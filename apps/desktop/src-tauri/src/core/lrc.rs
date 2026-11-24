use crate::core::models::{LyricLine, LyricWord, ParsedLyrics};
use once_cell::sync::Lazy;
use regex::Regex;

static RE_OFFSET: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?i)^\[offset:\s*([+-]?\d+)\s*\]$").unwrap());
static RE_LINE_TAG: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]").unwrap());
static RE_WORD_TAG: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>").unwrap());
static RE_META_TAG: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?i)^\[[a-z]{2,8}:[^\]]*\]$").unwrap());
static RE_SPACES: Lazy<Regex> = Lazy::new(|| Regex::new(r"\s+").unwrap());

pub struct LrcParser;

impl LrcParser {
    fn parse_fraction(frac: Option<&str>) -> f64 {
        let Some(f) = frac else { return 0.0 };
        if f.is_empty() {
            return 0.0;
        }
        let Ok(num) = f.parse::<f64>() else {
            return 0.0;
        };
        match f.len() {
            1 => num / 10.0,
            2 => num / 100.0,
            _ => num / 1000.0,
        }
    }

    fn parse_timestamp(min_str: &str, sec_str: &str, frac: Option<&str>) -> Option<f64> {
        let m: f64 = min_str.parse().ok()?;
        let s: f64 = sec_str.parse().ok()?;
        Some(m * 60.0 + s + Self::parse_fraction(frac))
    }

    fn parse_enhanced_words(
        raw_text: &str,
        line_start: f64,
        offset_sec: f64,
    ) -> Option<Vec<LyricWord>> {
        let matches: Vec<_> = RE_WORD_TAG.find_iter(raw_text).collect();
        if matches.is_empty() {
            return None;
        }

        let mut words = Vec::new();
        for (i, m) in matches.iter().enumerate() {
            let caps = RE_WORD_TAG.captures(m.as_str())?;
            let raw_start = Self::parse_timestamp(
                caps.get(1)?.as_str(),
                caps.get(2)?.as_str(),
                caps.get(3).map(|x| x.as_str()),
            )?;
            let start = (raw_start - offset_sec).max(0.0);
            let slice_start = m.end();
            let slice_end = if i + 1 < matches.len() {
                matches[i + 1].start()
            } else {
                raw_text.len()
            };
            let fragment = &raw_text[slice_start..slice_end];
            if fragment.trim().is_empty() {
                continue;
            }
            let st = start.max(line_start);
            words.push(LyricWord {
                start_time: st,
                end_time: st + 0.35,
                text: fragment.to_string(),
            });
        }

        if words.len() < 2 {
            return None;
        }
        for i in 0..(words.len().saturating_sub(1)) {
            let next_start = words[i + 1].start_time;
            words[i].end_time = next_start.max(words[i].start_time + 0.08);
        }
        Some(words)
    }

    pub fn parse_lrc(lrc_text: &str, track_duration: f64) -> ParsedLyrics {
        let normalized = lrc_text.replace("\r\n", "\n").replace('\r', "\n");
        let mut offset_sec = 0.0;
        for raw in normalized.lines() {
            if let Some(caps) = RE_OFFSET.captures(raw.trim()) {
                if let Ok(ms) = caps[1].parse::<f64>() {
                    offset_sec = ms / 1000.0;
                }
            }
        }

        let mut entries: Vec<LyricLine> = Vec::new();
        for raw_line in normalized.lines() {
            let trimmed = raw_line.trim();
            if trimmed.is_empty() || RE_OFFSET.is_match(trimmed) {
                continue;
            }
            let tag_matches: Vec<_> = RE_LINE_TAG.find_iter(trimmed).collect();
            if tag_matches.is_empty() {
                if RE_META_TAG.is_match(trimmed) {
                    continue;
                }
                continue;
            }

            let last_end = tag_matches.last().map(|m| m.end()).unwrap_or(0);
            let body_raw = trimmed[last_end..].trim();

            for m in tag_matches {
                let Some(caps) = RE_LINE_TAG.captures(m.as_str()) else {
                    continue;
                };
                let Some(raw_time) = Self::parse_timestamp(
                    caps.get(1).map(|x| x.as_str()).unwrap_or("0"),
                    caps.get(2).map(|x| x.as_str()).unwrap_or("0"),
                    caps.get(3).map(|x| x.as_str()),
                ) else {
                    continue;
                };
                let start_time = (raw_time - offset_sec).max(0.0);

                let words = Self::parse_enhanced_words(body_raw, start_time, offset_sec);
                let plain_body = if let Some(ref w) = words {
                    let joined: String = w.iter().map(|x| x.text.as_str()).collect();
                    RE_SPACES.replace_all(joined.trim(), " ").trim().to_string()
                } else {
                    let clean = RE_WORD_TAG.replace_all(body_raw, "");
                    RE_SPACES.replace_all(clean.trim(), " ").trim().to_string()
                };

                let is_instrumental =
                    plain_body.is_empty() || plain_body == "♪" || plain_body == "•••";
                entries.push(LyricLine {
                    start_time,
                    end_time: start_time + 4.0,
                    text: if is_instrumental {
                        String::new()
                    } else {
                        plain_body
                    },
                    words,
                    is_instrumental,
                });
            }
        }

        if entries.is_empty() {
            return Self::parse_plain(lrc_text);
        }

        entries.sort_by(|a, b| {
            a.start_time
                .partial_cmp(&b.start_time)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        for i in 0..entries.len() {
            let next_start = if i + 1 < entries.len() {
                entries[i + 1].start_time
            } else if track_duration > entries[i].start_time {
                track_duration
            } else {
                entries[i].start_time + 4.5
            };
            entries[i].end_time = next_start.max(entries[i].start_time + 0.25);

            let entry_end = entries[i].end_time;
            if let Some(ref mut words) = entries[i].words {
                if let Some(last) = words.last_mut() {
                    last.end_time = entry_end.max(last.start_time + 0.12);
                }
            }
        }

        let has_word_sync = entries
            .iter()
            .any(|l| l.words.as_ref().map(|w| w.len() >= 2).unwrap_or(false));
        let plain_lines = entries
            .iter()
            .filter(|l| !l.is_instrumental && !l.text.is_empty())
            .map(|l| l.text.clone())
            .collect();

        ParsedLyrics {
            mode: "synced".to_string(),
            has_word_sync,
            lines: entries,
            plain_lines,
        }
    }

    pub fn parse_plain(text: &str) -> ParsedLyrics {
        let plain_lines: Vec<String> = text
            .lines()
            .map(|l| l.trim().to_string())
            .filter(|l| !l.is_empty())
            .collect();
        let lines = plain_lines
            .iter()
            .map(|t| LyricLine {
                start_time: 0.0,
                end_time: 0.0,
                text: t.clone(),
                words: None,
                is_instrumental: false,
            })
            .collect();

        ParsedLyrics {
            mode: "plain".to_string(),
            has_word_sync: false,
            lines,
            plain_lines,
        }
    }
}
