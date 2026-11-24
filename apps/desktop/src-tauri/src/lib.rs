pub mod core;

use crate::core::lrc::LrcParser;
use crate::core::lyrics_service::LyricsService;
use crate::core::models::{
    now_ms, CleanedTrack, LrclibCandidate, LyricsSource, ParsedLyrics, PlaybackSnapshot, SyncCalculator,
    SyncFrame, TrackInfo,
};
use crate::core::normalizer::MetadataNormalizer;
use crate::core::romanizer::{DetectedScript, RomanizerStore};
use crate::core::tap_sync::{TapSyncLine, TapSyncSession};
use crate::core::translation::TranslationService;
use crate::core::updater::{check_github_updates, DesktopUpdateInfo};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::{
    menu::{Menu, MenuItem},
    tray::TrayIconBuilder,
    AppHandle, Emitter, Manager, PhysicalPosition, PhysicalSize, Position, Size, WebviewUrl,
    WebviewWindow, WebviewWindowBuilder, WindowEvent,
};
use tauri_plugin_shell::ShellExt;
use tokio::sync::Mutex;

const SHARED_GLASS_CSS: &str = include_str!("../../../../packages/shared/web/theme-glass.css");
const SHARED_THEME_INSTALLER: &str = include_str!("../../../../packages/shared/web/theme-installer.js");
const SHARED_BRIDGE_JS: &str = include_str!("../../../../packages/shared/web/bridge.js");

