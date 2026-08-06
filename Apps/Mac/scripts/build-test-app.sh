#!/usr/bin/env bash
# Release build and install 智余.app to Desktop for local smoke testing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> tuist generate"
tuist generate --no-open

echo "==> xcodebuild Release"
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData build

APP=$(find build/DerivedData -name '智余.app' -type d | head -1)
if [[ -z "${APP}" ]]; then
  echo "error: 智余.app not found under build/DerivedData" >&2
  exit 1
fi

DEST="${HOME}/Desktop/智余.app"
rm -rf "${DEST}"
cp -R "${APP}" "${DEST}"
echo "Installed: ${DEST}"
echo "Note: LSUIElement=YES (menu bar only; no Dock icon)."
echo "Menu bar glyph falls back to SF Symbol yensign.circle.fill when needed."
