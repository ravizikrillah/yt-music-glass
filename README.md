# YT Music Glass (macOS)

Lightweight standalone native Swift macOS client for **YouTube Music** and **YouTube** (DMG / zero Electron, ~1.5 MB binary) — featuring an **Obsidian Liquid Glass** interface, **Spotify-style floating player bar**, **Synced Karaoke Lyrics Sidebar**, **True Transparent Floating HUD**, **Auto-Romaji**, **Smart Translate**, **Offline Lyrics Vault**, **Mini Player**, **Menu Bar Live Lyrics**, and **Quick Command Palette (`⌘K`)**.

## Features

- **Native YouTube Music & YouTube Player:** 1-click toolbar switcher between `music.youtube.com` and `www.youtube.com`, persistent Google Sign-In (`WKWebsiteDataStore.default()`), Safari macOS User-Agent + Google OAuth popup support, and native `Cmd+C/V/A` editing.
- **Docked Resizable Lyrics Sidebar (`⇧⌘S`):** Integrated right-side glass lyrics drawer synced to album-art ambient colors, with a draggable divider (`280pt–640pt`, double-click to reset).
- **Auto-Romanization (Romaji / Korean / Pinyin / Non-Latin) (`⇧⌘R`):**
  - 100% offline pronunciation guide for Korean (Revised Romanization with phonological rules), Japanese (Kanji/Kana → Romaji via `CFStringTokenizer`), Mandarin Pinyin, Cyrillic, Thai, Arabic, Greek, and Devanagari.
  - Matches mobile karaoke hierarchy: compact original script on top, bold hero romanized karaoke sweep in the middle, and skips pure Latin lines automatically.
- **Smart Lyrics Translation (`⇧⌘E`):**
  - Top toolbar toggle + **From → To** language picker (`Auto`, `EN`, `ID`, `JA`, `KO`, `ZH`, etc.) with persistent disk cache.
  - **Auto language-mismatch filtering:** automatically hides translations when the song (or individual line) is already in your chosen target language (e.g., Indonesian songs stay clean when target is `ID`, and translate automatically when target is switched to `EN`).
- **Offline Karaoke Vault (`⇧⌘D` / `⇧⌘O`):**
  - Automatically detects YouTube Music **Downloads** (`/downloads`), downloaded albums/playlists, and Download button clicks to pre-download & permanently pin synced lyrics (plus active translations) locally on disk.
  - 3-tier offline matching (`trackKey` → `videoId` → normalized `artist + title`) + 100% offline Auto-Romanization ensure full karaoke keeps working without internet.
- **Native macOS Integrations:**
  - **Menu Bar Live Lyrics (`⇧⌘B`):** Displays the active lyric line (with Auto-Romaji) directly in the macOS top Menu Bar next to the microphone icon; auto-collapses when paused.
  - **Apple Music–style Mini Player (`⇧⌘P`):** Compact Obsidian Glass floating widget (`356×136pt`) with album artwork, Prev/Play-Pause/Next controls, live 1-line karaoke strip (+ optional translation), and interactive seek bar across all Spaces.
  - **macOS Control Center / Now Playing & AirPods:** Syncs track metadata, artwork, elapsed time, and media key / AirPods remote commands via `MediaPlayer.framework`.
  - **Quick Command Palette (`⌘K`):** Raycast/Spotlight-style fuzzy launcher to jump to Home/Downloads/Library, search YouTube Music directly, switch Translate languages, or toggle any mode via keyboard.
- **Native Settings Window (`⌘,`), About & GitHub Auto-Updater:** Live font switcher (**Roboto** vs **SF Pro** across both lyrics and web UI), **Launch at Login** (`ServiceManagement`), animated theme-colored mini equalizer bars, Offline Vault management, **About YT Music Glass**, and built-in **GitHub Releases Auto-Updater** (`Check for Updates…`).
- **Landing Page (`website/`):** Pure static SEO-friendly download page ready to deploy on Vercel (`https://yt-music-glass.vercel.app`) — automatically pulls the latest macOS `.dmg` from GitHub Releases.
- **True Transparent Floating Lyrics (`NSPanel`):**
  - Smooth opacity slider from **`0%` (pure floating karaoke text with crisp double shadow)** up to **`85%` native macOS Frosted Glass** (`NSVisualEffectView`).
  - **Drag Anywhere** on the top grabber bar, header, or empty HUD area to position anywhere on screen (position saved per mode).
  - **Click-Through Lock (`⇧⌘K`):** Pass mouse clicks & scrolling straight through the transparent lyrics to VS Code, browsers, or any app behind it.
  - Floats cleanly across **all macOS Spaces** and **Fullscreen apps**.
