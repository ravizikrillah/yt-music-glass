#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MACOS_ROOT="${ROOT_DIR}/apps/macos"
APP_NAME="YT Music Glass"
OUT_DIR="${ROOT_DIR}/dist-macos"

REQUEST_ARCH="${1:-$(uname -m)}"
if [ "${REQUEST_ARCH}" = "all" ]; then
  ARCHS=("arm64" "x86_64")
elif [ "${REQUEST_ARCH}" = "arm64" ] || [ "${REQUEST_ARCH}" = "x86_64" ]; then
  ARCHS=("${REQUEST_ARCH}")
else
  echo "Unsupported target: ${REQUEST_ARCH} (expected arm64, x86_64, or all)" >&2
  exit 1
fi

for ARCH in "${ARCHS[@]}"; do
  APP_BUNDLE="${OUT_DIR}/${ARCH}/${APP_NAME}.app"
  DMG_NAME="YT-Music-Glass-macOS-${ARCH}.dmg"
  DMG_PATH="${OUT_DIR}/${DMG_NAME}"
  STAGE_DIR="${OUT_DIR}/dmg-stage-${ARCH}"

  bash "${MACOS_ROOT}/scripts/build.sh" "${ARCH}"

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
done
