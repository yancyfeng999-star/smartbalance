#!/usr/bin/env bash
# 本地测试包：装到 /Applications（唯一入口），并清掉构建产物里的 .app
# 不再复制到桌面，避免启动台/聚焦出现多个「智余」。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
DEST="/Applications/智余.app"
DERIVED="${ROOT}/build/DerivedData"

echo "==> tuist generate"
tuist generate --no-open

echo "==> xcodebuild Release"
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED}" build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES

APP="$(find "${DERIVED}/Build/Products" -name '智余.app' -type d | head -1)"
if [[ -z "${APP}" || ! -d "${APP}" ]]; then
  echo "error: 智余.app not found under ${DERIVED}" >&2
  exit 1
fi

# 退出旧进程
pkill -x "智余" 2>/dev/null || true

echo "==> install → ${DEST}"
rm -rf "${DEST}"
ditto --norsrc --noextattr --noqtn "${APP}" "${DEST}"
xattr -cr "${DEST}" 2>/dev/null || true
codesign --force --deep --sign - "${DEST}" 2>/dev/null || true

# 注销并删除构建目录里的 .app，避免第二个入口
if [[ -x "$LSREG" ]]; then
  "$LSREG" -u "${APP}" 2>/dev/null || true
  "$LSREG" -f "${DEST}" 2>/dev/null || true
fi
rm -rf "${APP}"
# 清空 Products，防止残留
rm -rf "${DERIVED}/Build/Products" 2>/dev/null || true
# 桌面旧测试包
if [[ -d "${HOME}/Desktop/智余.app" ]]; then
  [[ -x "$LSREG" ]] && "$LSREG" -u "${HOME}/Desktop/智余.app" 2>/dev/null || true
  rm -rf "${HOME}/Desktop/智余.app"
fi

# 通知中心/启动台常缓存旧 App 图标：碰时间戳 + 清用户图标缓存 + 重注册
touch "${DEST}" "${DEST}/Contents/Info.plist" "${DEST}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
rm -rf "${HOME}/Library/Caches/com.apple.iconservices.store" 2>/dev/null || true
find "${HOME}/Library/Caches/com.apple.iconservices" -type f -delete 2>/dev/null || true
if [[ -x "$LSREG" ]]; then
  "$LSREG" -f -R -trusted "${DEST}" 2>/dev/null || "$LSREG" -f "${DEST}" 2>/dev/null || true
fi
killall usernoted 2>/dev/null || true
killall NotificationCenter 2>/dev/null || true
killall Dock 2>/dev/null || true

VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${DEST}/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${DEST}/Contents/Info.plist")"
echo "Installed: ${DEST}  v${VER} (${BUILD})"
echo "Only open this one: 应用程序 → 智余（菜单栏图标，无 Dock）"
echo "open -a 智余"
