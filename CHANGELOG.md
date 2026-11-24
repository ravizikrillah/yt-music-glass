# Changelog

All notable changes to **YT Music Glass** are documented in this file.
GitHub Releases automatically reads the matching `## [X.Y.Z]` section via [`.github/scripts/release-notes.mjs`](.github/scripts/release-notes.mjs) whenever a `v*` tag is pushed.

## [1.2.0] - 2026-11-24

Lightweight cross-platform desktop client for YouTube Music & YouTube — now available for **macOS (Apple Silicon & Intel, 13.0+)**, **Windows**, and **Linux** (zero Electron).

### Highlights
- **Hybrid Multi-Engine Desktop Monorepo:** Restructured the codebase into `apps/macos/` (pure Swift), `apps/desktop/` (Tauri v2 Rust + WebView2 / WebKitGTK), and `packages/shared/` (single-source Glass CSS, JS playback bridge, Swift core modules, and cross-platform JSON test vectors) with CI verification across macOS, Windows, and Linux
- **macOS Intel & Ventura 13.0+ Support:** Added dual-architecture builds (`YT-Music-Glass-macOS-arm64.dmg` and `YT-Music-Glass-macOS-x86_64.dmg`) and lowered the minimum deployment target from macOS 14.0 to macOS 13.0+
- **Windows & Linux Native Desktop App (`apps/desktop/`):** Launched the Tauri v2 desktop client with the Obsidian Liquid Glass UI, Synced Word-Flow Lyrics, Tap-to-Sync, Offline Vault 3-tier matching, Click-Through Floating HUD, Mini Player, System Tray playback controls, Screen-Edge Mini Lyric Pill, embedded Auto-Romanizer with on-demand downloadable Kanji dictionary, offline `whatlang` language detection, Smart Translate, and GitHub Releases update checker
- **Auto-Detecting Website Download Hub:** Updated the landing page with OS/CPU architecture detection and an **All Desktop Platforms** download matrix covering macOS `arm64`/`x86_64`, Windows `.exe`/`.zip`, and Linux `.AppImage`/`.deb`

### Install
- **macOS (Apple Silicon & Intel, 13.0+):** Download `YT-Music-Glass-macOS-arm64.dmg` (M1–M4) or `YT-Music-Glass-macOS-x86_64.dmg` (Intel), drag **YT Music Glass.app** into **Applications**, and on first launch right-click → **Open** (or run `xattr -cr "/Applications/YT Music Glass.app"`).
- **Windows (10/11 x64):** Run `YT-Music-Glass-Windows-x64-Setup.exe` (NSIS installer) or extract `YT-Music-Glass-Windows-x64-Portable.zip`. If SmartScreen prompts on first launch, click **More info → Run anyway**.
- **Linux (x86_64 / amd64):** Run `chmod +x YT-Music-Glass-Linux-x86_64.AppImage && ./YT-Music-Glass-Linux-x86_64.AppImage` or install via `sudo apt install ./YT-Music-Glass-Linux-amd64.deb`.

**Full Changelog**: https://github.com/ravizikrillah/yt-music-glass/compare/v1.1.4...v1.2.0

## [1.1.4] - 2026-11-24

Lightweight standalone native Swift macOS client for YouTube Music & YouTube (~3.5 MB DMG, zero Electron).

### Highlights
- **1-Click Update & Auto-Relaunch:** Clicking **Update & Relaunch** in About or the toolbar pill now silently mounts the downloaded DMG, stages and swaps the `.app` bundle atomically (with automatic backup rollback on failure), clears quarantine attributes, cleans up the temporary DMG, and relaunches directly into the new version without opening a Finder DMG window
- **Safe Install Path & Fallback:** Automatically updates writable in-place bundles or targets `/Applications/YT Music Glass.app` when launched from a mounted DMG or AppTranslocation, and falls back cleanly to manual **Open DMG** if destination permissions are restricted

### Install
1. Download `YT-Music-Glass-macOS-arm64.dmg` below and drag **YT Music Glass.app** into **Applications**.
2. On first launch, right-click the app → **Open** (or run `xattr -cr "/Applications/YT Music Glass.app"`).

**Full Changelog**: https://github.com/ravizikrillah/yt-music-glass/compare/v1.1.3...v1.1.4

## [1.1.3] - 2026-11-24

Lightweight standalone native Swift macOS client for YouTube Music & YouTube (~3.4 MB DMG, zero Electron).

### Highlights
- **Live Tap-to-Sync Lyrics:** Convert unsynced plain lyrics into `[mm:ss.xx]` synced karaoke by pressing `Space` (or clicking **Tap Line**) inside the Lyrics Sidebar (`⇧⌘S`), Full Screen Lyrics (`⇧⌘F`), or Command Palette (`⌘K`), with `⌫` undo, line jump, `0:00` restart, and automatic Offline Vault saving (`Tap Sync`)
- **Optional macOS Dock Album Artwork:** Dynamically renders the active song's cover art as a macOS squircle Dock icon with a mini **YT Music Glass** badge (toggleable in **Settings `⌘,`** or **`⌘K`**)
- **Optional Silent Now Playing Banner:** Displays a non-intrusive macOS notification with album artwork plus **Play / Pause** and **Next Track** actions when tracks change while in the background

### Install
1. Download `YT-Music-Glass-macOS-arm64.dmg` below and drag **YT Music Glass.app** into **Applications**.
2. On first launch, right-click the app → **Open** (or run `xattr -cr "/Applications/YT Music Glass.app"`).

