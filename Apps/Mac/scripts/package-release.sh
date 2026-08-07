#!/usr/bin/env bash
# 智余 · SmartBalance — 打成 macOS 标准安装包（对齐智额）
#
# 产物（<repo>/releases/Mac/vX.Y.Z/）：
#   智余-X.Y.Z.dmg     ← 推荐：打开后拖进 Applications
#   智余-X.Y.Z.pkg     ← 双击安装向导
#   SmartBalance-X.Y.Z.dmg / .pkg  ← 英文文件名（GitHub / 更新器更稳）
#   RELEASE_NOTES.md
#   SHA256SUMS.txt
#
# 用法（在 Apps/Mac 下）：
#   ./scripts/package-release.sh              # 用 Info.plist 当前版本（本地试包）
#   ./scripts/package-release.sh 0.2.1        # 指定版本（会先写入 Info.plist）
#
# ⚠️ 规则：每次上线必须先升版本。完整发版请用：
#   ./scripts/release.sh              # patch 升版 → 打包 → GitHub
#   ./scripts/release.sh minor|major|0.3.0
#
# 若当前版本已打过 git tag（说明已上线过），默认拒绝重复打包，避免同版本覆盖上线。
# 仅本地调试可： FORCE_REPACKAGE=1 ./scripts/package-release.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
cd "$ROOT"

APP_NAME="智余"
EN_NAME="SmartBalance"
BUNDLE_ID="com.smartbalance.zhiyu"
CONFIG="Release"
DERIVED="${ROOT}/build/DerivedData-Release"
RELEASES_ROOT="${RELEASES_ROOT:-$REPO_ROOT/releases/Mac}"
# 默认不上桌面：发版只走 GitHub；需要本机副本时 COPY_TO_DESKTOP=1
COPY_TO_DESKTOP="${COPY_TO_DESKTOP:-0}"
DESKTOP_OUT="${DESKTOP_OUT:-$HOME/Desktop/智余-发布}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
FORCE_REPACKAGE="${FORCE_REPACKAGE:-0}"

VERSION_ARG="${1:-}"
PLIST="${ROOT}/Sources/App/Info.plist"

# 若传入版本号，先写入 Info.plist（保证包内版本一致）
if [[ -n "${VERSION_ARG}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION_ARG}" "$PLIST"
  # 构建号：release.sh 已 bump 过则设 BUMP_BUILD=0，否则 +1
  if [[ "${BUMP_BUILD:-1}" == "1" ]]; then
    CUR_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((CUR_BUILD + 1))" "$PLIST"
  fi
fi

# 读将要打包的营销版本，禁止对已发布 tag 重复打包（每次上线必须升版）
PENDING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
PENDING_TAG="v${PENDING_VERSION}"
if [[ "${FORCE_REPACKAGE}" != "1" ]]; then
  if git -C "${REPO_ROOT}" rev-parse "${PENDING_TAG}" >/dev/null 2>&1; then
    echo "error: 版本 ${PENDING_VERSION} 已存在 tag ${PENDING_TAG}（说明已上线过）。" >&2
    echo "       规则：每次打包上线必须先升版本。" >&2
    echo "       请执行:  ./scripts/release.sh          # 自动 patch 升版并上线" >&2
    echo "       或:      ./scripts/release.sh minor    # 升次版本" >&2
    echo "       仅本地重打同版本包可: FORCE_REPACKAGE=1 ./scripts/package-release.sh" >&2
    exit 1
  fi
  if [[ -d "${RELEASES_ROOT}/${PENDING_TAG}" ]] && [[ -f "${RELEASES_ROOT}/${PENDING_TAG}/SmartBalance-${PENDING_VERSION}.dmg" ]]; then
    echo "error: 本地已有 ${PENDING_TAG} 安装包。每次上线须升版本。" >&2
    echo "       请执行: ./scripts/release.sh" >&2
    echo "       强制重打: FORCE_REPACKAGE=1 ./scripts/package-release.sh" >&2
    exit 1
  fi
fi

printf '%s\n' "==> [1/5] branding + tuist generate"
# 确保 AppIcon 白底 + 完整 icns 入库后再编
if command -v python3 >/dev/null 2>&1; then
  python3 "${ROOT}/scripts/apply-branding.py" || true
fi
tuist generate --no-open

printf '%s\n' "==> [2/5] xcodebuild Release"
BUILD_LOG="${DERIVED}/xcodebuild-release.log"
mkdir -p "${DERIVED}"
set +e
xcodebuild \
  -workspace SmartBalance.xcworkspace \
  -scheme SmartBalance \
  -configuration "${CONFIG}" \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED}" \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  >"${BUILD_LOG}" 2>&1
BUILD_STATUS=$?
set -e
tail -20 "${BUILD_LOG}" || true
if [[ "${BUILD_STATUS}" -ne 0 ]]; then
  echo "ERROR: xcodebuild failed. Full log: ${BUILD_LOG}"
  exit "${BUILD_STATUS}"
fi

APP_SRC="$(find "${DERIVED}/Build/Products/${CONFIG}" -maxdepth 1 -name "*.app" | head -1)"
if [[ -z "${APP_SRC}" || ! -d "${APP_SRC}" ]]; then
  echo "ERROR: Release .app not found under ${DERIVED}/Build/Products/${CONFIG}"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_SRC}/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP_SRC}/Contents/Info.plist" 2>/dev/null || echo "1")"
