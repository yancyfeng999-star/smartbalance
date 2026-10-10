#!/usr/bin/env bash
# 一键发版：升版本 → 打包 dmg/pkg → 提交 → 打 tag → push → GitHub Release
#
# Agent 默认：功能/修复做完后直接跑本脚本上线，不要让用户自己升版/push。
# 说明见仓库根 AGENTS.md 与 docs/AGENT_RELEASE_WORKFLOW.md
#
# 用法（在 Apps/Mac 下）:
#   ./scripts/release.sh              # patch 升版并上线
#   ./scripts/release.sh minor        # minor 升版
#   ./scripts/release.sh 0.3.0        # 指定版本
#   SKIP_PUBLISH=1 ./scripts/release.sh   # 只升版+打包，不上传
#   NOTES="修复 xxx" ./scripts/release.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "${ROOT}/../.." && pwd)"
cd "$ROOT"

BUMP="${1:-patch}"
SKIP_PUBLISH="${SKIP_PUBLISH:-0}"
NOTES_EXTRA="${NOTES:-}"

echo "======== 0) 开源门禁 ========"
./scripts/verify-open-source.sh

echo "======== 1) 升版本 ========"
# shellcheck disable=SC1091
eval "$(./scripts/bump-version.sh "${BUMP}" | tee /dev/stderr | grep '^NEW_')"
VERSION="${NEW_VERSION}"
BUILD="${NEW_BUILD}"
TAG="v${VERSION}"

echo "======== 2) 打包 ========"
# 版本与构建号已在 bump-version.sh 写好；禁止 package 再 +build
BUMP_BUILD=0 FORCE_REPACKAGE=1 ./scripts/package-release.sh "${VERSION}"

STAGE="${REPO}/releases/Mac/${TAG}"
if [[ ! -d "${STAGE}" ]]; then
  echo "error: 打包产物目录不存在 ${STAGE}" >&2
  exit 1
fi

# 追加 CHANGELOG 条目头（若不存在）
CHANGELOG="${REPO}/CHANGELOG.md"
if [[ -f "${CHANGELOG}" ]] && ! grep -q "## ${VERSION}" "${CHANGELOG}"; then
  {
    echo ""
    echo "## ${VERSION} — $(date '+%Y-%m-%d')"
    echo ""
    if [[ -n "${NOTES_EXTRA}" ]]; then
      echo "${NOTES_EXTRA}"
      echo ""
    else
      echo "- 日常发版（自动升版打包）"
      echo ""
    fi
    cat "${CHANGELOG}"
  } > "${CHANGELOG}.tmp"
  # 把新段放到文件头（保留原 # Changelog）
  {
    head -1 "${CHANGELOG}"
    echo ""
    echo "## ${VERSION} — $(date '+%Y-%m-%d')"
    echo ""
    if [[ -n "${NOTES_EXTRA}" ]]; then
      echo "${NOTES_EXTRA}"
    else
      echo "- 日常发版（自动升版打包）"
    fi
    echo ""
    tail -n +2 "${CHANGELOG}"
  } > "${CHANGELOG}.tmp"
  mv "${CHANGELOG}.tmp" "${CHANGELOG}"
fi

echo "======== 3) Git 提交 ========"
cd "${REPO}"
# 一并提交尚未入库的源码/脚本/品牌图，避免出现「包已更新、仓库无代码」
git add Apps/Mac/README.md Apps/Mac/Sources Apps/Mac/Tests Apps/Mac/SmartBalance.xcodeproj Apps/Mac/scripts Apps/Mac/Branding Branding README.md LICENSE CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md THIRD_PARTY_NOTICES.md .github CHANGELOG.md PRODUCT.md PROJECT_STATUS.md docs 2>/dev/null || true
git add "releases/Mac/${TAG}/RELEASE_NOTES.md" "releases/Mac/${TAG}/SHA256SUMS.txt" 2>/dev/null || true
if git diff --cached --quiet 2>/dev/null && git diff --quiet 2>/dev/null; then
  echo "(无文本变更可提交，继续)"
else
  git commit -m "release: ${VERSION} (build ${BUILD})" || true
fi

if [[ "${SKIP_PUBLISH}" == "1" ]]; then
  echo "SKIP_PUBLISH=1：已打包，未 push / 未建 Release"
  echo "产物: ${STAGE}"
  ls -lh "${STAGE}"
  exit 0
fi

echo "======== 4) Push + Tag ========"
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "error: 无 origin remote，请先 gh repo create / git remote add" >&2
  exit 1
fi

# 创建 release 分支并推送到远程
RELEASE_BRANCH="release/${VERSION}"
git checkout -b "${RELEASE_BRANCH}"
git push -u origin "${RELEASE_BRANCH}"

# 删除同名 tag 重发（仅当本地强制）
if git rev-parse "${TAG}" >/dev/null 2>&1; then
  git tag -d "${TAG}" || true
fi
git tag -a "${TAG}" -m "智余 SmartBalance ${VERSION}"
git push origin "${TAG}" --force

echo "======== 5) 创建 Pull Request ========"
gh pr create --title "release: ${VERSION} (build ${BUILD})" --body "发版 PR，包含版本 ${VERSION} 的变更" --base main --head "${RELEASE_BRANCH}"

echo "======== 6) 清掉本机多余 .app ========"
KEEP_RUNNING=1 ./scripts/cleanup-duplicate-apps.sh || true

echo ""
echo "========== 发版准备完成 =========="
echo "版本: ${VERSION} (build ${BUILD})"
echo "PR: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/pull/new/${RELEASE_BRANCH}"
echo "资产: ${STAGE}/SmartBalance-${VERSION}.dmg / .pkg"
echo ""
echo "下一步："
echo "1. 在 GitHub 上 Review 并 Merge PR"
echo "2. 运行 ./scripts/publish-release.sh ${VERSION} 来创建 GitHub Release"
