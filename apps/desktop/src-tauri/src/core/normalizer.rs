use crate::core::models::{CleanedTrack, TrackInfo};
use once_cell::sync::Lazy;
use regex::Regex;

static RE_PAREN_NOISE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\s*[\(\[\{]\s*(?:official(?:\s+(?:music|lyric|lyrics|audio|4k|hd|hq|mv|video|clip))*\s*(?:video|audio|mv|visualizer|clip)?|lyric(?:s)?(?:\s+video)?|video\s+lirik|lirik(?:\s+lagu)?|music\s+video|visualizer|audio(?:\s+only)?|full\s+(?:song|audio|video)|mv|m/v|hd|4k|hq|explicit|clean(?:\s+version)?|color\s+coded(?:\s+lyrics)?|(?:\d{4}\s+)?remaster(?:ed)?(?:\s+\d{4})?|remastered\s+version|album\s+version|radio\s+edit|single\s+version|feat\.?\s+[^\)\]\}]+|ft\.?\s+[^\)\]\}]+|featuring\s+[^\)\]\}]+|prod\.?\s+[^\)\]\}]+)\s*[\)\]\}]").unwrap()
});
static RE_TRAILING_FEAT: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?i)\s+(?:feat\.?|ft\.?|featuring)\s+.+$").unwrap());
static RE_TRAILING_PIPE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\s*[\|｜]\s*(?:official|lyrics?|lirik|audio|mv|m/v|hd|4k|video|music\s+video|visualizer).*$").unwrap()
});
static RE_TRAILING_DASH_NOISE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?i)\s+[-–—]\s+(?:official\s+(?:music\s+)?(?:video|audio|lyric\s+video|visualizer|mv)|lyrics?|lirik(?:\s+lagu)?|video\s+lirik|audio|mv|m/v|remaster(?:ed)?(?:\s+\d{4})?)$").unwrap()
});
static RE_DASH_SPLIT: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"^(.+?)\s+[-–—]\s+(.+)$").unwrap());
static RE_ARTIST_TOPIC: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?i)\s*-\s*Topic$").unwrap());
static RE_ARTIST_VEVO: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"([a-z0-9])VEVO$").unwrap());
static RE_ARTIST_OFFICIAL: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?i)\s+(?:Official|Music|Channel)$").unwrap());
static RE_NON_ARTIST_PREFIX: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"(?i)^(?:official|lyrics?|lirik|mv|m/v|full\s+album|playlist|ost|audio)$").unwrap());
static RE_SPACES: Lazy<Regex> = Lazy::new(|| Regex::new(r"\s+").unwrap());
static RE_SLUG_STRIP: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"[^\p{L}\p{N}]+").unwrap());

pub struct MetadataNormalizer;

impl MetadataNormalizer {
    fn normalize_ws(input: &str) -> String {
        RE_SPACES.replace_all(input.trim(), " ").trim().to_string()
    }

    fn trim_quotes(input: &str) -> &str {
        input.trim_matches(|c: char| matches!(c, '"' | '\'' | '“' | '”'))
    }

    fn strip_video_noise(input: &str) -> String {
        let mut cleaned = input.to_string();
        let mut prev = String::new();
        while prev != cleaned {
            prev = cleaned.clone();
            cleaned = RE_PAREN_NOISE.replace_all(&cleaned, "").to_string();
        }
        for _ in 0..2 {
            cleaned = RE_TRAILING_PIPE.replace_all(&cleaned, "").to_string();
            cleaned = RE_TRAILING_DASH_NOISE.replace_all(&cleaned, "").to_string();
        }
        Self::normalize_ws(&cleaned)
    }

    pub fn clean_artist(raw: &str) -> String {
        if raw.is_empty() {
            return String::new();
        }
        let primary = raw
            .split('•')
            .next()
            .and_then(|s| s.split('·').next())
            .unwrap_or(raw);
        let s = RE_ARTIST_TOPIC.replace_all(primary, "");
        let s = RE_ARTIST_VEVO.replace_all(&s, "$1");
        let s = RE_ARTIST_OFFICIAL.replace_all(&s, "");
        let cleaned = Self::normalize_ws(&s);
        if cleaned.is_empty() {
            Self::normalize_ws(primary)
        } else {
            cleaned
        }
    }

    fn finalize_title(candidate: &str, fallback: &str) -> String {
        let no_feat = RE_TRAILING_FEAT.replace_all(candidate, "");
        let cleaned = Self::normalize_ws(Self::trim_quotes(&no_feat));
        if cleaned.is_empty() {
            Self::normalize_ws(fallback)
        } else {
            cleaned
        }
    }

    pub fn extract_artist_and_title(raw_title: &str, raw_artist: &str) -> (String, String) {
        let cleaned_channel = Self::clean_artist(raw_artist);
        let denoised = Self::strip_video_noise(raw_title);

        if let Some(caps) = RE_DASH_SPLIT.captures(&denoised) {
            let left = Self::normalize_ws(Self::trim_quotes(&caps[1]));
            let right = Self::normalize_ws(Self::trim_quotes(&caps[2]));
            let is_noise = RE_NON_ARTIST_PREFIX.is_match(&left);

            if !left.is_empty() && !right.is_empty() && !is_noise {
                let left_slug = Self::slugify(&left);
                let right_slug = Self::slugify(&right);
                let chan_slug = Self::slugify(&cleaned_channel);

                let right_matches = !chan_slug.is_empty()
                    && !right_slug.is_empty()
                    && (right_slug == chan_slug
                        || right_slug.contains(&chan_slug)
                        || chan_slug.contains(&right_slug));
                let left_matches = !chan_slug.is_empty()
                    && !left_slug.is_empty()
                    && (left_slug == chan_slug
                        || left_slug.contains(&chan_slug)
                        || chan_slug.contains(&left_slug));

                if right_matches && !left_matches {
                    return (
                        Self::clean_artist(&right),
                        Self::finalize_title(&left, raw_title),
                    );
                }

                let left_no_feat = RE_TRAILING_FEAT.replace_all(&left, "");
                return (
                    Self::clean_artist(&left_no_feat),
                    Self::finalize_title(&right, raw_title),
                );
            }
        }

        (cleaned_channel, Self::finalize_title(&denoised, raw_title))
    }

    pub fn slugify(value: &str) -> String {
        let lower = value.to_lowercase();
        let stripped = RE_SLUG_STRIP.replace_all(&lower, " ");
        Self::normalize_ws(&stripped)
    }

    pub fn compute_track_key(track: &TrackInfo) -> String {
        let (artist, title) = Self::extract_artist_and_title(&track.title, &track.artist);
        let artist_slug = Self::slugify(&artist);
        let title_slug = Self::slugify(&title);
        let vid = track.id.trim();
        if !vid.is_empty() && (!artist_slug.is_empty() || !title_slug.is_empty()) {
            format!("ytm:{vid}::{artist_slug}::{title_slug}")
        } else if !vid.is_empty() {
            format!("ytm:{vid}")
        } else {
            format!("meta:{artist_slug}::{title_slug}")
        }
    }

    pub fn normalize(track: TrackInfo) -> CleanedTrack {
        let (artist, title) = Self::extract_artist_and_title(&track.title, &track.artist);
        let duration = if track.duration.is_finite() && track.duration > 0.0 {
            track.duration.round() as i64
        } else {
            0
        };
        let album = track
            .album
            .as_deref()
            .map(Self::normalize_ws)
            .filter(|s| !s.is_empty());
        CleanedTrack {
            track_key: Self::compute_track_key(&track),
            raw: track,
            title,
            artist,
            album,
            duration,
        }
    }
}
