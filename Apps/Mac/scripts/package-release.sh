#!/usr/bin/env bash
# Release 构建 → 桌面 智余.app + releases/ + Desktop zip
# 用法: ./scripts/package-release.sh [version]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "${ROOT}/../.." && pwd)"   # 智余 仓库根
cd "$ROOT"

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/App/Info.plist 2>/dev/null || echo "0.2.0")
fi

RELEASES_DIR="${REPO}/releases"
DIST_LOCAL="${ROOT}/dist"
mkdir -p "${RELEASES_DIR}" "${DIST_LOCAL}"

echo "==> version ${VERSION}"
echo "==> tuist generate"
tuist generate --no-open

echo "==> xcodebuild Release"
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData build

APP=$(find build/DerivedData/Build/Products/Release -name '智余.app' -type d | head -1)
if [[ -z "${APP}" ]]; then
  echo "error: 智余.app not found" >&2
  exit 1
fi

APP_VER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist" || true)
echo "==> built app version: ${APP_VER}"

DEST="${HOME}/Desktop/智余.app"
rm -rf "${DEST}"
ditto "${APP}" "${DEST}"
xattr -cr "${DEST}" 2>/dev/null || true
echo "Installed: ${DEST}"

ZIP_NAME="SmartBalance-${VERSION}-macOS.zip"
ZIP_DESKTOP="${HOME}/Desktop/${ZIP_NAME}"
ZIP_RELEASES="${RELEASES_DIR}/${ZIP_NAME}"
ZIP_DIST="${DIST_LOCAL}/${ZIP_NAME}"

STAGE=$(mktemp -d)
ditto "${DEST}" "${STAGE}/智余.app"
(
  cd "${STAGE}"
  ditto -c -k --sequesterRsrc --keepParent "智余.app" "${ZIP_DIST}"
)
rm -rf "${STAGE}"
cp -f "${ZIP_DIST}" "${ZIP_DESKTOP}"
cp -f "${ZIP_DIST}" "${ZIP_RELEASES}"

echo "Packaged:"
ls -lh "${ZIP_DIST}" "${ZIP_DESKTOP}" "${ZIP_RELEASES}"
echo ""
echo "安装：双击/拖入 应用程序  →  ${DEST}"
echo "GitHub Release 上传：${ZIP_NAME}"
echo "仓库 releases 目录：${ZIP_RELEASES}"