- **Dual Mode (`⇧⌘M`):** Switch between **Compact 2-Line Strip** and **Full Multi-Line Karaoke Card** (smooth auto-scroll).
- **Karaoke Sync Engine:**
  - Direct in-process `WKScriptMessageHandler` bridge (zero WebSocket / zero localhost ports).
  - 60fps word-by-word highlight (Enhanced LRC), smooth left-to-right active-line sweep, and animated `•••` instrumental break dots.
  - **Click-to-Seek** on any lyric line, **Sync Offset (`-0.2s` / `+0.2s` / Reset)** saved per track, and built-in **Lyrics Picker** to search/switch LRCLIB candidates.
  - Smart YouTube title cleaning (`(Official Music Video)`, `(Lirik Lagu)`, `- Topic`, `VEVO`, record-label `Artist - Title` parsing), LRCLIB exact + fuzzy ranking, YouTube Music native lyrics fallback, ad detection, and local disk cache in `~/Library/Application Support/YTMKaraoke/`.
- **Background Playback & Menu Bar:** Closing the main player window keeps music and floating lyrics running seamlessly; reopen from the Dock or the Menu Bar microphone icon. Also includes the circular **Float Lyrics** button (`Shift + L`) right inside YouTube Music / YouTube's player bar.

## Build, Test & Install

Requires macOS 14+ with Apple Command Line Tools (`swiftc`).

```bash
make test     # Run Swift core unit tests
make build    # Compile dist-macos/YT Music Glass.app
make run      # Build and launch YT Music Glass.app
make install  # Build and install directly into /Applications/YT Music Glass.app
make dmg      # Build distributable macOS installer DMG (dist-macos/YT-Music-Glass-macOS-arm64.dmg)
```

## Release & Deploy

- **Publish a macOS Release (Auto-Update + Website Download):**
  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```
  GitHub Actions (`.github/workflows/release.yml`) automatically runs `make test`, compiles `YT-Music-Glass-macOS-arm64.dmg`, and publishes it to GitHub Releases. Both the app's built-in **Check for Updates…** and the Vercel download button pick up new releases automatically.
- **Deploy Landing Page on Vercel:** Import `ravizikrillah/yt-music-glass` in Vercel and set **Root Directory** to `website` (Framework Preset: `Other`, no build step required).

## Author

Built by **Ravi Bangkit Nur Zikrillah** ([@ravizikrillah](https://github.com/ravizikrillah)) · [Website](https://yt-music-glass.vercel.app)

## Keyboard Shortcuts

- `⌘K` — Open Quick Command Palette & Instant Song Search
- `⌘,` — Open Native Settings Window
- `Shift + L` (inside player) or `⇧⌘S` — Show / Hide Docked Right Lyrics Sidebar
- `⇧⌘L` — Show / Hide Separate Transparent Floating Lyrics Window
- `⇧⌘P` — Show / Hide Apple Music–style Floating Mini Player
- `⇧⌘B` — Toggle Menu Bar Live Lyrics
- `⇧⌘K` — Toggle Click-Through Lock (Floating Window)
- `⇧⌘M` — Toggle Compact / Full Mode (Floating Window)
- `⇧⌘E` — Toggle Smart Lyrics Translation
- `⇧⌘R` — Toggle Auto Romaji / Romanization
- `⇧⌘D` — Save Current Track Lyrics Offline
- `⇧⌘O` — Download Offline Lyrics for Current Page (Downloads / Album / Playlist)
- `⇧⌘T` — Toggle Apple Music / macOS Glass Theme vs. Original
- `⌘R` — Reload Page