**Full Changelog**: https://github.com/ravizikrillah/yt-music-glass/compare/v1.1.2...v1.1.3

## [1.1.2] - 2026-11-24

Lightweight standalone native Swift macOS client for YouTube Music & YouTube (~3.5 MB DMG, zero Electron).

### Highlights
- **Full Identity Migration to YT Music Glass:** Migrated `CFBundleIdentifier` (`com.ytmusicglass.app`), Application Support folder (`~/Library/Application Support/YTMusicGlass/`), window autosave frame (`YTMusicGlassMainWindow`), menu titles, and internal JS/CSS bridge symbols (`ytmg`)
- **Automatic Legacy Data Preservation:** Seamlessly migrates existing lyrics, translations, preferences, and saved window frame from legacy `YTMKaraoke` / `com.ytmkaraokefloat.app` installations on launch
- **Dynamic Client Header & Core Tests:** `Lrclib-Client` header now reports the running app version dynamically, backed by new migration unit tests in `scripts/test.sh`

### Install
1. Download `YT-Music-Glass-macOS-arm64.dmg` below and drag **YT Music Glass.app** into **Applications**.
2. On first launch, right-click the app → **Open** (or run `xattr -cr "/Applications/YT Music Glass.app"`).

**Full Changelog**: https://github.com/ravizikrillah/yt-music-glass/compare/v1.1.1...v1.1.2

## [1.1.1] - 2026-11-23

Lightweight standalone native Swift macOS client for YouTube Music & YouTube (~3.5 MB DMG, zero Electron).

### Highlights
- **Toolbar Auto-Update Pill:** Live status capsule in the main window toolbar (`Update v...`, `Downloading %`, `Install v...`) that opens the About & Updater window directly
- **About Auto-Recheck & Cache-Free Checks:** Opening **About YT Music Glass** now refreshes update availability automatically when idle/up-to-date/errored, backed by ephemeral `no-cache` GitHub Releases requests
- **Command Palette Full Screen Action:** Added **Open / End Full Screen Lyrics** (`⇧⌘F`) to the Quick Command Palette (`⌘K`)

### Install
1. Download `YT-Music-Glass-macOS-arm64.dmg` below and drag **YT Music Glass.app** into **Applications**.
2. On first launch, right-click the app → **Open** (or run `xattr -cr "/Applications/YT Music Glass.app"`).

**Full Changelog**: https://github.com/ravizikrillah/yt-music-glass/compare/v1.1.0...v1.1.1

## [1.1.0] - 2026-11-23

Lightweight standalone native Swift macOS client for YouTube Music & YouTube (~3.4 MB DMG, zero Electron).

### Highlights
- **Centered Full Screen Lyrics Stage (`⇧⌘F`):** Dynamic album-art ambient glow, blurred cover mesh, and smooth spring transition (also accessible from the Lyrics Sidebar or dismissed via `Esc`)
- **Immersive Karaoke Stage:** Centered 60fps word-flow synced lyrics with click-to-seek, Auto-Romaji (`⇧⌘R`), Smart Translate (`⇧⌘E`), Offline Vault save (`⇧⌘D`), and an inline **Choose Lyrics Version** picker
- **Auto-Hiding Floating Dock & Native Full Monitor:** Idle auto-fade track capsule and Obsidian Glass control dock (seek bar, Previous / Play-Pause / Next, `-0.2s` / `+0.2s` sync offset, `A-` / `A+` font size) plus a **Full Monitor / Windowed** macOS Full Screen Space toggle
- **Docs & Landing Page Polish:** Added app icon and feature gallery screenshots to README and updated the landing page with a live 60fps equalizer and interactive karaoke deck

### Install
1. Download `YT-Music-Glass-macOS-arm64.dmg` below and drag **YT Music Glass.app** into **Applications**.
2. On first launch, right-click the app → **Open** (or run `xattr -cr "/Applications/YT Music Glass.app"`).

**Full Changelog**: https://github.com/ravizikrillah/yt-music-glass/compare/v1.0.0...v1.1.0

## [1.0.0]

Lightweight standalone native Swift macOS client for YouTube Music & YouTube (~2.9 MB DMG, zero Electron).

### Highlights
- **Obsidian Liquid Glass UI & Spotify-style Floating Player Bar** with dynamic album-art logo & accent color
- **Synced Karaoke Lyrics Sidebar** (`⇧⌘S`) + **True Transparent Click-Through Floating HUD** (`⇧⌘L`)
- **100% Offline Auto-Romaji** (Korean, Japanese, Mandarin & more) + **Smart Translate** (`⇧⌘E`) with automatic same-language hiding
- **Permanent Offline Lyrics Vault** (`⇧⌘D` / `⇧⌘O`) auto-synced with YouTube Music Downloads
- **Native macOS Pro:** Menu Bar Live Lyrics (`⇧⌘B`), Floating Mini Player (`⇧⌘P`), Quick Command Palette (`⌘K`), Control Center / AirPods Now Playing, Native Settings (`⌘,`), and GitHub Releases Auto-Updater

### Install
1. Download `YT-Music-Glass-macOS-arm64.dmg` below and drag **YT Music Glass.app** into **Applications**.
2. On first launch, right-click the app → **Open** (or run `xattr -cr "/Applications/YT Music Glass.app"`).

**Full Changelog**: https://github.com/ravizikrillah/yt-music-glass/commits/v1.0.0
