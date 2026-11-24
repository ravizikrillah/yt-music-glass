#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="YT Music Glass"
OUT_DIR="${ROOT_DIR}/dist-macos"
APP_BUNDLE="${OUT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BINARY_PATH="${MACOS_DIR}/YTMusicGlass"
ICONSET_DIR="${OUT_DIR}/AppIcon.iconset"

rm -rf "${APP_BUNDLE}" "${ICONSET_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${ICONSET_DIR}"

# Build crisp multi-resolution macOS AppIcon.icns from Resources/AppIcon.png (fallback to procedural icon)
if [ -f "${ROOT_DIR}/Resources/AppIcon.png" ] && command -v sips >/dev/null 2>&1; then
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
    sips -z "${px}" "${px}" "${ROOT_DIR}/Resources/AppIcon.png" --out "${ICONSET_DIR}/${name}" >/dev/null 2>&1
  done
else
  PYTHONDONTWRITEBYTECODE=1 python3 - "${ROOT_DIR}" "${ICONSET_DIR}" <<'PY'
import os, sys, importlib.util
root, iconset = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("gen", os.path.join(root, "scripts", "generate_icons.py"))
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

if [ -d "${ROOT_DIR}/Resources/Fonts" ]; then
  mkdir -p "${RESOURCES_DIR}/Fonts"
  cp -f "${ROOT_DIR}/Resources/Fonts/"*.ttf "${RESOURCES_DIR}/Fonts/" 2>/dev/null || true
fi

ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos14.0"

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
  "${ROOT_DIR}/Sources/Models.swift" \
  "${ROOT_DIR}/Sources/ArtworkPalette.swift" \
  "${ROOT_DIR}/Sources/AudioVisualizerView.swift" \
  "${ROOT_DIR}/Sources/ThemeStyles.swift" \
  "${ROOT_DIR}/Sources/MetadataNormalizer.swift" \
  "${ROOT_DIR}/Sources/LrcParser.swift" \
  "${ROOT_DIR}/Sources/Romanizer.swift" \
  "${ROOT_DIR}/Sources/TranslationService.swift" \
  "${ROOT_DIR}/Sources/LyricsService.swift" \
  "${ROOT_DIR}/Sources/UpdateService.swift" \
  "${ROOT_DIR}/Sources/NowPlayingBridge.swift" \
  "${ROOT_DIR}/Sources/WebBridgeScript.swift" \
  "${ROOT_DIR}/Sources/AppStore.swift" \
  "${ROOT_DIR}/Sources/FloatingHudPanel.swift" \
  "${ROOT_DIR}/Sources/MiniPlayerPanel.swift" \
  "${ROOT_DIR}/Sources/SettingsWindow.swift" \
  "${ROOT_DIR}/Sources/AboutWindow.swift" \
  "${ROOT_DIR}/Sources/CommandPalettePanel.swift" \
  "${ROOT_DIR}/Sources/HudContentView.swift" \
  "${ROOT_DIR}/Sources/SidebarLyricsView.swift" \
  "${ROOT_DIR}/Sources/FullScreenLyricsView.swift" \
  "${ROOT_DIR}/Sources/PlayerWindowController.swift" \
  "${ROOT_DIR}/Sources/AppDelegate.swift" \
  -o "${BINARY_PATH}"

cat > "${CONTENTS_DIR}/Info.plist" <<'PLIST'
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
  <string>1.0.0</string>
  <key>CFBundleExecutable</key>
  <string>YTMusicGlass</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>ATSApplicationFontsPath</key>
  <string>Fonts</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "Built native macOS app -> ${APP_BUNDLE}"
