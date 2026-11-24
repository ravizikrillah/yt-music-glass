use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct LyricWord {
    pub start_time: f64,
    pub end_time: f64,
    pub text: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct LyricLine {
    pub start_time: f64,
    pub end_time: f64,
    pub text: String,
    pub words: Option<Vec<LyricWord>>,
    pub is_instrumental: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ParsedLyrics {
    pub mode: String, // "synced" | "plain"
    pub has_word_sync: bool,
    pub lines: Vec<LyricLine>,
    pub plain_lines: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TrackInfo {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: Option<String>,
    pub duration: f64,
    pub artwork_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CleanedTrack {
    pub track_key: String,
    pub raw: TrackInfo,
    pub title: String,
    pub artist: String,
    pub album: Option<String>,
    pub duration: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct PlaybackSnapshot {
    pub current_time: f64,
    pub duration: f64,
    pub paused: bool,
    pub playback_rate: f64,
    pub is_ad_playing: bool,
    pub captured_at_ms: f64,
}

impl Default for PlaybackSnapshot {
    fn default() -> Self {
        Self {
            current_time: 0.0,
            duration: 0.0,
            paused: true,
            playback_rate: 1.0,
            is_ad_playing: false,
            captured_at_ms: now_ms(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct LrclibCandidate {
    pub id: i64,
    pub name: Option<String>,
    #[serde(default)]
    pub track_name: String,
    #[serde(default)]
    pub artist_name: String,
    pub album_name: Option<String>,
    #[serde(default)]
    pub duration: f64,
    #[serde(default)]
    pub instrumental: bool,
    pub has_word_sync: Option<bool>,
    pub plain_lyrics: Option<String>,
    pub synced_lyrics: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum LyricsSource {
    #[serde(rename = "lrclib_synced")]
    LrclibSynced,
    #[serde(rename = "lrclib_plain")]
    LrclibPlain,
    #[serde(rename = "ytm_native")]
    YtmNative,
    #[serde(rename = "user_synced")]
    UserSynced,
}

impl LyricsSource {
    pub fn is_synced(self) -> bool {
        matches!(self, Self::LrclibSynced | Self::UserSynced)
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::LrclibSynced => "lrclib_synced",
            Self::LrclibPlain => "lrclib_plain",
            Self::YtmNative => "ytm_native",
            Self::UserSynced => "user_synced",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SyncFrame {
    pub effective_time: f64,
    pub active_line_index: i64,
    pub next_vocal_line_index: i64,
    pub line_progress: f64,
    pub active_word_index: i64,
    pub word_progress: f64,
    pub instrumental_active: bool,
    pub instrumental_progress: f64,
}

impl Default for SyncFrame {
    fn default() -> Self {
        Self {
            effective_time: 0.0,
            active_line_index: -1,
            next_vocal_line_index: -1,
            line_progress: 0.0,
            active_word_index: -1,
            word_progress: 0.0,
            instrumental_active: false,
            instrumental_progress: 0.0,
        }
    }
}

pub fn now_ms() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs_f64() * 1000.0)
        .unwrap_or(0.0)
}

pub fn clamp(v: f64, lo: f64, hi: f64) -> f64 {
    v.max(lo).min(hi)
}

pub struct SyncCalculator;

impl SyncCalculator {
    const INTRO_GAP_MIN_SECONDS: f64 = 4.0;
    const BREAK_MIN_SECONDS: f64 = 2.8;

    pub fn compute_seek_target(line_start_time: f64, offset_ms: f64, duration: f64) -> f64 {
        let raw = line_start_time - offset_ms / 1000.0;
        let max_time = if duration > 0.0 { duration } else { f64::MAX };
        clamp(raw, 0.0, max_time)
    }

    pub fn extrapolate_time(playback: &PlaybackSnapshot, current_now_ms: f64) -> f64 {
        if playback.paused {
            return playback.current_time.max(0.0);
        }
        let elapsed_sec = ((current_now_ms - playback.captured_at_ms) / 1000.0).max(0.0);
        let rate = if playback.playback_rate > 0.0 {
            playback.playback_rate
        } else {
            1.0
        };
        let raw = playback.current_time + elapsed_sec * rate;
        if playback.duration > 0.0 {
            clamp(raw, 0.0, playback.duration)
        } else {
            raw.max(0.0)
        }
    }

    fn find_next_vocal_index(lines: &[LyricLine], start: usize) -> i64 {
        for (idx, line) in lines.iter().enumerate().skip(start) {
            if !line.is_instrumental && !line.text.is_empty() {
                return idx as i64;
            }
        }
        -1
    }

    pub fn compute_frame(parsed: &ParsedLyrics, current_time: f64, offset_ms: f64) -> SyncFrame {
        let effective_time = current_time + offset_ms / 1000.0;
        if parsed.mode != "synced" || parsed.lines.is_empty() {
            return SyncFrame::default();
        }

        let lines = &parsed.lines;
        let first_vocal_idx = Self::find_next_vocal_index(lines, 0);

        if effective_time < lines[0].start_time {
            let intro_duration = if first_vocal_idx >= 0 {
                lines[first_vocal_idx as usize].start_time
            } else {
                lines[0].start_time
            };
            let show_dots = intro_duration >= Self::INTRO_GAP_MIN_SECONDS;
            return SyncFrame {
                effective_time,
                active_line_index: -1,
                next_vocal_line_index: first_vocal_idx,
                line_progress: 0.0,
                active_word_index: -1,
                word_progress: 0.0,
                instrumental_active: show_dots,
                instrumental_progress: if show_dots {
                    clamp(effective_time / intro_duration, 0.0, 1.0)
                } else {
                    0.0
                },
            };
        }

        let mut lo = 0isize;
        let mut hi = (lines.len() as isize) - 1;
        let mut idx = 0usize;
        while lo <= hi {
            let mid = ((lo + hi) >> 1) as usize;
            if lines[mid].start_time <= effective_time {
                idx = mid;
                lo = (mid as isize) + 1;
            } else {
                hi = (mid as isize) - 1;
            }
        }

        let active_line = &lines[idx];
        let next_vocal_idx = Self::find_next_vocal_index(lines, idx + 1);

        if active_line.is_instrumental {
            let span = (active_line.end_time - active_line.start_time).max(0.1);
            let show_dots = span >= Self::BREAK_MIN_SECONDS && next_vocal_idx >= 0;
            return SyncFrame {
                effective_time,
                active_line_index: -1,
                next_vocal_line_index: next_vocal_idx,
                line_progress: 0.0,
                active_word_index: -1,
                word_progress: 0.0,
                instrumental_active: show_dots,
                instrumental_progress: if show_dots {
                    clamp((effective_time - active_line.start_time) / span, 0.0, 1.0)
                } else {
                    0.0
                },
            };
        }

        let line_span = (active_line.end_time - active_line.start_time).max(0.2);
        let line_progress = clamp((effective_time - active_line.start_time) / line_span, 0.0, 1.0);

        let mut active_word_idx = -1i64;
        let mut word_prog = 0.0;
        if let Some(words) = &active_line.words {
            for (w_idx, word) in words.iter().enumerate() {
                if effective_time >= word.start_time {
                    active_word_idx = w_idx as i64;
                    let w_span = (word.end_time - word.start_time).max(0.08);
                    word_prog = clamp((effective_time - word.start_time) / w_span, 0.0, 1.0);
                } else {
                    break;
                }
            }
        }

        SyncFrame {
            effective_time,
            active_line_index: idx as i64,
            next_vocal_line_index: next_vocal_idx,
            line_progress,
            active_word_index: active_word_idx,
            word_progress: word_prog,
            instrumental_active: false,
            instrumental_progress: 0.0,
        }
    }
}
