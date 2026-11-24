# YT Music Glass — Multi-Platform Desktop Specification

## Problem Statement

Listening to YouTube Music on desktop typically forces users into browser tabs, heavy 180+ MB Electron wrappers, or single-architecture macOS builds (Apple Silicon only). Users on Mac Intel, Windows, and Linux need the same Obsidian Liquid Glass interface, synced word-flow karaoke lyrics, Auto-Romaji, Smart Translate, and Offline Vault without Electron bloat.

## Architecture (Hybrid Desktop Monorepo)

- **`apps/macos/` (macOS 13.0+ Ventura+, `arm64` & `x86_64`):** Pure Swift (`AppKit`, `SwiftUI`, `WKWebView`, `MediaPlayer`, `ServiceManagement`, `UserNotifications`) producing separate lightweight `arm64.dmg` and `x86_64.dmg` installers.
- **`apps/desktop/` (Windows & Linux):** Tauri v2 (`Rust` + `WebView2` / `WebKitGTK` + `whatlang`), producing Windows NSIS `.exe` + Portable `.zip` and Linux `.AppImage` + `.deb`. Includes System Tray controls and an optional Screen-Edge Mini Lyric Pill replacing macOS Menu Bar live lyrics.
- **`packages/shared/`:**
  - `web/`: Single-source `theme-glass.css`, `theme-installer.js`, and cross-platform `bridge.js` (`emitToNative` supporting WebKit and Tauri IPC).
  - `swift-core/`: Shared `Foundation` + `NaturalLanguage` Swift modules (`AppIdentity`, `Models`, `MetadataNormalizer`, `LrcParser`, `TapSyncEngine`, `Romanizer`, `TranslationService`, `LyricsService`, `SharedWebAssets`).
  - `resources/`: Shared `AppIcon.png` and `Fonts/Roboto-*.ttf`.
  - `test-vectors/`: Canonical JSON vectors (`core-vectors.json`) and Node validation script (`verify-shared.mjs`).
- **`website/` & `.github/workflows/`:** Static Vercel landing page with OS/arch auto-detect + All Desktop Platforms matrix, backed by CI verification (`ci.yml`) and 4-target GitHub Release builds (`release.yml`).

## Verification

- `node packages/shared/scripts/verify-shared.mjs` validates shared CSS/JS syntax and JSON test vectors.
- `make test` executes Swift core unit tests (`MetadataNormalizer`, `LrcParser`, `SyncCalculator`, `Romanizer`, `TranslationService`, Offline Vault 3-tier matching, `TapSyncSession`, `SemVerComparator`, `SharedWebAssets`).
- `make build-all` / `make dmg-all` verifies both `arm64-apple-macos13.0` and `x86_64-apple-macos13.0` native macOS builds and DMGs.
- CI pipelines validate Tauri Rust tests (`cargo test`) and frontend compilation (`npm run build`) on Windows and Linux.