TAG="v${VERSION}"
STAGE="${RELEASES_ROOT}/${TAG}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/zhiyu-pkg.XXXXXX")"
cleanup() { rm -rf "${WORK}"; }
trap cleanup EXIT

printf '%s\n' "==> [3/5] stage + sign  (${VERSION} build ${BUILD})"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$WORK/app"

ditto --norsrc --noextattr --noqtn "$APP_SRC" "$WORK/app/${APP_NAME}.app"
xattr -cr "$WORK/app/${APP_NAME}.app" 2>/dev/null || true

# 用 branding 脚本生成的完整白底 AppIcon.icns 覆盖 actool 子集（对齐智额：只靠包内图标）
ICNS_SRC="${ROOT}/Sources/App/Resources/AppIcon.icns"
if [[ -f "${ICNS_SRC}" ]]; then
  mkdir -p "$WORK/app/${APP_NAME}.app/Contents/Resources"
  cp -f "${ICNS_SRC}" "$WORK/app/${APP_NAME}.app/Contents/Resources/AppIcon.icns"
  echo "  seeded AppIcon.icns ($(wc -c < "${ICNS_SRC}" | tr -d ' ') bytes, white-bg)"
else
  echo "  warn: missing ${ICNS_SRC} — run python3 scripts/apply-branding.py" >&2
fi
# 去掉自定义 Icon（setIcon 残留会锁住通知中心旧图）
rm -f "$WORK/app/${APP_NAME}.app/Icon" "$WORK/app/${APP_NAME}.app/Icon"$'\r' 2>/dev/null || true
xattr -d com.apple.FinderInfo "$WORK/app/${APP_NAME}.app" 2>/dev/null || true

# 拷走后立刻删掉构建产物 .app，避免启动台/聚焦出现多个「智余」
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREG" ]]; then
  "$LSREG" -u "$APP_SRC" 2>/dev/null || true
fi
rm -rf "$APP_SRC"
# 本项目 DerivedData + 全局 Xcode DerivedData 里残留的 智余.app
rm -rf "${ROOT}/build/DerivedData/Build/Products" 2>/dev/null || true
rm -rf "${DERIVED}/Build/Products" 2>/dev/null || true
while IFS= read -r leftover; do
  [[ -z "$leftover" ]] && continue
  [[ "$leftover" == "/Applications/${APP_NAME}.app" ]] && continue
  if [[ -x "$LSREG" ]]; then
    "$LSREG" -u "$leftover" 2>/dev/null || true
  fi
  rm -rf "$leftover"
