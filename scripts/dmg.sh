#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="YT Music Glass"
ARCH="$(uname -m)"
OUT_DIR="${ROOT_DIR}/dist-macos"
APP_BUNDLE="${OUT_DIR}/${APP_NAME}.app"
DMG_NAME="YT-Music-Glass-macOS-${ARCH}.dmg"
DMG_PATH="${OUT_DIR}/${DMG_NAME}"
STAGE_DIR="${OUT_DIR}/dmg-stage"

bash "${ROOT_DIR}/scripts/build.sh"

rm -rf "${STAGE_DIR}" "${DMG_PATH}"
mkdir -p "${STAGE_DIR}"

cp -R "${APP_BUNDLE}" "${STAGE_DIR}/"
ln -s /Applications "${STAGE_DIR}/Applications"

echo "Packaging ${DMG_NAME}..."
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

rm -rf "${STAGE_DIR}"
echo "Built macOS installer DMG -> ${DMG_PATH}"
ls -lh "${DMG_PATH}"
