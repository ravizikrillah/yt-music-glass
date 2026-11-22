# YT Music Glass (macOS) — Specification

## Problem Statement

Listening to YouTube Music on macOS typically forces users to keep a browser tab open or rely on heavy 180+ MB Electron wrappers. Browser Document Picture-in-Picture cannot render true transparent click-through overlays, lacks native Menu Bar lyrics, and does not persist synced lyrics or translations for offline playback.

## Solution

**YT Music Glass** is a lightweight (~2.9 MB DMG), standalone native macOS desktop client built in pure Swift, SwiftUI, AppKit (`NSPanel`), CoreText, MediaPlayer, NaturalLanguage, ServiceManagement, and `WKWebView`. It reskins YouTube Music into an Obsidian Liquid Glass experience with a Spotify-style floating player bar, resizable docked Lyrics Sidebar, true-transparent click-through Floating HUD, Apple Music–style Mini Player, Menu Bar Live Lyrics, 100% offline Auto-Romanization, Smart Translation, Permanent Offline Lyrics Vault, Quick Command Palette (`⌘K`), Native Settings (`⌘,`), and GitHub Releases Auto-Updater.

## Core Capabilities

- **Native Player & Seamless Obsidian Glass UI (`WKWebView`):** Hosts `music.youtube.com` and `www.youtube.com` with persistent Google Sign-In, unified macOS titlebar, Spotify-style 3-column floating glass player bar (`Track | Prev-Play-Next + Progress | Lyrics & Utils`), dynamic album-art color logo & accent adaptation, and clean Watch tabs (`UP NEXT` & `RELATED`).
- **Multi-Surface Synced Lyrics:**
  - **Docked Resizable Lyrics Sidebar (`⇧⌘S` / `Shift+L`):** Draggable divider (`260pt–760pt`), word-flow progressive karaoke highlighting, click-to-seek, per-track sync offsets, and built-in LRCLIB Lyrics Picker.
  - **True Transparent Floating HUD (`⇧⌘L`):** `0%–85%` opacity frosted glass `NSPanel`, Click-Through Lock (`⇧⌘K`), Compact/Full modes (`⇧⌘M`), visible across all macOS Spaces and Fullscreen apps.
  - **Apple Music–style Floating Mini Player (`⇧⌘P`):** Compact `356×136pt` glass widget with cover art, playback controls, live 1-line karaoke strip, and seek bar.
  - **Menu Bar Live Lyrics (`⇧⌘B`):** Active lyric line displayed next to the top macOS Menu Bar icon; auto-collapses when paused.
- **Auto-Romanization & Smart Translation:**
  - 100% offline pronunciation guide for Korean (Revised Romanization with phonological rules), Japanese (Kanji/Kana via `CFStringTokenizer`), Mandarin Pinyin, and other non-Latin scripts in a 3-tier layout (original script → bold Romaji → translation).
  - Smart Translate (`⇧⌘E`) with From → To language picker, disk cache, and automatic same-language hiding.
- **Permanent Offline Lyrics Vault (`⇧⌘D` / `⇧⌘O`):** Auto-discovers tracks from YouTube Music's Downloads page and Download button clicks, pinning synced lyrics & active translations permanently on disk with resilient 3-tier offline matching (`trackKey` → `videoId` → normalized `artist + title`).
- **Native macOS Integrations & Distribution:**
  - macOS Control Center / Now Playing & AirPods remote commands (`MediaPlayer.framework`).
  - Quick Command Palette (`⌘K`), Native Settings (`⌘,`) with live **Roboto ↔ SF Pro** font switcher & **Launch at Login** (`SMAppService`), Live Mini Audio Visualizer, About Window, and GitHub Releases Auto-Updater.
  - Automated `.dmg` packaging (`make dmg`), GitHub Actions release pipeline (`.github/workflows/release.yml`), and SEO-friendly Vercel landing page (`website/`).

## Verification

- Automated Swift unit test suite (`make test`) verifies metadata normalization, LRC/Enhanced LRC parsing, sync/seek math, Korean/Japanese offline romanization, language detection & auto-skip rules, Offline Vault persistence & 3-tier matching, and SemVer update comparisons.
- Clean zero-warning compilation, ad-hoc signing, and compressed UDZO `.dmg` packaging verified via `make dmg`.
