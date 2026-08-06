#!/usr/bin/env bash
# Release 构建 → 桌面 智余.app + dist zip（供 GitHub Releases 上传）
# 用法: ./scripts/package-release.sh [version]
# 例:   ./scripts/package-release.sh 0.2.0
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  # 从 Info.plist 读版本
  VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/App/Info.plist 2>/dev/null || echo "0.2.0")
fi

DIST="${ROOT}/dist"
mkdir -p "${DIST}"

echo "==> version ${VERSION}"
echo "==> tuist generate"
tuist generate --no-open

echo "==> xcodebuild Release"
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData build

APP=$(find build/DerivedData/Build/Products/Release -name '智余.app' -type d | head -1)
if [[ -z "${APP}" ]]; then
  echo "error: 智余.app not found under Release products" >&2
  exit 1
fi

# 校验 Info 版本
APP_VER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist" || true)
echo "==> built app version: ${APP_VER}"

# 安装到桌面
DEST="${HOME}/Desktop/智余.app"
rm -rf "${DEST}"
ditto "${APP}" "${DEST}"
# 去掉隔离属性，方便本地双击（仍可能被 Gatekeeper 提示）
xattr -cr "${DEST}" 2>/dev/null || true
echo "Installed: ${DEST}"

# Zip for GitHub Release
ZIP_NAME="SmartBalance-${VERSION}-macOS.zip"
ZIP="${DIST}/${ZIP_NAME}"
rm -f "${ZIP}"
# 在临时目录用英文名包一层，避免部分工具对中文路径不友好；Release 资产名用 SmartBalance
STAGE=$(mktemp -d)
ditto "${DEST}" "${STAGE}/智余.app"
(
  cd "${STAGE}"
  ditto -c -k --sequesterRsrc --keepParent "智余.app" "${ZIP}"
)
rm -rf "${STAGE}"

# 同步一份到桌面方便上传
cp -f "${ZIP}" "${HOME}/Desktop/${ZIP_NAME}"
echo "Packaged: ${ZIP}"
echo "Desktop:  ${HOME}/Desktop/${ZIP_NAME}"
ls -lh "${ZIP}" "${HOME}/Desktop/${ZIP_NAME}"
echo ""
echo "下一步（GitHub Release）:"
echo "  1. 建仓库并 push 代码"
echo "  2. Releases → Draft → tag v${VERSION}"
echo "  3. 上传 ${ZIP_NAME}"
echo "  4. 应用内「检查更新」会读 api.github.com/.../releases/latest"
echo "当前检查地址: https://github.com/yancyfeng999-star/smartbalance/releases"
