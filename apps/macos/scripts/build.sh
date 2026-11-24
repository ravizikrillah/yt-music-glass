#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MACOS_ROOT="${ROOT_DIR}/apps/macos"
SHARED_CORE="${ROOT_DIR}/packages/shared/swift-core"
SHARED_WEB="${ROOT_DIR}/packages/shared/web"
SHARED_RES="${ROOT_DIR}/packages/shared/resources"

ARCH="${1:-$(uname -m)}"
if [ "${ARCH}" != "arm64" ] && [ "${ARCH}" != "x86_64" ]; then
  echo "Unsupported macOS arch: ${ARCH} (expected arm64 or x86_64)" >&2
  exit 1
fi

APP_NAME="YT Music Glass"
OUT_DIR="${ROOT_DIR}/dist-macos"
ARCH_OUT_DIR="${OUT_DIR}/${ARCH}"
APP_BUNDLE="${ARCH_OUT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
SHARED_WEB_RES_DIR="${RESOURCES_DIR}/SharedWeb"
BINARY_PATH="${MACOS_DIR}/YTMusicGlass"
ICONSET_DIR="${ARCH_OUT_DIR}/AppIcon.iconset"

rm -rf "${APP_BUNDLE}" "${ICONSET_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${SHARED_WEB_RES_DIR}" "${ICONSET_DIR}"

# Build crisp multi-resolution macOS AppIcon.icns from shared AppIcon.png (fallback to procedural icon)
if [ -f "${SHARED_RES}/AppIcon.png" ] && command -v sips >/dev/null 2>&1; then
  for spec in \
    "16:icon_16x16.png" \
    "32:icon_16x16@2x.png" \
    "32:icon_32x32.png" \
    "64:icon_32x32@2x.png" \
    "128:icon_128x128.png" \
    "256:icon_128x128@2x.png" \
    "256:icon_256x256.png" \
    "512:icon_256x256@2x.png" \
    "512:icon_512x512.png" \
    "1024:icon_512x512@2x.png"
  do
    px="${spec%%:*}"
    name="${spec#*:}"
    sips -z "${px}" "${px}" "${SHARED_RES}/AppIcon.png" --out "${ICONSET_DIR}/${name}" >/dev/null 2>&1
  done
else
  PYTHONDONTWRITEBYTECODE=1 python3 - "${MACOS_ROOT}" "${ICONSET_DIR}" <<'PY'
import os, sys, importlib.util
macos_root, iconset = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("gen", os.path.join(macos_root, "scripts", "generate_icons.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
sizes = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
]
for px, name in sizes:
    with open(os.path.join(iconset, name), "wb") as f:
        f.write(mod.render_icon(px))
PY
fi

if command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns" || true
fi
rm -rf "${ICONSET_DIR}"

if [ -d "${SHARED_RES}/Fonts" ]; then
  mkdir -p "${RESOURCES_DIR}/Fonts"
  cp -f "${SHARED_RES}/Fonts/"*.ttf "${RESOURCES_DIR}/Fonts/" 2>/dev/null || true
fi

cp -f "${SHARED_WEB}/theme-glass.css" "${SHARED_WEB}/theme-installer.js" "${SHARED_WEB}/bridge.js" "${SHARED_WEB_RES_DIR}/"

TARGET="${ARCH}-apple-macos13.0"
APP_VERSION="${YTMG_VERSION:-1.2.0}"

echo "Compiling ${APP_NAME}.app (${TARGET})..."
swiftc \
  -O \
  -parse-as-library \
  -target "${TARGET}" \
  -framework AppKit \
  -framework SwiftUI \
  -framework WebKit \
  -framework Combine \
  -framework CoreText \
  -framework MediaPlayer \
  -framework NaturalLanguage \
  -framework ServiceManagement \
  -framework UserNotifications \
  "${SHARED_CORE}/AppIdentity.swift" \
  "${SHARED_CORE}/Models.swift" \
  "${SHARED_CORE}/MetadataNormalizer.swift" \
  "${SHARED_CORE}/LrcParser.swift" \
  "${SHARED_CORE}/TapSyncEngine.swift" \
  "${SHARED_CORE}/Romanizer.swift" \
  "${SHARED_CORE}/TranslationService.swift" \
  "${SHARED_CORE}/LyricsService.swift" \
  "${SHARED_CORE}/SharedWebAssets.swift" \
  "${MACOS_ROOT}/Sources/ArtworkPalette.swift" \
  "${MACOS_ROOT}/Sources/AudioVisualizerView.swift" \
  "${MACOS_ROOT}/Sources/UpdateService.swift" \
  "${MACOS_ROOT}/Sources/NowPlayingBridge.swift" \
  "${MACOS_ROOT}/Sources/NativeDesktopExperience.swift" \
  "${MACOS_ROOT}/Sources/AppStore.swift" \
  "${MACOS_ROOT}/Sources/FloatingHudPanel.swift" \
  "${MACOS_ROOT}/Sources/MiniPlayerPanel.swift" \
  "${MACOS_ROOT}/Sources/SettingsWindow.swift" \
  "${MACOS_ROOT}/Sources/AboutWindow.swift" \
  "${MACOS_ROOT}/Sources/CommandPalettePanel.swift" \
  "${MACOS_ROOT}/Sources/TapSyncPanelView.swift" \
  "${MACOS_ROOT}/Sources/HudContentView.swift" \
  "${MACOS_ROOT}/Sources/SidebarLyricsView.swift" \
  "${MACOS_ROOT}/Sources/FullScreenLyricsView.swift" \
  "${MACOS_ROOT}/Sources/PlayerWindowController.swift" \
  "${MACOS_ROOT}/Sources/AppDelegate.swift" \
  -o "${BINARY_PATH}"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>YT Music Glass</string>
  <key>CFBundleDisplayName</key>
  <string>YT Music Glass</string>
  <key>CFBundleIdentifier</key>
  <string>com.ytmusicglass.app</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>YTMusicGlass</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>ATSApplicationFontsPath</key>
  <string>Fonts</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "Built native macOS app -> ${APP_BUNDLE}"
