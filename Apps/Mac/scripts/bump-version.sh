#!/usr/bin/env bash
# 提升 Info.plist 版本号（每次发版必跑）
# 用法:
#   ./scripts/bump-version.sh           # patch +1（0.2.0 → 0.2.1）
#   ./scripts/bump-version.sh minor     # 0.2.1 → 0.3.0
#   ./scripts/bump-version.sh major     # 0.3.0 → 1.0.0
#   ./scripts/bump-version.sh 0.3.5     # 指定营销版本
# 始终 +1 CFBundleVersion（构建号）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="${ROOT}/Sources/App/Info.plist"
ARG="${1:-patch}"

cur=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" | tr -d '[:space:]')
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST" | tr -d '[:space:]')
build=$((build + 1))

# 注意：read 最后一个变量会吞掉剩余字段，必须多读一位丢弃
# 例：cur=0.2.0 补成 0.2.0.0.0 时，若只读 3 段则 PA 会变成 "0.0.0"
IFS='.' read -r MA MI PA _ <<< "${cur}.0.0"
MA=${MA:-0}; MI=${MI:-0}; PA=${PA:-0}
# 只保留数字（防异常）
MA=${MA//[^0-9]/}; MI=${MI//[^0-9]/}; PA=${PA//[^0-9]/}
MA=${MA:-0}; MI=${MI:-0}; PA=${PA:-0}

case "$ARG" in
  patch)  PA=$((10#${PA} + 1)); NEW="${MA}.${MI}.${PA}" ;;
  minor)  MI=$((10#${MI} + 1)); PA=0; NEW="${MA}.${MI}.${PA}" ;;
  major)  MA=$((10#${MA} + 1)); MI=0; PA=0; NEW="${MA}.${MI}.${PA}" ;;
  [0-9]*.[0-9]*) NEW="$ARG" ;;
  *)
    echo "用法: $0 [patch|minor|major|X.Y.Z]" >&2
    exit 1
    ;;
esac

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${NEW}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${build}" "$PLIST"

# 同步 README 版本行（若存在）
README="${ROOT}/../../README.md"
if [[ -f "$README" ]]; then
  # macOS sed
  sed -i '' -E "s/\| 版本 \| [^|]+ \|/| 版本 | ${NEW} |/" "$README" 2>/dev/null || true
fi

echo "version ${cur} → ${NEW}  (build ${build})"
echo "NEW_VERSION=${NEW}"
echo "NEW_BUILD=${build}"