fn build_init_script() -> String {
    let css_json = serde_json::to_string(SHARED_GLASS_CSS).unwrap_or_else(|_| "\"\"".to_string());
    format!(
        "window.__YTMG_GLASS_CSS__ = {css_json};\n{SHARED_THEME_INSTALLER}\n{SHARED_BRIDGE_JS}"
    )
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrackSummaryPayload {
    pub track_key: String,
    pub title: String,
    pub artist: String,
    pub album: Option<String>,
    pub duration: f64,
    pub artwork_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TapSyncStatePayload {
    pub track_key: String,
    pub current_index: usize,
    pub total_count: usize,
    pub tapped_count: usize,
    pub is_complete: bool,
    pub lines: Vec<TapSyncLine>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppSnapshot {
    pub version: String,
    pub site_mode: String,
    pub status: String,
    pub status_message: String,
    pub track: Option<TrackSummaryPayload>,
    pub playback: PlaybackSnapshot,
    pub parsed: Option<ParsedLyrics>,
    pub frame: SyncFrame,
    pub romanized_lines: Vec<Option<String>>,
    pub translated_lines: Vec<Option<String>>,
    pub candidates: Vec<LrclibCandidate>,
    pub selected_candidate_id: Option<i64>,
    pub lyrics_source: Option<String>,
    pub is_offline_pinned: bool,
    pub offline_vault_count: usize,
    pub kanji_dict_ready: bool,
    pub kanji_dict_downloading: bool,
    pub accent_rgb: String,
    pub offset_ms: f64,
    pub hud_opacity: f64,
    pub hud_mode: String,
    pub click_through: bool,
    pub pill_enabled: bool,
    pub pill_edge: String,
    pub romanize_enabled: bool,
    pub translate_enabled: bool,
    pub translate_source: String,
    pub translate_target: String,
    pub theme_enabled: bool,
    pub font_style: String,
    pub tap_sync: Option<TapSyncStatePayload>,
    pub update: DesktopUpdateInfo,
}

pub struct SharedState {
    pub version: String,
    pub site_mode: String,
    pub status: String,
    pub status_message: String,
    pub cleaned_track: Option<CleanedTrack>,
    pub playback: PlaybackSnapshot,
    pub parsed: Option<ParsedLyrics>,
    pub frame: SyncFrame,
    pub romanized_lines: Vec<Option<String>>,
    pub translated_lines: Vec<Option<String>>,
    pub candidates: Vec<LrclibCandidate>,
    pub selected_candidate_id: Option<i64>,
    pub lyrics_source: Option<LyricsSource>,
    pub accent_rgb: String,
    pub offset_ms: f64,
    pub hud_opacity: f64,
    pub hud_mode: String,
    pub click_through: bool,
    pub pill_enabled: bool,
    pub pill_edge: String,
    pub romanize_enabled: bool,
    pub translate_enabled: bool,
    pub translate_source: String,
    pub translate_target: String,
    pub theme_enabled: bool,
    pub font_style: String,
    pub kanji_dict_downloading: bool,
    pub tap_sync: Option<TapSyncSession>,
    pub update: DesktopUpdateInfo,
    pub lyrics_service: LyricsService,
    pub translation_service: TranslationService,
    pub romanizer: RomanizerStore,
}

impl SharedState {
    fn new() -> Self {
        let app_dir = dirs::data_local_dir()
            .unwrap_or_else(std::env::temp_dir)
            .join("YTMusicGlass");
        let _ = std::fs::create_dir_all(&app_dir);
        let lyrics_service = LyricsService::new(app_dir.clone());
        let translation_service = TranslationService::new(app_dir.clone());
        let romanizer = RomanizerStore::new(app_dir);

        Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
            site_mode: "ytm".to_string(),
            status: "idle".to_string(),
            status_message: "Play any track on YouTube Music".to_string(),
            cleaned_track: None,
            playback: PlaybackSnapshot::default(),
            parsed: None,
            frame: SyncFrame::default(),
            romanized_lines: Vec::new(),
            translated_lines: Vec::new(),
            candidates: Vec::new(),
            selected_candidate_id: None,
            lyrics_source: None,
            accent_rgb: "244, 63, 108".to_string(),
            offset_ms: 0.0,
            hud_opacity: 0.68,
            hud_mode: "full".to_string(),
            click_through: false,
            pill_enabled: true,
            pill_edge: "top".to_string(),
            romanize_enabled: true,
            translate_enabled: false,
            translate_source: "auto".to_string(),
            translate_target: "id".to_string(),
            theme_enabled: true,
            font_style: "roboto".to_string(),
            kanji_dict_downloading: false,
            tap_sync: None,
            update: DesktopUpdateInfo::default(),
            lyrics_service,
            translation_service,
            romanizer,
        }
    }

    fn snapshot(&self) -> AppSnapshot {
        let track = self.cleaned_track.as_ref().map(|t| TrackSummaryPayload {
            track_key: t.track_key.clone(),
            title: t.title.clone(),
            artist: t.artist.clone(),
            album: t.album.clone(),
            duration: t.raw.duration,
            artwork_url: t.raw.artwork_url.clone(),
        });
        let is_offline_pinned = self
            .cleaned_track
            .as_ref()
            .map(|t| self.lyrics_service.has_offline_lyrics(t))
            .unwrap_or(false);
        let tap_sync = self.tap_sync.as_ref().map(|s| TapSyncStatePayload {
            track_key: s.track_key.clone(),
            current_index: s.current_index,
            total_count: s.total_count(),
            tapped_count: s.tapped_count(),
            is_complete: s.is_complete(),
            lines: s.lines.clone(),
        });

        AppSnapshot {
            version: self.version.clone(),
            site_mode: self.site_mode.clone(),
            status: self.status.clone(),
            status_message: self.status_message.clone(),
            track,
            playback: self.playback.clone(),
            parsed: self.parsed.clone(),
            frame: self.frame.clone(),
            romanized_lines: self.romanized_lines.clone(),
            translated_lines: self.translated_lines.clone(),
            candidates: self.candidates.clone(),
            selected_candidate_id: self.selected_candidate_id,
            lyrics_source: self.lyrics_source.map(|s| s.as_str().to_string()),
            is_offline_pinned,
            offline_vault_count: self.lyrics_service.offline_count(),
            kanji_dict_ready: self.romanizer.is_kanji_dict_ready(),
            kanji_dict_downloading: self.kanji_dict_downloading,
            accent_rgb: self.accent_rgb.clone(),
            offset_ms: self.offset_ms,
            hud_opacity: self.hud_opacity,
            hud_mode: self.hud_mode.clone(),
            click_through: self.click_through,
            pill_enabled: self.pill_enabled,
            pill_edge: self.pill_edge.clone(),
            romanize_enabled: self.romanize_enabled,
            translate_enabled: self.translate_enabled,
            translate_source: self.translate_source.clone(),
            translate_target: self.translate_target.clone(),
            theme_enabled: self.theme_enabled,
            font_style: self.font_style.clone(),
            tap_sync,
            update: self.update.clone(),
        }
    }

    fn recompute_romanization(&mut self) {
        let Some(ref parsed) = self.parsed else {
            self.romanized_lines.clear();
            return;
        };
        let hint = parsed
            .lines
            .iter()
            .map(|l| RomanizerStore::detect_script(&l.text))
            .find(|&s| s == DetectedScript::Japanese || s == DetectedScript::Korean);
        self.romanized_lines = parsed
            .lines
            .iter()
            .map(|l| self.romanizer.romanize_line(&l.text, hint))
            .collect();
    }
}

type ManagedState = Arc<Mutex<SharedState>>;

fn emit_snapshot(app: &AppHandle, snap: &AppSnapshot) {
    let _ = app.emit("ytmg://state", snap);
}

fn ensure_companion_window(
    app: &AppHandle,
    label: &str,
    surface: &str,
    title: &str,
    w: f64,
    h: f64,
    transparent: bool,
    always_on_top: bool,
    decorations: bool,
    skip_taskbar: bool,
) -> Option<WebviewWindow> {
    if let Some(win) = app.get_webview_window(label) {
        return Some(win);
    }
    let url = WebviewUrl::App(format!("index.html?surface={surface}").into());
    WebviewWindowBuilder::new(app, label, url)
        .title(title)
        .inner_size(w, h)
        .transparent(transparent)
        .decorations(decorations)
        .always_on_top(always_on_top)
        .skip_taskbar(skip_taskbar)
        .visible(false)
        .build()
        .ok()
}

fn position_pill(win: &WebviewWindow, edge: &str) {
    if let Ok(Some(monitor)) = win.current_monitor() {
        let m_size = monitor.size();
        let m_pos = monitor.position();
        let pill_w = 440i32;
        let pill_h = 38i32;
        let x = m_pos.x + (m_size.width as i32 - pill_w) / 2;
        let y = if edge == "bottom" {
            m_pos.y + (m_size.height as i32) - pill_h - 54
        } else {
            m_pos.y + 10
        };
        let _ = win.set_position(Position::Physical(PhysicalPosition::new(x, y)));
        let _ = win.set_size(Size::Physical(PhysicalSize::new(pill_w as u32, pill_h as u32)));
    }
}

fn dock_sidebar_to_main(app: &AppHandle) {
    let Some(main_win) = app.get_webview_window("main") else {
        return;
    };
    let Some(side_win) = app.get_webview_window("sidebar") else {
        return;
    };
    if !side_win.is_visible().unwrap_or(false) {
        return;
    }
    if let (Ok(pos), Ok(size)) = (main_win.outer_position(), main_win.outer_size()) {
        let side_w = 340u32;
        let _ = side_win.set_position(Position::Physical(PhysicalPosition::new(
            pos.x + size.width as i32 + 4,
            pos.y,
        )));
        let _ = side_win.set_size(Size::Physical(PhysicalSize::new(side_w, size.height)));
    }
}

fn toggle_window_visibility(app: &AppHandle, label: &str) {
    if let Some(win) = app.get_webview_window(label) {
        if win.is_visible().unwrap_or(false) {
            let _ = win.hide();
        } else {
            let _ = win.show();
            let _ = win.set_focus();
            if label == "sidebar" {
                dock_sidebar_to_main(app);
            }
        }
    }
}

#[tauri::command]
async fn ytmg_get_state(state: tauri::State<'_, ManagedState>) -> Result<AppSnapshot, String> {
    let guard = state.lock().await;
    Ok(guard.snapshot())
}

#[tauri::command]
async fn ytmg_bridge_event(
    app: AppHandle,
    state: tauri::State<'_, ManagedState>,
    payload: String,
) -> Result<(), String> {
    let val: serde_json::Value = serde_json::from_str(&payload).map_err(|e| e.to_string())?;
    if let Some(action) = val.get("action").and_then(|v| v.as_str()) {
        match action {
            "toggleSidebar" => {
                toggle_window_visibility(&app, "sidebar");
            }
            "offlineTracksDiscovered" => {
                if let Some(arr) = val.get("tracks").and_then(|v| v.as_array()) {
                    let tracks: Vec<TrackInfo> = arr
                        .iter()
                        .filter_map(|item| serde_json::from_value(item.clone()).ok())
                        .collect();
                    let state_arc = Arc::clone(state.inner());
                    let app_clone = app.clone();
                    tokio::spawn(async move {
                        for raw_t in tracks {
                            let cleaned = MetadataNormalizer::normalize(raw_t);
                            let already = {
                                let g = state_arc.lock().await;
                                g.lyrics_service.has_offline_lyrics(&cleaned)
                            };
                            if !already {
                                let mut tmp_svc = {
                                    let g = state_arc.lock().await;
                                    LyricsService::new(
                                        dirs::data_local_dir()
                                            .unwrap_or_else(std::env::temp_dir)
                                            .join("YTMusicGlass"),
                                    )
                                };
                                let fetched = tmp_svc.fetch_from_lrclib(&cleaned, true).await;
                                if let Some(res) = fetched {
                                    let mut g = state_arc.lock().await;
                                    if let Some(cand) = res.candidates.first() {
                                        g.lyrics_service.pin_candidate_offline(cand, res.source, &cleaned, res.candidates.clone());
                                    }
                                    let snap = g.snapshot();
                                    emit_snapshot(&app_clone, &snap);
                                }
                            }
                        }
                    });
                }
            }
            _ => {}
        }
        return Ok(());
    }

    let playback: PlaybackSnapshot = serde_json::from_value(val["playback"].clone()).unwrap_or_default();
    let track_opt: Option<TrackInfo> = serde_json::from_value(val["track"].clone()).ok();
    let is_offline_context = val.get("isOfflineContext").and_then(|v| v.as_bool()).unwrap_or(false);
    let site_mode = val.get("platform").and_then(|v| v.as_str()).unwrap_or("ytm").to_string();

    let mut need_fetch: Option<CleanedTrack> = None;
    let mut need_translate: Option<(String, Vec<String>, String, String, bool)> = None;
    let mut need_kanji_dict = false;

    let snap = {
        let mut g = state.lock().await;
        g.site_mode = site_mode;
        g.playback = playback.clone();

        if let Some(raw_track) = track_opt {
            let cleaned = MetadataNormalizer::normalize(raw_track);
            let changed = g
                .cleaned_track
                .as_ref()
                .map(|prev| prev.track_key != cleaned.track_key)
                .unwrap_or(true);

            if changed {
                g.cleaned_track = Some(cleaned.clone());
                g.translated_lines.clear();
                if let Some(cached) = g.lyrics_service.resolve_from_cache(&cleaned) {
                    g.lyrics_source = Some(cached.source);
                    g.parsed = Some(cached.parsed);
                    g.selected_candidate_id = cached.candidate_id;
                    g.candidates = cached.candidates;
                    g.status = if cached.source.is_synced() {
                        "synced".to_string()
                    } else {
                        "plainFallback".to_string()
                    };
                    g.status_message = String::new();
                    g.recompute_romanization();
                    if g.translate_enabled {
                        if let Some(ref p) = g.parsed {
                            let lines: Vec<String> = p.lines.iter().map(|l| l.text.clone()).collect();
                            need_translate = Some((
                                cleaned.track_key.clone(),
                                lines,
                                g.translate_source.clone(),
                                g.translate_target.clone(),
                                is_offline_context,
                            ));
                        }
                    }
                    if !g.romanizer.is_kanji_dict_ready() && !g.kanji_dict_downloading {
                        if let Some(ref p) = g.parsed {
                            if p.lines.iter().any(|l| RomanizerStore::detect_script(&l.text) == DetectedScript::Japanese) {
                                g.kanji_dict_downloading = true;
                                need_kanji_dict = true;
                            }
                        }
                    }
                } else {
                    g.parsed = None;
                    g.romanized_lines.clear();
                    g.status = "loading".to_string();
                    g.status_message = "Searching synced lyrics...".to_string();
                    need_fetch = Some(cleaned);
                }
            }
        }

        if let Some(ref parsed) = g.parsed {
            let ext_t = SyncCalculator::extrapolate_time(&g.playback, now_ms());
            g.frame = SyncCalculator::compute_frame(parsed, ext_t, g.offset_ms);
        } else {
            g.frame = SyncFrame::default();
        }
        g.snapshot()
    };

    emit_snapshot(&app, &snap);

    if need_kanji_dict {
        let state_arc = Arc::clone(state.inner());
        let app_clone = app.clone();
        tokio::spawn(async move {
            if let Ok(dict) = RomanizerStore::download_kanji_dictionary().await {
                let mut g = state_arc.lock().await;
                let _ = g.romanizer.install_kanji_dictionary(dict);
                g.kanji_dict_downloading = false;
                g.recompute_romanization();
                let s = g.snapshot();
                emit_snapshot(&app_clone, &s);
            } else {
                let mut g = state_arc.lock().await;
                g.kanji_dict_downloading = false;
            }
        });
    }

    if let Some(cleaned) = need_fetch {
        let state_arc = Arc::clone(state.inner());
        let app_clone = app.clone();
        tokio::spawn(async move {
            let app_dir = dirs::data_local_dir()
                .unwrap_or_else(std::env::temp_dir)
                .join("YTMusicGlass");
            let mut svc = LyricsService::new(app_dir);
            let res = svc.fetch_from_lrclib(&cleaned, is_offline_context).await;
            let mut trans_job = None;
            let snap = {
                let mut g = state_arc.lock().await;
                if g.cleaned_track.as_ref().map(|t| t.track_key == cleaned.track_key).unwrap_or(false) {
                    if let Some(resolved) = res {
                        g.lyrics_source = Some(resolved.source);
                        g.parsed = Some(resolved.parsed);
                        g.selected_candidate_id = resolved.candidate_id;
                        g.candidates = resolved.candidates;
                        g.status = if resolved.source.is_synced() {
                            "synced".to_string()
                        } else {
                            "plainFallback".to_string()
                        };
                        g.status_message = String::new();
                        g.recompute_romanization();
                        if g.translate_enabled {
                            if let Some(ref p) = g.parsed {
                                let lines: Vec<String> = p.lines.iter().map(|l| l.text.clone()).collect();
                                trans_job = Some((
                                    cleaned.track_key.clone(),
                                    lines,
                                    g.translate_source.clone(),
                                    g.translate_target.clone(),
                                    is_offline_context,
                                ));
                            }
                        }
                    } else {
                        g.status = "notFound".to_string();
                        g.status_message = "No lyrics found on LRCLIB".to_string();
                    }
                }
                g.snapshot()
            };
            emit_snapshot(&app_clone, &snap);

            if let Some((tk, lines, src, tgt, pin)) = trans_job {
                let mut tsvc = TranslationService::new(
                    dirs::data_local_dir()
                        .unwrap_or_else(std::env::temp_dir)
                        .join("YTMusicGlass"),
                );
                let translated = tsvc.translate_lines(&tk, &lines, &src, &tgt, pin).await;
                let mut g = state_arc.lock().await;
                if g.cleaned_track.as_ref().map(|t| t.track_key == tk).unwrap_or(false) {
                    g.translated_lines = translated;
                    let s = g.snapshot();
                    emit_snapshot(&app_clone, &s);
                }
            }
        });
    } else if let Some((tk, lines, src, tgt, pin)) = need_translate {
        let state_arc = Arc::clone(state.inner());
        let app_clone = app.clone();
        tokio::spawn(async move {
            let mut tsvc = TranslationService::new(
                dirs::data_local_dir()
                    .unwrap_or_else(std::env::temp_dir)
                    .join("YTMusicGlass"),
            );
            let translated = tsvc.translate_lines(&tk, &lines, &src, &tgt, pin).await;
            let mut g = state_arc.lock().await;
            if g.cleaned_track.as_ref().map(|t| t.track_key == tk).unwrap_or(false) {
                g.translated_lines = translated;
                let s = g.snapshot();
                emit_snapshot(&app_clone, &s);
            }
        });
    }

    Ok(())
}

#[tauri::command]
async fn ytmg_command(
    app: AppHandle,
    state: tauri::State<'_, ManagedState>,
    command: String,
    payload: Option<serde_json::Value>,
) -> Result<(), String> {
    let data = payload.unwrap_or_else(|| serde_json::json!({}));
    match command.as_str() {
        "toggle_play" | "next" | "prev" => {
            if let Some(main_win) = app.get_webview_window("main") {
                let cmd_name = match command.as_str() {
                    "toggle_play" => "togglePlay",
                    "next" => "next",
                    _ => "prev",
                };
                let _ = main_win.eval(&format!("window.__ytmgCmd && window.__ytmgCmd('{cmd_name}');"));
            }
            return Ok(());
        }
        "seek" => {
            if let Some(time) = data.get("time").and_then(|v| v.as_f64()) {
                if let Some(main_win) = app.get_webview_window("main") {
                    let _ = main_win.eval(&format!("window.__ytmgCmd && window.__ytmgCmd('seek', {time});"));
                }
            }
            return Ok(());
        }
        "toggle_hud" => {
            toggle_window_visibility(&app, "hud");
            return Ok(());
        }
        "toggle_mini" => {
            toggle_window_visibility(&app, "mini-player");
            return Ok(());
        }
        "open_settings" => {
            if let Some(w) = app.get_webview_window("settings") {
                let _ = w.show();
                let _ = w.set_focus();
            }
            return Ok(());
        }
        "open_about" => {
            if let Some(w) = app.get_webview_window("about") {
                let _ = w.show();
                let _ = w.set_focus();
            }
            return Ok(());
        }
        "open_tapsync" => {
            {
                let mut g = state.lock().await;
                if let (Some(track), Some(parsed)) = (g.cleaned_track.clone(), g.parsed.clone()) {
                    g.tap_sync = Some(TapSyncSession::new(track.track_key, &parsed.plain_lines));
                }
                let s = g.snapshot();
                emit_snapshot(&app, &s);
            }
            if let Some(w) = app.get_webview_window("tapsync") {
                let _ = w.show();
                let _ = w.set_focus();
            }
            return Ok(());
        }
        "check_updates" => {
            let state_arc = Arc::clone(state.inner());
            let app_clone = app.clone();
            tokio::spawn(async move {
                let cur = {
                    let g = state_arc.lock().await;
                    g.version.clone()
                };
                let info = check_github_updates(&cur).await;
                let mut g = state_arc.lock().await;
                g.update = info;
                let s = g.snapshot();
                emit_snapshot(&app_clone, &s);
            });
            return Ok(());
        }
        "download_update" => {
            let url_opt = {
                let g = state.lock().await;
                g.update.download_url.clone().or(g.update.release_url.clone())
            };
            if let Some(url) = url_opt {
                let _ = app.shell().open(url, None);
            }
            return Ok(());
        }
        "download_kanji_dict" => {
            let state_arc = Arc::clone(state.inner());
            let app_clone = app.clone();
            {
                let mut g = state.lock().await;
                g.kanji_dict_downloading = true;
                let s = g.snapshot();
                emit_snapshot(&app_clone, &s);
            }
            tokio::spawn(async move {
                if let Ok(dict) = RomanizerStore::download_kanji_dictionary().await {
                    let mut g = state_arc.lock().await;
                    let _ = g.romanizer.install_kanji_dictionary(dict);
                    g.kanji_dict_downloading = false;
                    g.recompute_romanization();
                    let s = g.snapshot();
                    emit_snapshot(&app_clone, &s);
                } else {
                    let mut g = state_arc.lock().await;
                    g.kanji_dict_downloading = false;
                    let s = g.snapshot();
                    emit_snapshot(&app_clone, &s);
                }
            });
            return Ok(());
        }
        _ => {}
    }

    let snap = {
        let mut g = state.lock().await;
        match command.as_str() {
            "toggle_hud_mode" => {
                g.hud_mode = if g.hud_mode == "full" {
                    "compact".to_string()
                } else {
                    "full".to_string()
                };
            }
            "toggle_click_through" => {
                g.click_through = !g.click_through;
                if let Some(hud) = app.get_webview_window("hud") {
                    let _ = hud.set_ignore_cursor_events(g.click_through);
                }
            }
            "toggle_pill" => {
                g.pill_enabled = !g.pill_enabled;
                if let Some(pill) = app.get_webview_window("lyric-pill") {
                    if g.pill_enabled {
                        position_pill(&pill, &g.pill_edge);
                        let _ = pill.show();
                    } else {
                        let _ = pill.hide();
                    }
                }
            }
            "toggle_pill_edge" => {
                g.pill_edge = if g.pill_edge == "top" {
                    "bottom".to_string()
                } else {
                    "top".to_string()
                };
                if let Some(pill) = app.get_webview_window("lyric-pill") {
                    position_pill(&pill, &g.pill_edge);
                }
            }
            "toggle_romanize" => {
                g.romanize_enabled = !g.romanize_enabled;
            }
            "toggle_translate" => {
                g.translate_enabled = !g.translate_enabled;
            }
            "set_translate_target" => {
                if let Some(t) = data.get("target").and_then(|v| v.as_str()) {
                    g.translate_target = t.to_string();
                }
            }
            "set_hud_opacity" => {
                if let Some(op) = data.get("opacity").and_then(|v| v.as_f64()) {
                    g.hud_opacity = op.clamp(0.0, 0.85);
                }
            }
            "toggle_theme" => {
                g.theme_enabled = !g.theme_enabled;
                if let Some(main_win) = app.get_webview_window("main") {
                    let _ = main_win.eval(&format!("window.__ytmgSetTheme && window.__ytmgSetTheme({});", g.theme_enabled));
                }
            }
            "switch_site" => {
                g.site_mode = if g.site_mode == "ytm" {
                    "youtube".to_string()
                } else {
                    "ytm".to_string()
                };
                if let Some(main_win) = app.get_webview_window("main") {
                    let url = if g.site_mode == "ytm" {
                        "https://music.youtube.com"
                    } else {
                        "https://www.youtube.com"
                    };
                    let _ = main_win.eval(&format!("window.location.href = '{url}';"));
                }
            }
            "offset_minus" => {
                g.offset_ms -= 200.0;
            }
            "offset_plus" => {
                g.offset_ms += 200.0;
            }
            "pin_offline" => {
                if let (Some(track), Some(cand)) = (g.cleaned_track.clone(), g.candidates.first().cloned()) {
                    let src = g.lyrics_source.unwrap_or(LyricsSource::LrclibSynced);
                    let all_c = g.candidates.clone();
                    g.lyrics_service.pin_candidate_offline(&cand, src, &track, all_c);
                }
            }
            "tap_next" => {
                let ext = SyncCalculator::extrapolate_time(&g.playback, now_ms());
                if let Some(ref mut tap) = g.tap_sync {
                    tap.tap_next(ext);
                }
            }
            "tap_undo" => {
                if let Some(ref mut tap) = g.tap_sync {
                    tap.undo_last_tap();
                }
            }
            "tap_save" => {
                if let (Some(track), Some(tap)) = (g.cleaned_track.clone(), g.tap_sync.clone()) {
                    if let Some(lrc_text) = tap.export_lrc() {
                        let plain = tap.lines.iter().map(|l| l.text.clone()).collect::<Vec<_>>().join("\n");
                        let resolved = g.lyrics_service.save_user_synced_lyrics(&lrc_text, &plain, &track);
                        g.lyrics_source = Some(resolved.source);
                        g.parsed = Some(resolved.parsed);
                        g.status = "synced".to_string();
                        g.recompute_romanization();
                    }
                }
            }
            _ => {}
        }
        g.snapshot()
    };

    emit_snapshot(&app, &snap);
    Ok(())
}

pub fn run() {
    let shared_state = Arc::new(Mutex::new(SharedState::new()));

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(Arc::clone(&shared_state))
        .invoke_handler(tauri::generate_handler![
            ytmg_get_state,
            ytmg_bridge_event,
            ytmg_command
        ])
        .setup(move |app| {
            let handle = app.handle().clone();
            let init_script = build_init_script();

            let main_win = WebviewWindowBuilder::new(
                &handle,
                "main",
                WebviewUrl::External("https://music.youtube.com".parse().unwrap()),
            )
            .title("YT Music Glass")
            .inner_size(1280.0, 820.0)
            .min_inner_size(760.0, 520.0)
            .initialization_script(&init_script)
            .build()?;

            let app_for_events = handle.clone();
            main_win.on_window_event(move |event| match event {
                WindowEvent::Moved(_) | WindowEvent::Resized(_) => {
                    dock_sidebar_to_main(&app_for_events);
                }
                _ => {}
            });

            let _ = ensure_companion_window(&handle, "hud", "hud", "Floating Lyrics HUD", 640.0, 175.0, true, true, false, true);
            let _ = ensure_companion_window(&handle, "mini-player", "mini", "Mini Player", 356.0, 136.0, true, true, false, true);
            if let Some(pill) = ensure_companion_window(&handle, "lyric-pill", "pill", "Live Lyric Pill", 440.0, 38.0, true, true, false, true) {
                position_pill(&pill, "top");
                let _ = pill.show();
            }
            let _ = ensure_companion_window(&handle, "sidebar", "sidebar", "Lyrics Sidebar", 340.0, 820.0, true, false, false, true);
            let _ = ensure_companion_window(&handle, "command-palette", "command-palette", "Quick Command Palette", 560.0, 420.0, true, true, false, true);
            let _ = ensure_companion_window(&handle, "settings", "settings", "Settings", 520.0, 480.0, false, false, true, false);
            let _ = ensure_companion_window(&handle, "about", "about", "About YT Music Glass", 440.0, 340.0, false, false, true, false);
            let _ = ensure_companion_window(&handle, "tapsync", "tapsync", "Tap-to-Sync", 520.0, 560.0, false, false, true, false);

            let tray_menu = Menu::with_items(
                &handle,
                &[
                    &MenuItem::with_id(&handle, "play_pause", "Play / Pause", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "next", "Next Track", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "prev", "Previous Track", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "sidebar", "Toggle Lyrics Sidebar", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "hud", "Toggle Floating HUD", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "mini", "Toggle Mini Player", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "pill", "Toggle Lyric Pill", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "palette", "Command Palette", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "settings", "Settings", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "about", "About & Updates", true, None::<&str>)?,
                    &MenuItem::with_id(&handle, "quit", "Quit", true, None::<&str>)?,
                ],
            )?;

            let mut tray_builder = TrayIconBuilder::new()
                .menu(&tray_menu)
                .tooltip("YT Music Glass")
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "play_pause" => {
                        if let Some(w) = app.get_webview_window("main") {
                            let _ = w.eval("window.__ytmgCmd && window.__ytmgCmd('togglePlay');");
                        }
                    }
                    "next" => {
                        if let Some(w) = app.get_webview_window("main") {
                            let _ = w.eval("window.__ytmgCmd && window.__ytmgCmd('next');");
                        }
                    }
                    "prev" => {
                        if let Some(w) = app.get_webview_window("main") {
                            let _ = w.eval("window.__ytmgCmd && window.__ytmgCmd('prev');");
                        }
                    }
                    "sidebar" => toggle_window_visibility(app, "sidebar"),
                    "hud" => toggle_window_visibility(app, "hud"),
                    "mini" => toggle_window_visibility(app, "mini-player"),
                    "pill" => toggle_window_visibility(app, "lyric-pill"),
                    "palette" => toggle_window_visibility(app, "command-palette"),
                    "settings" => toggle_window_visibility(app, "settings"),
                    "about" => toggle_window_visibility(app, "about"),
                    "quit" => app.exit(0),
                    _ => {}
                });
            if let Some(icon) = app.default_window_icon() {
                tray_builder = tray_builder.icon(icon.clone());
            }
            let _ = tray_builder.build(app)?;

            let ticker_state = Arc::clone(&shared_state);
            let ticker_app = handle.clone();
            tauri::async_runtime::spawn(async move {
                let mut interval = tokio::time::interval(std::time::Duration::from_millis(66));
                loop {
                    interval.tick().await;
                    let maybe_snap = {
                        let mut g = ticker_state.lock().await;
                        if g.playback.paused || g.parsed.is_none() {
                            None
                        } else {
                            let ext = SyncCalculator::extrapolate_time(&g.playback, now_ms());
                            let parsed = g.parsed.clone().unwrap();
                            let next_frame = SyncCalculator::compute_frame(&parsed, ext, g.offset_ms);
                            if next_frame != g.frame {
                                g.frame = next_frame;
                                Some(g.snapshot())
                            } else {
                                None
                            }
                        }
                    };
                    if let Some(snap) = maybe_snap {
                        emit_snapshot(&ticker_app, &snap);
                    }
                }
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running YT Music Glass desktop");
}