done < <(find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path '*SmartBalance*' -name "${APP_NAME}.app" -type d 2>/dev/null || true)

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$WORK/app/${APP_NAME}.app"
  SIGN_NOTE="临时签名（ad-hoc）。其他 Mac 首次：右键 → 打开，或 系统设置 → 隐私与安全性 → 仍要打开。"
else
  ENT="$ROOT/Sources/App/entitlements.plist"
  if [[ -f "$ENT" ]]; then
    codesign --force --deep --options runtime --timestamp \
      --entitlements "$ENT" --sign "$SIGN_IDENTITY" \
      "$WORK/app/${APP_NAME}.app"
  else
    codesign --force --deep --options runtime --timestamp \
      --sign "$SIGN_IDENTITY" \
      "$WORK/app/${APP_NAME}.app"
  fi
  SIGN_NOTE="已签名：${SIGN_IDENTITY}"
fi

# 不在 releases 里放裸 .app，避免 Spotlight 重复
rm -rf "${STAGE}/${APP_NAME}.app" 2>/dev/null || true

printf '%s\n' "==> [4/5] DMG + PKG"

# ---------- DMG：拖到 Applications ----------
DMG_ROOT="$WORK/dmg"
mkdir -p "$DMG_ROOT"
ditto --norsrc --noextattr --noqtn "$WORK/app/${APP_NAME}.app" "$DMG_ROOT/${APP_NAME}.app"
ln -s /Applications "$DMG_ROOT/Applications"

cat > "$DMG_ROOT/Install.txt" <<EOF
智余 · ${EN_NAME}  ${VERSION}

安装方法（常见 Mac 软件做法）：
  1. 把「${APP_NAME}.app」拖到「Applications」
  2. 打开启动台 / 应用程序里的 智余
  3. 菜单栏出现图标即成功

若提示无法打开：
  Control + 点击 智余 → 打开
  或：系统设置 → 隐私与安全性 → 仍要打开

系统要求：macOS 15+
${SIGN_NOTE}
EOF
cp "$DMG_ROOT/Install.txt" "$DMG_ROOT/安装说明.txt"

DMG_CN="${STAGE}/${APP_NAME}-${VERSION}.dmg"
DMG_EN="${STAGE}/${EN_NAME}-${VERSION}.dmg"
rm -f "$DMG_CN" "$DMG_EN"

RW_DMG="$WORK/temp.dmg"
hdiutil create \
  -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "$DMG_ROOT" \
  -ov -fs HFS+ -format UDRW \
  "$RW_DMG" >/dev/null

MOUNT_DIR="$WORK/mnt"
mkdir -p "$MOUNT_DIR"
DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk '/Apple_HFS|Apple_APFS|GUID_partition_scheme/ {print $1; exit}')"
VOL_PATH="$(ls -d /Volumes/${APP_NAME}* 2>/dev/null | head -1 || true)"
if [[ -n "${VOL_PATH:-}" && -d "$VOL_PATH" ]]; then
  osascript <<APPLESCRIPT 2>/dev/null || true
tell application "Finder"
  tell disk "$(basename "$VOL_PATH")"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 480}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    try
      set position of item "${APP_NAME}.app" of container window to {160, 180}
      set position of item "Applications" of container window to {480, 180}
      set position of item "安装说明.txt" of container window to {320, 340}
    end try
    update without registering applications
    delay 0.5
    close
  end tell
end tell
APPLESCRIPT
  sync
  hdiutil detach "$VOL_PATH" -force 2>/dev/null || hdiutil detach "$DEVICE" -force 2>/dev/null || true
else
  hdiutil detach "$DEVICE" -force 2>/dev/null || true
fi
# 确保卷已卸下再 convert，避免「资源暂时不可用」
sleep 0.8
for _try in 1 2 3; do
  if hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_CN" 2>/dev/null; then
    break
  fi
  # 残留挂载时强制卸下后重试
  hdiutil detach "$VOL_PATH" -force 2>/dev/null || true
  hdiutil detach "$DEVICE" -force 2>/dev/null || true
  sleep 1
  if [[ "$_try" -eq 3 ]]; then
    echo "ERROR: hdiutil convert failed after retries" >&2
    exit 1
  fi
