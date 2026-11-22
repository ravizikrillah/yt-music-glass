import Foundation

enum ThemeStyles {
    /// Complete Apple Music / macOS Liquid Glass reskin for music.youtube.com
    /// and subtle native macOS scrollbar/dark polish for www.youtube.com.
    static let appleGlassCSS = #"""
:root {
  --ytmk-accent-rgb: 244, 63, 108;
  --ytmk-bg-top: #24111c;
  --ytmk-bg-bottom: #0b0b11;
  --ytmk-artwork-url: none;
  --ytmk-glass: rgba(20, 20, 28, 0.62);
  --ytmk-glass-strong: rgba(18, 18, 25, 0.78);
  --ytmk-border: rgba(255, 255, 255, 0.09);
  --ytmk-border-strong: rgba(255, 255, 255, 0.14);
}

/* Native macOS translucent scrollbars across YouTube Music & YouTube */
* {
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.22) transparent;
}

::-webkit-scrollbar {
  width: 7px;
  height: 7px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 999px;
}

::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.34);
}

/* =====================================================================
   YOUTUBE MUSIC — SEAMLESS MACOS DARK GLASS POLISH
   Preserves YouTube Music's native web background & smooth hero fade-out
   while keeping clean typography, rounded cards, and Floating Glass Player Bar.
   ===================================================================== */

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"],
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] body {
  -webkit-font-smoothing: antialiased !important;
  background-color: #030303 !important;
  --ytmusic-brand-color: rgb(var(--ytmk-accent-rgb)) !important;
  --yt-spec-call-to-action: rgb(var(--ytmk-accent-rgb)) !important;
}

/* Hide YouTube Music web upsell & promo clutter */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-mealbar-promo-renderer,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-statement-banner-renderer,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-pivot-bar-renderer,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] tp-yt-paper-dialog.ytmusic-popup-container[aria-label*="Premium"],
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] a.yt-simple-endpoint[href*="music_premium"] {
  display: none !important;
}

/* Seamless Top Nav Bar — blends naturally into web canvas & native titlebar */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-nav-bar,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] #nav-bar-background.ytmusic-app-layout {
  border-bottom: 1px solid rgba(255, 255, 255, 0.05) !important;
}

/* Dynamic theme-colored Music logo synced with current song palette */
#ytmk-dynamic-logo {
  display: none;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-nav-bar a.ytmk-has-dyn-logo > picture,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-nav-bar a.ytmk-has-dyn-logo > img.logo {
  display: none !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-nav-bar a.ytmk-has-dyn-logo #ytmk-dynamic-logo {
  display: inline-flex !important;
  align-items: center !important;
  gap: 6px !important;
  height: 26px !important;
  text-decoration: none !important;
  user-select: none !important;
  -webkit-user-select: none !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] #ytmk-dynamic-logo .ytmk-logo-disc {
  fill: rgb(var(--ytmk-accent-rgb)) !important;
  transition: fill 0.55s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] #ytmk-dynamic-logo .ytmk-logo-wordmark {
  font-family: "YouTube Sans", "Roboto", -apple-system, sans-serif !important;
  font-size: 20px !important;
  font-weight: 700 !important;
  letter-spacing: -0.03em !important;
  color: #ffffff !important;
  line-height: 1 !important;
}

