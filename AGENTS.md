# AGENTS.md

Permanent operating conventions for AI coding agents working in **YT Music Glass**.

## Scope & Single Source of Truth

- **Desktop-only monorepo:** Active targets are `apps/macos/` (pure Swift, macOS 13.0+ `arm64` & `x86_64`), `apps/desktop/` (Tauri v2 Rust + WebView2/WebKitGTK for Windows & Linux), `packages/shared/`, and `website/`. Mobile targets (`iOS` / `Android`) are discontinued; keep the codebase desktop-focused.
- **Vercel compatibility:** Keep `website/` at the repository root (`Root Directory: website`).
- **Shared assets first:** Place CSS theme changes, YouTube Music DOM hooks, and web bridge updates in `packages/shared/web/` (`theme-glass.css`, `theme-installer.js`, `bridge.js`), preserving `emitToNative` support for both `webkit.messageHandlers.ytmgBridge` and `window.__TAURI_INTERNALS__`. Keep `packages/shared/swift-core/` platform-agnostic (`Foundation` / `NaturalLanguage`) and `packages/shared/test-vectors/core-vectors.json` aligned across Swift and Rust tests.

## macOS Compatibility & Packaging Constraints

- Support **macOS 13.0+** (Ventura) across separate **Apple Silicon (`arm64`)** and **Intel (`x86_64`)** DMGs (`make dmg-all`). Guard any macOS 14.0+ API with `@available(macOS 14.0, *)` or `#available(macOS 14.0, *)` plus a macOS 13 fallback.
- When changing Tauri commands or capability rules in `apps/desktop/`, update `apps/desktop/src-tauri/capabilities/` together with `apps/desktop/src-tauri/tauri.conf.json`.
- `apps/desktop/src-tauri/src/core/tests.rs` resolves `packages/shared/test-vectors/core-vectors.json` relative to `CARGO_MANIFEST_DIR`; keep `core-vectors.json` schema compatible with both Swift and Rust parsers.

## Release, Versioning & Changelog Standard (Mandatory)

Never leave GitHub Releases with an empty or auto-generated PR-only changelog. Before pushing a `vX.Y.Z` tag, complete **all** steps below in order:

1. **Synchronize the version string across every target:**
   - `apps/macos/scripts/build.sh` (`APP_VERSION="${YTMG_VERSION:-X.Y.Z}"`)
   - `apps/desktop/src-tauri/Cargo.toml` (`version = "X.Y.Z"`)
   - `apps/desktop/src-tauri/tauri.conf.json` (`"version": "X.Y.Z"`)
   - `apps/desktop/package.json` & `apps/desktop/package-lock.json`
   - User-Agent strings in `apps/desktop/src-tauri/src/core/lyrics_service.rs` and `apps/desktop/src-tauri/src/core/romanizer.rs`
   - `website/index.html` (`"softwareVersion": "X.Y.Z"`) and `website/app.js` (fallback tag `vX.Y.Z`)

2. **Add an entry at the top of `CHANGELOG.md`:**
   Use heading `## [X.Y.Z] - YYYY-MM-DD` and include all three sections below (read automatically by `.github/workflows/release.yml` via `.github/scripts/release-notes.mjs` to title the release `YT Music Glass vX.Y.Z`):
   - **Intro line:** Concise summary of the release scope and target platforms.
   - `### Highlights`: `- **Feature Name:** User-facing detail grounded in verified commits` bullets.
   - `### Install`: Exact asset instructions for `YT-Music-Glass-macOS-arm64.dmg` (plus `xattr -cr` note), `YT-Music-Glass-macOS-x86_64.dmg`, `YT-Music-Glass-Windows-x64-Setup.exe` / `YT-Music-Glass-Windows-x64-Portable.zip`, and `YT-Music-Glass-Linux-x86_64.AppImage` / `YT-Music-Glass-Linux-amd64.deb`.
   - `**Full Changelog**: https://github.com/ravizikrillah/yt-music-glass/compare/<prev_tag>...vX.Y.Z`

3. **Run local verification before committing:**
   - `node .github/scripts/release-notes.mjs --verify`
   - `make test` (`verify-shared.mjs` + Swift core tests) and `make build-all`
   - `cd apps/desktop && npm run build && cargo test --manifest-path src-tauri/Cargo.toml`
   - `node --check website/app.js`

4. **Publish cleanly:**
   - Push `main` and wait for `CI Verification Matrix` (`ci.yml`) to pass before tagging.
   - Create an annotated tag (`git tag -a vX.Y.Z -m "Release vX.Y.Z"`) — bare `git tag` without `-m` fails when git's editor is set to `false`.
   - After `Build & Release All Desktop Platforms` (`release.yml`) completes, run `gh release view vX.Y.Z` to confirm title `YT Music Glass vX.Y.Z`, structured body, and all 6 uploaded desktop assets.

## Repository Hygiene

- Keep `dist-macos/`, `apps/desktop/node_modules/`, and `apps/desktop/src-tauri/target/` untracked (gitignored).
- Only stage, commit, or push changes when explicitly authorized by the user.
