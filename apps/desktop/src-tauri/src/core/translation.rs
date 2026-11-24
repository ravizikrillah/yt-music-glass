use crate::core::models::now_ms;
use crate::core::romanizer::{DetectedScript, RomanizerStore};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TranslationCacheRecord {
    pub detected_language: Option<String>,
    pub lines: Vec<Option<String>>,
    pub last_accessed_at: f64,
    pub pinned_offline: Option<bool>,
    pub meta_key: Option<String>,
}

pub struct TranslationService {
    cache_path: PathBuf,
    cache: HashMap<String, TranslationCacheRecord>,
    client: reqwest::Client,
}

impl TranslationService {
    pub fn new(app_dir: PathBuf) -> Self {
        let _ = fs::create_dir_all(&app_dir);
        let cache_path = app_dir.join("translations-cache.json");
        let cache = fs::read_to_string(&cache_path)
            .ok()
            .and_then(|s| serde_json::from_str::<HashMap<String, TranslationCacheRecord>>(&s).ok())
            .unwrap_or_default();
        let client = reqwest::Client::builder()
            .user_agent("YT Music Glass Desktop")
            .timeout(std::time::Duration::from_secs(10))
            .build()
            .unwrap_or_default();
        Self {
            cache_path,
            cache,
            client,
        }
    }

    fn persist(&self) {
        if let Ok(json) = serde_json::to_string_pretty(&self.cache) {
            let _ = fs::write(&self.cache_path, json);
        }
    }

    pub fn normalize_lang_code(raw: Option<&str>) -> String {
        let cleaned = raw.unwrap_or("").trim().to_lowercase();
        if cleaned.is_empty() {
            return String::new();
        }
        if cleaned.starts_with("zh") || cleaned == "cmn" {
            return "zh".to_string();
        }
        if cleaned == "in" || cleaned == "ind" {
            return "id".to_string();
        }
        if cleaned == "eng" {
            return "en".to_string();
        }
        if cleaned == "jpn" {
            return "ja".to_string();
        }
        if cleaned == "kor" {
            return "ko".to_string();
        }
        if cleaned == "spa" {
            return "es".to_string();
        }
        if cleaned == "fra" {
            return "fr".to_string();
        }
        if cleaned == "tha" {
            return "th".to_string();
        }
        if cleaned == "msa" || cleaned == "zsm" {
            return "ms".to_string();
        }
        cleaned.chars().take(2).collect()
    }

    pub fn detect_song_language(lines: &[String]) -> (String, DetectedScript) {
        let non_empty: Vec<&str> = lines.iter().map(|s| s.trim()).filter(|s| !s.is_empty()).collect();
        if non_empty.is_empty() {
            return (String::new(), DetectedScript::Latin);
        }

        let mut ko = 0usize;
        let mut ja = 0usize;
        let mut zh = 0usize;
        let mut other = 0usize;
        for line in &non_empty {
            match RomanizerStore::detect_script(line) {
                DetectedScript::Korean => ko += 1,
                DetectedScript::Japanese => ja += 1,
                DetectedScript::Chinese => zh += 1,
                DetectedScript::OtherNonLatin => other += 1,
                DetectedScript::Latin => {}
            }
        }

        let threshold = ((non_empty.len() as f64) * 0.12).ceil().max(1.0) as usize;
        if ko >= threshold {
            return ("ko".to_string(), DetectedScript::Korean);
        }
        if ja >= threshold {
            return ("ja".to_string(), DetectedScript::Japanese);
        }
        if zh >= threshold {
            return ("zh".to_string(), DetectedScript::Chinese);
        }

        let sample = non_empty.iter().take(30).copied().collect::<Vec<_>>().join("\n");
        let detected = whatlang::detect(&sample)
            .map(|info| Self::normalize_lang_code(Some(info.lang().code())))
            .unwrap_or_default();

        if other >= threshold {
            return (
                if detected.is_empty() { "und".to_string() } else { detected },
                DetectedScript::OtherNonLatin,
            );
        }
        (detected, DetectedScript::Latin)
    }

    pub fn should_translate_song(detected_lang: &str, source: &str, target: &str) -> bool {
        if source != "auto" {
            return Self::normalize_lang_code(Some(source)) != Self::normalize_lang_code(Some(target));
        }
        if detected_lang.is_empty() {
            return true;
        }
        Self::normalize_lang_code(Some(detected_lang)) != Self::normalize_lang_code(Some(target))
    }

    pub fn cache_key(track_key: &str, source: &str, target: &str) -> String {
        format!("{track_key}::{source}::{target}")
    }

    pub async fn translate_lines(
        &mut self,
        track_key: &str,
        lines: &[String],
        source: &str,
        target: &str,
        pin_offline: bool,
    ) -> Vec<Option<String>> {
        let key = Self::cache_key(track_key, source, target);
        if let Some(cached) = self.cache.get(&key) {
            if cached.lines.len() == lines.len() {
                return cached.lines.clone();
            }
        }

        let (detected, _) = Self::detect_song_language(lines);
        if !Self::should_translate_song(&detected, source, target) {
            return vec![None; lines.len()];
        }

        let joined = lines.join("\n");
        let q = urlencoding::encode(&joined);
        let sl = if source == "auto" { "auto" } else { source };
        let url = format!(
            "https://translate.googleapis.com/translate_a/single?client=gtx&sl={sl}&tl={target}&dt=t&q={q}"
        );

        let Ok(resp) = self.client.get(url).send().await else {
            return vec![None; lines.len()];
        };
        let Ok(val) = resp.json::<serde_json::Value>().await else {
            return vec![None; lines.len()];
        };

        let mut translated_text = String::new();
        if let Some(chunks) = val.get(0).and_then(|v| v.as_array()) {
            for chunk in chunks {
                if let Some(part) = chunk.get(0).and_then(|v| v.as_str()) {
                    translated_text.push_str(part);
                }
            }
        }

        let parts: Vec<&str> = translated_text.split('\n').collect();
        let out: Vec<Option<String>> = lines
            .iter()
            .enumerate()
            .map(|(i, orig)| {
                let candidate = parts.get(i).map(|s| s.trim()).unwrap_or("");
                if candidate.is_empty() || candidate.eq_ignore_ascii_case(orig.trim()) {
                    None
                } else {
                    Some(candidate.to_string())
                }
            })
            .collect();

        self.cache.insert(
            key,
            TranslationCacheRecord {
                detected_language: Some(detected),
                lines: out.clone(),
                last_accessed_at: now_ms(),
                pinned_offline: Some(pin_offline),
                meta_key: None,
            },
        );
        self.persist();
        out
    }
}