/* macOS Spotlight-style Search Pill */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-search-box .search-box.ytmusic-search-box {
  background: rgba(255, 255, 255, 0.07) !important;
  border: 1px solid rgba(255, 255, 255, 0.11) !important;
  border-radius: 12px !important;
  backdrop-filter: blur(20px) !important;
  -webkit-backdrop-filter: blur(20px) !important;
  transition: background 0.18s ease, border-color 0.18s ease, box-shadow 0.18s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-search-box[opened] .search-box.ytmusic-search-box,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-search-box .search-box.ytmusic-search-box:focus-within {
  background: rgba(18, 18, 22, 0.94) !important;
  border-color: rgba(var(--ytmk-accent-rgb), 0.65) !important;
  box-shadow: 0 0 0 3px rgba(var(--ytmk-accent-rgb), 0.18) !important;
}

/* Seamless Left Navigation Sidebar (matches native web dark #030303) */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] #guide-wrapper.ytmusic-app-layout,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-guide-renderer,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] #mini-guide-background.ytmusic-app-layout {
  background: #030303 !important;
  border-right: 1px solid rgba(255, 255, 255, 0.06) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-guide-entry-renderer tp-yt-paper-item {
  border-radius: 10px !important;
  margin: 2px 8px !important;
  transition: background 0.16s ease, color 0.16s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-guide-entry-renderer[active] tp-yt-paper-item {
  background: rgba(var(--ytmk-accent-rgb), 0.22) !important;
  box-shadow: inset 0 0 0 1px rgba(var(--ytmk-accent-rgb), 0.35) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-guide-entry-renderer tp-yt-paper-item:hover {
  background: rgba(255, 255, 255, 0.09) !important;
}

/* Keep native YouTube Music typography (YouTube Sans + Roboto) by default;
   when user picks SF Pro in Settings (⌘,), unify the entire web UI to Apple SF Pro! */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] .title.ytmusic-carousel-shelf-basic-header-renderer,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] h2.title,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] yt-formatted-string.title {
  letter-spacing: -0.01em !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"],
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"] body,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"] yt-formatted-string,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"] h1,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"] h2,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"] a,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"] input,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"] tp-yt-paper-tab,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"][data-ytmk-font="sfpro"] #ytmk-dynamic-logo .ytmk-logo-wordmark {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif !important;
}

