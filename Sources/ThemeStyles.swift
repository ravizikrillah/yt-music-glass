import Foundation

enum ThemeStyles {
    /// Complete Apple Music / macOS Liquid Glass reskin for music.youtube.com
    /// and subtle native macOS scrollbar/dark polish for www.youtube.com.
    static let appleGlassCSS = #"""
:root {
  --ytmg-accent-rgb: 244, 63, 108;
  --ytmg-bg-top: #24111c;
  --ytmg-bg-bottom: #0b0b11;
  --ytmg-artwork-url: none;
  --ytmg-glass: rgba(20, 20, 28, 0.62);
  --ytmg-glass-strong: rgba(18, 18, 25, 0.78);
  --ytmg-border: rgba(255, 255, 255, 0.09);
  --ytmg-border-strong: rgba(255, 255, 255, 0.14);
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

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"],
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] body {
  -webkit-font-smoothing: antialiased !important;
  background-color: #030303 !important;
  --ytmusic-brand-color: rgb(var(--ytmg-accent-rgb)) !important;
  --yt-spec-call-to-action: rgb(var(--ytmg-accent-rgb)) !important;
}

/* Hide YouTube Music web upsell & promo clutter */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-mealbar-promo-renderer,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-statement-banner-renderer,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-pivot-bar-renderer,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] tp-yt-paper-dialog.ytmusic-popup-container[aria-label*="Premium"],
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] a.yt-simple-endpoint[href*="music_premium"] {
  display: none !important;
}

/* Seamless Top Nav Bar — blends naturally into web canvas & native titlebar */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-nav-bar,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] #nav-bar-background.ytmusic-app-layout {
  border-bottom: 1px solid rgba(255, 255, 255, 0.05) !important;
}

/* Dynamic theme-colored Music logo synced with current song palette */
#ytmg-dynamic-logo {
  display: none;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-nav-bar a.ytmg-has-dyn-logo > picture,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-nav-bar a.ytmg-has-dyn-logo > img.logo {
  display: none !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-nav-bar a.ytmg-has-dyn-logo #ytmg-dynamic-logo {
  display: inline-flex !important;
  align-items: center !important;
  gap: 6px !important;
  height: 26px !important;
  text-decoration: none !important;
  user-select: none !important;
  -webkit-user-select: none !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] #ytmg-dynamic-logo .ytmg-logo-disc {
  fill: rgb(var(--ytmg-accent-rgb)) !important;
  transition: fill 0.55s ease !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] #ytmg-dynamic-logo .ytmg-logo-wordmark {
  font-family: "YouTube Sans", "Roboto", -apple-system, sans-serif !important;
  font-size: 20px !important;
  font-weight: 700 !important;
  letter-spacing: -0.03em !important;
  color: #ffffff !important;
  line-height: 1 !important;
}

/* macOS Spotlight-style Search Pill */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-search-box .search-box.ytmusic-search-box {
  background: rgba(255, 255, 255, 0.07) !important;
  border: 1px solid rgba(255, 255, 255, 0.11) !important;
  border-radius: 12px !important;
  backdrop-filter: blur(20px) !important;
  -webkit-backdrop-filter: blur(20px) !important;
  transition: background 0.18s ease, border-color 0.18s ease, box-shadow 0.18s ease !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-search-box[opened] .search-box.ytmusic-search-box,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-search-box .search-box.ytmusic-search-box:focus-within {
  background: rgba(18, 18, 22, 0.94) !important;
  border-color: rgba(var(--ytmg-accent-rgb), 0.65) !important;
  box-shadow: 0 0 0 3px rgba(var(--ytmg-accent-rgb), 0.18) !important;
}

/* Seamless Left Navigation Sidebar (matches native web dark #030303) */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] #guide-wrapper.ytmusic-app-layout,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-guide-renderer,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] #mini-guide-background.ytmusic-app-layout {
  background: #030303 !important;
  border-right: 1px solid rgba(255, 255, 255, 0.06) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-guide-entry-renderer tp-yt-paper-item {
  border-radius: 10px !important;
  margin: 2px 8px !important;
  transition: background 0.16s ease, color 0.16s ease !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-guide-entry-renderer[active] tp-yt-paper-item {
  background: rgba(var(--ytmg-accent-rgb), 0.22) !important;
  box-shadow: inset 0 0 0 1px rgba(var(--ytmg-accent-rgb), 0.35) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-guide-entry-renderer tp-yt-paper-item:hover {
  background: rgba(255, 255, 255, 0.09) !important;
}

/* Keep native YouTube Music typography (YouTube Sans + Roboto) by default;
   when user picks SF Pro in Settings (⌘,), unify the entire web UI to Apple SF Pro! */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] .title.ytmusic-carousel-shelf-basic-header-renderer,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] h2.title,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] yt-formatted-string.title {
  letter-spacing: -0.01em !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"],
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"] body,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"] yt-formatted-string,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"] h1,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"] h2,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"] a,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"] input,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"] tp-yt-paper-tab,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"][data-ytmg-font="sfpro"] #ytmg-dynamic-logo .ytmg-logo-wordmark {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif !important;
}

