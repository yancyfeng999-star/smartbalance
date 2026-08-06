#!/usr/bin/env bash
# Build Release and zip 智余.app into dist/ for local handoff (no notarization).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-0.1.0}"
DIST="${ROOT}/dist"
mkdir -p "${DIST}"

echo "==> build-test-app (Release → Desktop)"
bash "${ROOT}/scripts/build-test-app.sh"

APP="${HOME}/Desktop/智余.app"
if [[ ! -d "${APP}" ]]; then
  echo "error: missing ${APP}" >&2
  exit 1
fi

ZIP="${DIST}/SmartBalance-${VERSION}-macOS.zip"
rm -f "${ZIP}"
ditto -c -k --sequesterRsrc --keepParent "${APP}" "${ZIP}"
echo "Packaged: ${ZIP}"
ls -lh "${ZIP}"
