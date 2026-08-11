#!/usr/bin/env bash
# 发布 GitHub Release（PR 合并后运行）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "${ROOT}/../.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "用法: ./scripts/publish-release.sh <version>" >&2
  echo "示例: ./scripts/publish-release.sh 0.2.57" >&2
  exit 1
fi

TAG="v${VERSION}"
STAGE="${REPO}/releases/Mac/${TAG}"

if [[ ! -d "${STAGE}" ]]; then
  echo "error: 未找到发布资产目录 ${STAGE}" >&2
  exit 1
fi

NOTES_FILE="${STAGE}/RELEASE_NOTES.md"
if [[ ! -f "${NOTES_FILE}" ]]; then
  echo "error: 未找到 RELEASE_NOTES.md" >&2
  exit 1
fi

echo "======== 创建 GitHub Release ========"
# 删旧 release（若存在）
gh release delete "${TAG}" --yes 2>/dev/null || true

gh release create "${TAG}" \
  --title "智余 SmartBalance ${VERSION}" \
  --notes-file "${NOTES_FILE}" \
  "${STAGE}/SmartBalance-${VERSION}.dmg" \
  "${STAGE}/SmartBalance-${VERSION}.pkg" \
  "${STAGE}/SHA256SUMS.txt"

echo ""
echo "========== 发布完成 =========="
echo "版本: ${VERSION}"
echo "Release: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/${TAG}"
