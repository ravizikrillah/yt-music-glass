use crate::core::lrc::LrcParser;
use crate::core::models::{now_ms, CleanedTrack, LrclibCandidate, LyricsSource, ParsedLyrics};
use crate::core::normalizer::MetadataNormalizer;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CachedLyricsRecord {
    pub track_key: String,
    pub video_id: Option<String>,
    pub meta_slug: Option<String>,
    pub source: LyricsSource,
    pub candidate_id: Option<i64>,
    pub plain_lyrics: Option<String>,
    pub synced_lyrics: Option<String>,
    pub candidates: Vec<LrclibCandidate>,
    pub last_accessed_at: f64,
    pub pinned_offline: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct LyricsStoreDisk {
    pub overrides: HashMap<String, i64>,
    pub cache: HashMap<String, CachedLyricsRecord>,
}

pub struct ResolvedLyrics {
    pub source: LyricsSource,
    pub parsed: ParsedLyrics,
    pub candidate_id: Option<i64>,
    pub candidates: Vec<LrclibCandidate>,
}

pub struct LyricsService {
    store_path: PathBuf,
    disk: LyricsStoreDisk,
    client: reqwest::Client,
}

impl LyricsService {
    pub fn new(app_dir: PathBuf) -> Self {
        let _ = fs::create_dir_all(&app_dir);
        let store_path = app_dir.join("lyrics-store.json");
        let disk = fs::read_to_string(&store_path)
            .ok()
            .and_then(|s| serde_json::from_str::<LyricsStoreDisk>(&s).ok())
            .unwrap_or_default();
        let client = reqwest::Client::builder()
            .user_agent("YT Music Glass Desktop v1.2.0")
            .timeout(std::time::Duration::from_secs(10))
            .build()
            .unwrap_or_default();
        Self {
            store_path,
            disk,
            client,
        }
    }

    fn persist(&self) {
        if let Ok(json) = serde_json::to_string_pretty(&self.disk) {
            let _ = fs::write(&self.store_path, json);
        }
    }

    fn meta_slug(track: &CleanedTrack) -> String {
        format!(
            "{}::{}",
            MetadataNormalizer::slugify(&track.artist),
            MetadataNormalizer::slugify(&track.title)
        )
    }

    pub fn offline_count(&self) -> usize {
        self.disk.cache.values().filter(|r| r.pinned_offline).count()
    }

    pub fn has_offline_lyrics(&self, track: &CleanedTrack) -> bool {
        self.find_cached_record(track).map(|r| r.pinned_offline).unwrap_or(false)
    }

    pub fn find_cached_record(&self, track: &CleanedTrack) -> Option<&CachedLyricsRecord> {
        if let Some(exact) = self.disk.cache.get(&track.track_key) {
            return Some(exact);
        }
        let vid = track.raw.id.trim();
        if !vid.is_empty() {
            if let Some(hit) = self
                .disk
                .cache
                .values()
                .find(|r| r.video_id.as_deref() == Some(vid) && r.pinned_offline)
            {
                return Some(hit);
            }
        }
        let slug = Self::meta_slug(track);
        self.disk
            .cache
            .values()
            .find(|r| r.meta_slug.as_deref() == Some(slug.as_str()) && r.pinned_offline)
    }

    pub fn clear_temp_cache(&mut self) {
        self.disk.cache.retain(|_, v| v.pinned_offline);
        self.persist();
    }

    pub fn resolve_from_cache(&mut self, track: &CleanedTrack) -> Option<ResolvedLyrics> {
        let record = self.find_cached_record(track)?.clone();
        let parsed = if let Some(ref synced) = record.synced_lyrics {
            LrcParser::parse_lrc(synced, track.raw.duration)
        } else if let Some(ref plain) = record.plain_lyrics {
            LrcParser::parse_plain(plain)
        } else {
            return None;
        };
        Some(ResolvedLyrics {
            source: record.source,
            parsed,
            candidate_id: record.candidate_id,
            candidates: record.candidates,
        })
    }

    pub fn pin_candidate_offline(
        &mut self,
        candidate: &LrclibCandidate,
        source: LyricsSource,
        track: &CleanedTrack,
        candidates: Vec<LrclibCandidate>,
    ) {
        let vid = track.raw.id.trim();
        let record = CachedLyricsRecord {
            track_key: track.track_key.clone(),
            video_id: if vid.is_empty() { None } else { Some(vid.to_string()) },
            meta_slug: Some(Self::meta_slug(track)),
            source,
            candidate_id: Some(candidate.id),
            plain_lyrics: candidate.plain_lyrics.clone(),
            synced_lyrics: candidate.synced_lyrics.clone(),
            candidates,
            last_accessed_at: now_ms(),
            pinned_offline: true,
        };
        self.disk.cache.insert(track.track_key.clone(), record);
        self.persist();
    }

    pub fn save_user_synced_lyrics(&mut self, lrc_text: &str, plain_text: &str, track: &CleanedTrack) -> ResolvedLyrics {
        let vid = track.raw.id.trim();
        let record = CachedLyricsRecord {
            track_key: track.track_key.clone(),
            video_id: if vid.is_empty() { None } else { Some(vid.to_string()) },
            meta_slug: Some(Self::meta_slug(track)),
            source: LyricsSource::UserSynced,
            candidate_id: None,
            plain_lyrics: Some(plain_text.to_string()),
            synced_lyrics: Some(lrc_text.to_string()),
            candidates: vec![],
            last_accessed_at: now_ms(),
            pinned_offline: true,
        };
        self.disk.cache.insert(track.track_key.clone(), record);
        self.persist();

        ResolvedLyrics {
            source: LyricsSource::UserSynced,
            parsed: LrcParser::parse_lrc(lrc_text, track.raw.duration),
            candidate_id: None,
            candidates: vec![],
        }
    }

    pub async fn fetch_from_lrclib(&mut self, track: &CleanedTrack, pin_offline: bool) -> Option<ResolvedLyrics> {
        let raw_query = format!("{} {}", track.artist, track.title);
        let q = urlencoding::encode(&raw_query);
        let url = format!("https://lrclib.net/api/search?q={q}");
        let resp = self.client.get(url).send().await.ok()?;
        if !resp.status().is_success() {
            return None;
        }
        let candidates: Vec<LrclibCandidate> = resp.json().await.ok()?;
        if candidates.is_empty() {
            return None;
        }

        let best = candidates
            .iter()
            .max_by_key(|c| {
                let mut score: i64 = 0;
                if c.synced_lyrics.as_deref().map(|s| !s.trim().is_empty()).unwrap_or(false) {
                    score += 1000;
                } else if c.plain_lyrics.as_deref().map(|s| !s.trim().is_empty()).unwrap_or(false) {
                    score += 200;
                }
                let diff = (c.duration - track.raw.duration).abs();
                score -= diff as i64;
                score
            })?
            .clone();

        let (source, parsed) = if let Some(ref synced) = best.synced_lyrics {
            if !synced.trim().is_empty() {
                (LyricsSource::LrclibSynced, LrcParser::parse_lrc(synced, track.raw.duration))
            } else if let Some(ref plain) = best.plain_lyrics {
                (LyricsSource::LrclibPlain, LrcParser::parse_plain(plain))
            } else {
                return None;
            }
        } else if let Some(ref plain) = best.plain_lyrics {
            (LyricsSource::LrclibPlain, LrcParser::parse_plain(plain))
        } else {
            return None;
        };

        let vid = track.raw.id.trim();
        let record = CachedLyricsRecord {
            track_key: track.track_key.clone(),
            video_id: if vid.is_empty() { None } else { Some(vid.to_string()) },
            meta_slug: Some(Self::meta_slug(track)),
            source,
            candidate_id: Some(best.id),
            plain_lyrics: best.plain_lyrics.clone(),
            synced_lyrics: best.synced_lyrics.clone(),
            candidates: candidates.clone(),
            last_accessed_at: now_ms(),
            pinned_offline: pin_offline,
        };
        self.disk.cache.insert(track.track_key.clone(), record);
        self.persist();

        Some(ResolvedLyrics {
            source,
            parsed,
            candidate_id: Some(best.id),
            candidates,
        })
    }
}