done
rm -f "$RW_DMG"
cp -f "$DMG_CN" "$DMG_EN"

# ---------- PKG：安装向导 ----------
PKG_ROOT="$WORK/pkgroot"
mkdir -p "$PKG_ROOT"
ditto --norsrc --noextattr --noqtn "$WORK/app/${APP_NAME}.app" "$PKG_ROOT/${APP_NAME}.app"

PKG_CN="${STAGE}/${APP_NAME}-${VERSION}.pkg"
PKG_EN="${STAGE}/${EN_NAME}-${VERSION}.pkg"
rm -f "$PKG_CN" "$PKG_EN"
pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "${BUNDLE_ID}" \
  --version "${VERSION}" \
  --install-location "/Applications" \
  --min-os-version "15.0" \
  "$PKG_CN" >/dev/null
cp -f "$PKG_CN" "$PKG_EN"

# 说明 + 校验
DATE_STR="$(date '+%Y-%m-%d')"
cat > "$STAGE/RELEASE_NOTES.md" <<EOF
# 智余 ${VERSION} (build ${BUILD})

- **日期**：${DATE_STR}
- **标签**：\`${TAG}\`

## 安装包

| 文件 | 怎么用 |
|------|--------|
| **${APP_NAME}-${VERSION}.dmg** / **${EN_NAME}-${VERSION}.dmg** | 打开后把 App **拖到 Applications**（推荐） |
| **${APP_NAME}-${VERSION}.pkg** / **${EN_NAME}-${VERSION}.pkg** | 双击，按安装向导装到「应用程序」 |

## 首次打开

若提示无法验证开发者：Control + 点击 → 打开。  
${SIGN_NOTE}

## 系统

macOS 15.0 或更高。

## 更新

设置 → 软件更新 → 检查更新（GitHub Releases，优先下载 dmg/pkg）。
EOF

(
  cd "$STAGE"
  shasum -a 256 \
    "${APP_NAME}-${VERSION}.dmg" \
    "${APP_NAME}-${VERSION}.pkg" \
    "${EN_NAME}-${VERSION}.dmg" \
    "${EN_NAME}-${VERSION}.pkg" \
    > SHA256SUMS.txt
)

printf '%s\n' "==> [5/5] 清理（默认不复制到桌面，发版只上 GitHub）"
# 避免桌面残留裸 .app / 旧发布夹导致 Spotlight 多个智余
if [[ -x "$LSREG" && -d "${HOME}/Desktop/${APP_NAME}.app" ]]; then
  "$LSREG" -u "${HOME}/Desktop/${APP_NAME}.app" 2>/dev/null || true
fi
rm -rf "${HOME}/Desktop/${APP_NAME}.app" 2>/dev/null || true
# 弹出打包时可能挂上的临时卷
shopt -s nullglob
for vol in /Volumes/${APP_NAME}* /Volumes/${EN_NAME}*; do
  hdiutil detach "$vol" -force 2>/dev/null || true
done
shopt -u nullglob
if [[ "${COPY_TO_DESKTOP}" == "1" ]]; then
  rm -rf "${DESKTOP_OUT}"
  mkdir -p "${DESKTOP_OUT}"
  cp -f "$DMG_CN" "$PKG_CN" "$STAGE/RELEASE_NOTES.md" "$STAGE/SHA256SUMS.txt" "${DESKTOP_OUT}/"
  # 禁止把裸 .app 放到桌面
else
  rm -rf "${DESKTOP_OUT}" 2>/dev/null || true
fi

echo ""
echo "========== 打包完成 =========="
echo "版本: ${VERSION} (build ${BUILD})"
echo "本地暂存: ${STAGE}"
ls -lh "${STAGE}"
echo ""
echo "上线资产（GitHub 英文名）："
echo "  ${EN_NAME}-${VERSION}.dmg"
echo "  ${EN_NAME}-${VERSION}.pkg"
echo "标签: ${TAG}"
if [[ "${COPY_TO_DESKTOP}" == "1" ]]; then
  echo "（已额外复制到桌面 ${DESKTOP_OUT}/）"
fi
