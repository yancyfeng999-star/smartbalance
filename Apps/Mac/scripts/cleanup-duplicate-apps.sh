#!/usr/bin/env bash
# 清理本机多余的「智余」入口，只保留 /Applications/智余.app
#
# 常见重复来源：
# - Xcode / tuist 构建的 DerivedData Debug/Release
# - 桌面/下载的测试包
# - 未弹出的 dmg 卷（/Volumes/智余 x.y.z）
#
set -euo pipefail

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
APP_ID="com.smartbalance.app"
KEEP="/Applications/智余.app"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "==> 退出运行中的智余"
pkill -x "智余" 2>/dev/null || true
sleep 0.3

echo "==> 弹出未关闭的安装镜像"
shopt -s nullglob
for vol in /Volumes/智余* /Volumes/SmartBalance*; do
  if [[ -d "$vol" ]]; then
    echo "  eject $vol"
    hdiutil detach "$vol" -force 2>/dev/null || true
  fi
done
shopt -u nullglob

unregister_rm() {
  local app="$1"
  [[ -e "$app" || -d "$app" ]] || return 0
  if [[ "$app" == "$KEEP" ]]; then
    return 0
  fi
  echo "  remove $app"
  if [[ -x "$LSREG" ]]; then
    "$LSREG" -u "$app" 2>/dev/null || true
  fi
  rm -rf "$app"
}

echo "==> 扫描并删除多余 .app"
# Spotlight
while IFS= read -r app; do
  [[ -n "$app" ]] || continue
  unregister_rm "$app"
done < <(mdfind "kMDItemCFBundleIdentifier == '${APP_ID}'" 2>/dev/null || true)

# 固定路径
for app in \
  "${HOME}/Desktop/智余.app" \
  "${HOME}/Downloads/智余.app" \
  "${HOME}/Applications/智余.app"
do
  unregister_rm "$app"
done

# Xcode / 项目构建产物
for root in \
  "${HOME}/Library/Developer/Xcode/DerivedData" \
  "${REPO_ROOT}/Apps/Mac/build"
do
  [[ -d "$root" ]] || continue
  while IFS= read -r app; do
    unregister_rm "$app"
  done < <(find "$root" -name "智余.app" -type d 2>/dev/null || true)
done

if [[ -d "$KEEP" ]]; then
  ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$KEEP/Contents/Info.plist" 2>/dev/null || echo "?")"
  build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$KEEP/Contents/Info.plist" 2>/dev/null || echo "?")"
  echo "==> 正式安装：${KEEP}  (v${ver} build ${build})"
  if [[ -x "$LSREG" ]]; then
    "$LSREG" -f "$KEEP" 2>/dev/null || true
  fi
else
  echo "==> 警告：未找到 ${KEEP}"
  echo "    请从 GitHub 安装 dmg/pkg 到「应用程序」"
fi

echo "==> 刷新 Launch Services 索引"
if [[ -x "$LSREG" ]]; then
  "$LSREG" -kill -seed 2>/dev/null || true
fi

echo ""
echo "剩余入口："
mdfind "kMDItemCFBundleIdentifier == '${APP_ID}'" 2>/dev/null || true
echo "完成。启动台若仍有幽灵图标：注销一次，或删掉 ~/Library/Application Support/Dock 后重新登录。"