/* Mood / Genre Filter Chips & Queue Save Chip -> Frosted Glass Pills with crisp white text & icons */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint {
  background: rgba(255, 255, 255, 0.09) !important;
  color: rgba(255, 255, 255, 0.94) !important;
  border: 1px solid rgba(255, 255, 255, 0.14) !important;
  border-radius: 999px !important;
  backdrop-filter: blur(16px) !important;
  -webkit-backdrop-filter: blur(16px) !important;
  transition: background 0.16s ease, border-color 0.16s ease, transform 0.14s ease !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint:hover {
  background: rgba(255, 255, 255, 0.16) !important;
  border-color: rgba(255, 255, 255, 0.24) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint yt-icon,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint yt-formatted-string,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint .text,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-chip-cloud-chip-renderer a.yt-simple-endpoint svg {
  color: rgba(255, 255, 255, 0.94) !important;
  fill: currentColor !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-chip-cloud-chip-renderer[is-selected] a.yt-simple-endpoint {
  background: rgb(var(--ytmg-accent-rgb)) !important;
  color: #ffffff !important;
  border-color: transparent !important;
}

/* Album & Playlist Cards — Rounded macOS Corners & Subtle Hover Lift */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-two-row-item-renderer .image-wrapper,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-two-row-item-renderer ytmusic-thumbnail-renderer,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-two-row-item-renderer img#img {
  border-radius: 12px !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-two-row-item-renderer {
  transition: transform 0.2s cubic-bezier(0.22, 1, 0.36, 1) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-two-row-item-renderer:hover {
  transform: translateY(-3px) !important;
}

/* Song List Rows — Clean Rounded Hover Pills */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-responsive-list-item-renderer {
  border-radius: 10px !important;
  border-bottom-color: rgba(255, 255, 255, 0.04) !important;
  padding-left: 8px !important;
  padding-right: 8px !important;
  transition: background 0.15s ease !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-responsive-list-item-renderer:hover {
  background: rgba(255, 255, 255, 0.07) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-responsive-list-item-renderer ytmusic-thumbnail-renderer,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-responsive-list-item-renderer img#img {
  border-radius: 7px !important;
}

/* Expanded Now-Playing / Watch Page — Seamless Pure Dark */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-page {
  background: #030303 !important;
}

/* Hide redundant YTM Lyrics & Comments tabs so only UP NEXT and RELATED remain */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-page tp-yt-paper-tab[data-ytmg-hidden-tab="true"] {
  display: none !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player#player {
  border-radius: 16px !important;
  overflow: hidden !important;
  box-shadow: 0 24px 64px rgba(0, 0, 0, 0.58), 0 0 42px rgba(var(--ytmg-accent-rgb), 0.16) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-queue-item {
  border-radius: 10px !important;
  border-bottom-color: rgba(255, 255, 255, 0.04) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-queue-item[selected] {
  background: rgba(var(--ytmg-accent-rgb), 0.2) !important;
}

/* =====================================================================
   FLOATING GLASS PILL BOTTOM PLAYER BAR — SPOTIFY DESKTOP 3-COLUMN LAYOUT
   Left: Track artwork & info | Center: Prev/Play/Next + [Cur | Bar | Dur] | Right: Lyrics & Utils
   ===================================================================== */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar {
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
  border: 1px solid var(--ytmg-border-strong) !important;
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
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .middle-controls.ytmusic-player-bar {
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

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .content-info-wrapper.ytmusic-player-bar {
  min-width: 0 !important;
  max-width: 100% !important;
  overflow: hidden !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .title.ytmusic-player-bar,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .byline.ytmusic-player-bar {
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .middle-controls-buttons.ytmusic-player-bar {
  flex-shrink: 0 !important;
  display: flex !important;
  align-items: center !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar img.image {
  width: 46px !important;
  height: 46px !important;
  border-radius: 9px !important;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.45) !important;
  flex-shrink: 0 !important;
}

/* CENTER TOP: Prev / Play-Pause / Next buttons */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .left-controls.ytmusic-player-bar {
  grid-area: controls !important;
  min-width: 0 !important;
  width: 100% !important;
  padding: 0 !important;
  margin: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .left-controls-buttons.ytmusic-player-bar {
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  gap: 8px !important;
}

/* Hide legacy combined "1:37 / 3:14" text — split cleanly to left & right ends of progress bar */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .time-info.ytmusic-player-bar {
  display: none !important;
}

/* Crisp centered circular halo around Play/Pause button (Spotify Desktop proportions) */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .previous-button,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .next-button {
  width: 32px !important;
  height: 32px !important;
  padding: 0 !important;
  display: inline-flex !important;
  align-items: center !important;
  justify-content: center !important;
  --iron-icon-width: 20px !important;
  --iron-icon-height: 20px !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button {
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
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button #button,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button button,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button #icon,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button yt-icon,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button .yt-icon-shape,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button .yt-icon-shape > div,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .previous-button #button,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .previous-button button,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .next-button #button,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .next-button button {
  width: 100% !important;
  height: 100% !important;
  margin: 0 !important;
  padding: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button svg {
  width: 22px !important;
  height: 22px !important;
  margin: auto !important;
  display: block !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #play-pause-button:hover {
  background: rgba(255, 255, 255, 0.16) !important;
  border-color: rgba(255, 255, 255, 0.40) !important;
  transform: scale(1.06) !important;
}

/* RIGHT COLUMN: Lyrics button, Volume, Repeat, Shuffle, Expand */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .right-controls.ytmusic-player-bar {
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
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #progress-bar {
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
#ytmg-progress-bar {
  display: none;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar {
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

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-time {
  font-size: 11px !important;
  font-weight: 500 !important;
  font-variant-numeric: tabular-nums !important;
  color: rgba(255, 255, 255, 0.56) !important;
  min-width: 34px !important;
  line-height: 1 !important;
  flex-shrink: 0 !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-cur {
  text-align: right !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-dur {
  text-align: left !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-hit {
  position: relative !important;
  flex: 1 1 auto !important;
  min-width: 90px !important;
  height: 16px !important;
  display: flex !important;
  align-items: center !important;
  cursor: pointer !important;
  touch-action: none !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-track {
  position: relative !important;
  width: 100% !important;
  height: 4.5px !important;
  border-radius: 999px !important;
  background: rgba(255, 255, 255, 0.22) !important;
  overflow: hidden !important;
  transition: height 0.14s ease, background 0.14s ease !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-hit:hover .ytmg-pb-track,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar.dragging .ytmg-pb-track {
  height: 6px !important;
  background: rgba(255, 255, 255, 0.28) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-buf {
  position: absolute !important;
  top: 0 !important;
  left: 0 !important;
  bottom: 0 !important;
  width: 0%;
  border-radius: 999px !important;
  background: rgba(255, 255, 255, 0.15) !important;
  pointer-events: none !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-fill {
  position: absolute !important;
  top: 0 !important;
  left: 0 !important;
  bottom: 0 !important;
  width: 0%;
  border-radius: 999px !important;
  background: rgb(var(--ytmg-accent-rgb)) !important;
  pointer-events: none !important;
  transition: background-color 0.45s ease !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-knob {
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

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-hit:hover .ytmg-pb-knob,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar.dragging .ytmg-pb-knob {
  opacity: 1 !important;
  transform: translate(-50%, -50%) scale(1) !important;
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-tooltip {
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

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar .ytmg-pb-hit:hover .ytmg-pb-tooltip,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar #ytmg-progress-bar.dragging .ytmg-pb-tooltip {
  opacity: 1 !important;
}

/* Responsive compaction when lyrics sidebar is dragged wide */
@media (max-width: 900px) {
  html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar {
    grid-template-columns: minmax(150px, 1fr) minmax(210px, 1.35fr) auto !important;
    column-gap: 10px !important;
    padding: 6px 12px 8px 12px !important;
  }
  html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .middle-controls-buttons.ytmusic-player-bar {
    display: none !important;
  }
}

@media (max-width: 680px) {
  html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar {
    grid-template-columns: minmax(120px, 0.9fr) minmax(175px, 1.45fr) auto !important;
    column-gap: 8px !important;
  }
  html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .volume-slider.ytmusic-player-bar,
  html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .repeat.ytmusic-player-bar,
  html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] ytmusic-player-bar .shuffle.ytmusic-player-bar {
    display: none !important;
  }
}

html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] #player-bar-background.ytmusic-app-layout {
  display: none !important;
}

/* Give page scroll area breathing room above the floating glass player pill */
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] #contents.ytmusic-browse-response,
html[data-ytmg-theme="apple-glass"][data-ytmg-site="ytm"] #contents.ytmusic-section-list-renderer {
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
          const STYLE_ID = 'ytmg-apple-glass-style';
          const site = location.hostname.startsWith('music.') ? 'ytm' : 'youtube';
          document.documentElement.dataset.ytmgSite = site;

          if (!document.getElementById(STYLE_ID)) {
            const style = document.createElement('style');
            style.id = STYLE_ID;
            style.textContent = `\(escapedCSS)`;
            (document.head || document.documentElement).appendChild(style);
          }

          window.__ytmgSetTheme = function (enabled) {
            document.documentElement.dataset.ytmgTheme = enabled ? 'apple-glass' : 'original';
          };

          window.__ytmgSetFontStyle = function (style) {
            document.documentElement.dataset.ytmgFont = style === 'sfpro' ? 'sfpro' : 'roboto';
          };

          window.__ytmgSetPalette = function (accentRgb, bgTop, bgBottom, artworkUrl) {
            const root = document.documentElement.style;
            root.setProperty('--ytmg-accent-rgb', accentRgb);
            root.setProperty('--ytmg-bg-top', bgTop);
            root.setProperty('--ytmg-bg-bottom', bgBottom);
            if (artworkUrl) {
              const safeUrl = String(artworkUrl).replace(/["'\\\\()\\n\\r]/g, '');
              root.setProperty('--ytmg-artwork-url', 'url("' + safeUrl + '")');
            } else {
              root.setProperty('--ytmg-artwork-url', 'none');
            }
          };

          document.documentElement.dataset.ytmgTheme = 'apple-glass';
        })();
        """
    }
}