/* Mood / Genre Filter Chips & Queue Save Chip -> Frosted Glass Pills with crisp white text & icons */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint {
  background: rgba(255, 255, 255, 0.09) !important;
  color: rgba(255, 255, 255, 0.94) !important;
  border: 1px solid rgba(255, 255, 255, 0.14) !important;
  border-radius: 999px !important;
  backdrop-filter: blur(16px) !important;
  -webkit-backdrop-filter: blur(16px) !important;
  transition: background 0.16s ease, border-color 0.16s ease, transform 0.14s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint:hover {
  background: rgba(255, 255, 255, 0.16) !important;
  border-color: rgba(255, 255, 255, 0.24) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint yt-icon,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint yt-formatted-string,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint .text,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint svg {
  color: rgba(255, 255, 255, 0.94) !important;
  fill: currentColor !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-chip-cloud-chip-renderer[is-selected] a.yt-simple-endpoint {
  background: rgb(var(--ytmk-accent-rgb)) !important;
  color: #ffffff !important;
  border-color: transparent !important;
}

/* Album & Playlist Cards — Rounded macOS Corners & Subtle Hover Lift */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-two-row-item-renderer .image-wrapper,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-two-row-item-renderer ytmusic-thumbnail-renderer,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-two-row-item-renderer img#img {
  border-radius: 12px !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-two-row-item-renderer {
  transition: transform 0.2s cubic-bezier(0.22, 1, 0.36, 1) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-two-row-item-renderer:hover {
  transform: translateY(-3px) !important;
}

/* Song List Rows — Clean Rounded Hover Pills */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-responsive-list-item-renderer {
  border-radius: 10px !important;
  border-bottom-color: rgba(255, 255, 255, 0.04) !important;
  padding-left: 8px !important;
  padding-right: 8px !important;
  transition: background 0.15s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-responsive-list-item-renderer:hover {
  background: rgba(255, 255, 255, 0.07) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-responsive-list-item-renderer ytmusic-thumbnail-renderer,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-responsive-list-item-renderer img#img {
  border-radius: 7px !important;
}

/* Expanded Now-Playing / Watch Page — Seamless Pure Dark */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-page {
  background: #030303 !important;
}

/* Hide redundant YTM Lyrics & Comments tabs so only UP NEXT and RELATED remain */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-page tp-yt-paper-tab[data-ytmk-hidden-tab="true"] {
  display: none !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player#player {
  border-radius: 16px !important;
  overflow: hidden !important;
  box-shadow: 0 24px 64px rgba(0, 0, 0, 0.58), 0 0 42px rgba(var(--ytmk-accent-rgb), 0.16) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-queue-item {
  border-radius: 10px !important;
  border-bottom-color: rgba(255, 255, 255, 0.04) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-queue-item[selected] {
  background: rgba(var(--ytmk-accent-rgb), 0.2) !important;
}

/* =====================================================================
   FLOATING GLASS PILL BOTTOM PLAYER BAR — SPOTIFY DESKTOP 3-COLUMN LAYOUT
   Left: Track artwork & info | Center: Prev/Play/Next + [Cur | Bar | Dur] | Right: Lyrics & Utils
   ===================================================================== */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar {
  box-sizing: border-box !important;
  position: fixed !important;
  left: 12px !important;
  right: 12px !important;
  bottom: 12px !important;
  width: calc(100% - 24px) !important;
  max-width: calc(100vw - 24px) !important;
  height: 82px !important;
  border-radius: 20px !important;
  background: rgba(18, 18, 25, 0.84) !important;
  backdrop-filter: blur(38px) saturate(1.75) !important;
  -webkit-backdrop-filter: blur(38px) saturate(1.75) !important;
  border: 1px solid var(--ytmk-border-strong) !important;
  box-shadow:
    0 18px 48px rgba(0, 0, 0, 0.54),
    inset 0 1px 0 rgba(255, 255, 255, 0.11) !important;
  display: grid !important;
  grid-template-columns: minmax(190px, 1fr) minmax(250px, 1.35fr) minmax(160px, 1fr) !important;
  grid-template-rows: 1fr auto !important;
  grid-template-areas:
    "track controls right"
    "track progress right" !important;
  align-items: center !important;
  column-gap: 14px !important;
  row-gap: 2px !important;
  padding: 6px 18px 8px 16px !important;
  margin: 0 !important;
  overflow: visible !important;
  transition: border-color 0.35s ease, box-shadow 0.35s ease !important;
}

/* LEFT COLUMN: Track cover + Title/Artist + Like/Dislike/Menu */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .middle-controls.ytmusic-player-bar {
  grid-area: track !important;
  min-width: 0 !important;
  width: 100% !important;
  padding: 0 !important;
  margin: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: flex-start !important;
  gap: 10px !important;
  overflow: hidden !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .content-info-wrapper.ytmusic-player-bar {
  min-width: 0 !important;
  max-width: 100% !important;
  overflow: hidden !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .title.ytmusic-player-bar,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .byline.ytmusic-player-bar {
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .middle-controls-buttons.ytmusic-player-bar {
  flex-shrink: 0 !important;
  display: flex !important;
  align-items: center !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar img.image {
  width: 46px !important;
  height: 46px !important;
  border-radius: 9px !important;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.45) !important;
  flex-shrink: 0 !important;
}

/* CENTER TOP: Prev / Play-Pause / Next buttons */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .left-controls.ytmusic-player-bar {
  grid-area: controls !important;
  min-width: 0 !important;
  width: 100% !important;
  padding: 0 !important;
  margin: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .left-controls-buttons.ytmusic-player-bar {
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  gap: 8px !important;
}

/* Hide legacy combined "1:37 / 3:14" text — split cleanly to left & right ends of progress bar */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .time-info.ytmusic-player-bar {
  display: none !important;
}

/* Crisp centered circular halo around Play/Pause button (Spotify Desktop proportions) */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .previous-button,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .next-button {
  width: 32px !important;
  height: 32px !important;
  padding: 0 !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
  --iron-icon-width: 20px !important;
  --iron-icon-height: 20px !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button {
  box-sizing: border-box !important;
  background: rgba(255, 255, 255, 0.08) !important;
  border: 1px solid rgba(255, 255, 255, 0.24) !important;
  border-radius: 50% !important;
  width: 36px !important;
  height: 36px !important;
  padding: 0 !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
  --iron-icon-width: 22px !important;
  --iron-icon-height: 22px !important;
  transition: transform 0.14s ease, background 0.16s ease, border-color 0.16s ease !important;
}

/* Center every nested button/icon wrapper so the 22px SVG sits dead-center inside the 36px circle */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button #button,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button button,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button #icon,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button yt-icon,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button .yt-icon-shape,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button .yt-icon-shape > div,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .previous-button #button,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .previous-button button,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .next-button #button,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .next-button button {
  width: 100% !important;
  height: 100% !important;
  margin: 0 !important;
  padding: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button svg {
  width: 22px !important;
  height: 22px !important;
  margin: auto !important;
  display: block !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #play-pause-button:hover {
  background: rgba(255, 255, 255, 0.16) !important;
  border-color: rgba(255, 255, 255, 0.40) !important;
  transform: scale(1.06) !important;
}

/* RIGHT COLUMN: Lyrics button, Volume, Repeat, Shuffle, Expand */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .right-controls.ytmusic-player-bar {
  grid-area: right !important;
  min-width: 0 !important;
  width: 100% !important;
  padding: 0 !important;
  margin: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: flex-end !important;
}

/* Hide Polymer's default top-floating slider out of grid flow in glass theme */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #progress-bar {
  position: absolute !important;
  top: 0 !important;
  left: 0 !important;
  opacity: 0 !important;
  pointer-events: none !important;
  height: 0 !important;
  width: 0 !important;
  overflow: hidden !important;
}

/* CENTER BOTTOM: Spotify-style [ 1:35  ━━━━━━━━░░░░░  3:09 ] right under Prev / Play / Next */
#ytmk-progress-bar {
  display: none;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar {
  grid-area: progress !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  gap: 10px !important;
  width: 100% !important;
  max-width: 560px !important;
  justify-self: center !important;
  height: 18px !important;
  user-select: none !important;
  -webkit-user-select: none !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-time {
  font-size: 11px !important;
  font-weight: 500 !important;
  font-variant-numeric: tabular-nums !important;
  color: rgba(255, 255, 255, 0.56) !important;
  min-width: 34px !important;
  line-height: 1 !important;
  flex-shrink: 0 !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-cur {
  text-align: right !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-dur {
  text-align: left !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-hit {
  position: relative !important;
  flex: 1 1 auto !important;
  min-width: 90px !important;
  height: 16px !important;
  display: flex !important;
  align-items: center !important;
  cursor: pointer !important;
  touch-action: none !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-track {
  position: relative !important;
  width: 100% !important;
  height: 4.5px !important;
  border-radius: 999px !important;
  background: rgba(255, 255, 255, 0.22) !important;
  overflow: hidden !important;
  transition: height 0.14s ease, background 0.14s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-hit:hover .ytmk-pb-track,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar.dragging .ytmk-pb-track {
  height: 6px !important;
  background: rgba(255, 255, 255, 0.28) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-buf {
  position: absolute !important;
  top: 0 !important;
  left: 0 !important;
  bottom: 0 !important;
  width: 0%;
  border-radius: 999px !important;
  background: rgba(255, 255, 255, 0.15) !important;
  pointer-events: none !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-fill {
  position: absolute !important;
  top: 0 !important;
  left: 0 !important;
  bottom: 0 !important;
  width: 0%;
  border-radius: 999px !important;
  background: rgb(var(--ytmk-accent-rgb)) !important;
  pointer-events: none !important;
  transition: background-color 0.45s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-knob {
  position: absolute !important;
  top: 50% !important;
  left: 0%;
  width: 12px !important;
  height: 12px !important;
  border-radius: 50% !important;
  background: #ffffff !important;
  box-shadow: 0 1px 6px rgba(0, 0, 0, 0.65) !important;
  transform: translate(-50%, -50%) scale(0.55) !important;
  opacity: 0 !important;
  pointer-events: none !important;
  transition: opacity 0.15s ease, transform 0.15s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-hit:hover .ytmk-pb-knob,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar.dragging .ytmk-pb-knob {
  opacity: 1 !important;
  transform: translate(-50%, -50%) scale(1) !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-tooltip {
  position: absolute !important;
  bottom: 20px !important;
  left: 0%;
  transform: translateX(-50%) !important;
  padding: 2px 7px !important;
  border-radius: 6px !important;
  background: rgba(16, 16, 22, 0.94) !important;
  border: 1px solid rgba(255, 255, 255, 0.14) !important;
  color: rgba(255, 255, 255, 0.94) !important;
  font-size: 10.5px !important;
  font-weight: 600 !important;
  font-variant-numeric: tabular-nums !important;
  white-space: nowrap !important;
  pointer-events: none !important;
  opacity: 0 !important;
  transition: opacity 0.12s ease !important;
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar .ytmk-pb-hit:hover .ytmk-pb-tooltip,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar #ytmk-progress-bar.dragging .ytmk-pb-tooltip {
  opacity: 1 !important;
}

/* Responsive compaction when lyrics sidebar is dragged wide */
@media (max-width: 900px) {
  html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar {
    grid-template-columns: minmax(150px, 1fr) minmax(210px, 1.35fr) auto !important;
    column-gap: 10px !important;
    padding: 6px 12px 8px 12px !important;
  }
  html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .middle-controls-buttons.ytmusic-player-bar {
    display: none !important;
  }
}

@media (max-width: 680px) {
  html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar {
    grid-template-columns: minmax(120px, 0.9fr) minmax(175px, 1.45fr) auto !important;
    column-gap: 8px !important;
  }
  html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .volume-slider.ytmusic-player-bar,
  html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .repeat.ytmusic-player-bar,
  html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] ytmusic-player-bar .shuffle.ytmusic-player-bar {
    display: none !important;
  }
}

html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] #player-bar-background.ytmusic-app-layout {
  display: none !important;
}

/* Give page scroll area breathing room above the floating glass player pill */
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] #contents.ytmusic-browse-response,
html[data-ytmk-theme="apple-glass"][data-ytmk-site="ytm"] #contents.ytmusic-section-list-renderer {
  padding-bottom: 112px !important;
}
"""#

    /// JS snippet that installs the theme stylesheet + exposes live palette/toggle setters.
    static var installerScript: String {
        let escapedCSS = appleGlassCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")

        return """
        (function () {
          const STYLE_ID = 'ytmk-apple-glass-style';
          const site = location.hostname.startsWith('music.') ? 'ytm' : 'youtube';
          document.documentElement.dataset.ytmkSite = site;

          if (!document.getElementById(STYLE_ID)) {
            const style = document.createElement('style');
            style.id = STYLE_ID;
            style.textContent = `\(escapedCSS)`;
            (document.head || document.documentElement).appendChild(style);
          }

          window.__ytmKaraokeSetTheme = function (enabled) {
            document.documentElement.dataset.ytmkTheme = enabled ? 'apple-glass' : 'original';
          };

          window.__ytmKaraokeSetFontStyle = function (style) {
            document.documentElement.dataset.ytmkFont = style === 'sfpro' ? 'sfpro' : 'roboto';
          };

          window.__ytmKaraokeSetPalette = function (accentRgb, bgTop, bgBottom, artworkUrl) {
            const root = document.documentElement.style;
            root.setProperty('--ytmk-accent-rgb', accentRgb);
            root.setProperty('--ytmk-bg-top', bgTop);
            root.setProperty('--ytmk-bg-bottom', bgBottom);
            if (artworkUrl) {
              const safeUrl = String(artworkUrl).replace(/["'\\\\()\\n\\r]/g, '');
              root.setProperty('--ytmk-artwork-url', 'url("' + safeUrl + '")');
            } else {
              root.setProperty('--ytmk-artwork-url', 'none');
            }
          };

          document.documentElement.dataset.ytmkTheme = 'apple-glass';
        })();
        """
    }
}
