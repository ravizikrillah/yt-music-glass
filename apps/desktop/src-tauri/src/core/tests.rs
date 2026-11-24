use crate::core::lrc::LrcParser;
use crate::core::models::{SyncCalculator, TrackInfo};
use crate::core::normalizer::MetadataNormalizer;
use crate::core::romanizer::RomanizerStore;
use crate::core::tap_sync::TapSyncSession;
use crate::core::translation::TranslationService;
use crate::core::updater::is_newer_semver;
use serde::Deserialize;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SharedVectors {
    metadata: Vec<MetaVec>,
    lrc_sample: LrcSampleVec,
    korean_romanization: Vec<KoVec>,
    semver: Vec<SemverVec>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct MetaVec {
    raw_title: String,
    raw_artist: String,
    expected_artist: String,
    expected_title: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct LrcSampleVec {
    text: String,
    duration: f64,
    expected_mode: String,
    expected_has_word_sync: bool,
    expected_line_count: usize,
    expected_first_start: f64,
    expected_first_word_count: usize,
}

#[derive(Deserialize)]
struct KoVec {
    input: String,
    expected: Option<String>,
}

#[derive(Deserialize)]
struct SemverVec {
    remote: String,
    current: String,
    expected: bool,
}

#[test]
fn shared_test_vectors_parity() {
    let raw = include_str!("../../../../../packages/shared/test-vectors/core-vectors.json");
    let vecs: SharedVectors = serde_json::from_str(raw).expect("valid shared vectors JSON");

    for case in vecs.metadata {
        let (artist, title) = MetadataNormalizer::extract_artist_and_title(&case.raw_title, &case.raw_artist);
        assert_eq!(artist, case.expected_artist);
        assert_eq!(title, case.expected_title);
    }

    let parsed = LrcParser::parse_lrc(&vecs.lrc_sample.text, vecs.lrc_sample.duration);
    assert_eq!(parsed.mode, vecs.lrc_sample.expected_mode);
    assert_eq!(parsed.has_word_sync, vecs.lrc_sample.expected_has_word_sync);
    assert_eq!(parsed.lines.len(), vecs.lrc_sample.expected_line_count);
    assert!((parsed.lines[0].start_time - vecs.lrc_sample.expected_first_start).abs() < 0.01);
    assert_eq!(parsed.lines[0].words.as_ref().map(|w| w.len()).unwrap_or(0), vecs.lrc_sample.expected_first_word_count);

    let frame = SyncCalculator::compute_frame(&parsed, 6.0, 0.0);
    assert_eq!(frame.active_line_index, 0);
    assert_eq!(frame.active_word_index, 1);

    let tmp_dir = std::env::temp_dir().join("ytmg_rust_test");
    let rom = RomanizerStore::new(tmp_dir);
    for case in vecs.korean_romanization {
        let actual = rom.romanize_line(&case.input, None);
        assert_eq!(actual, case.expected);
    }

    for case in vecs.semver {
        assert_eq!(is_newer_semver(&case.remote, &case.current), case.expected);
    }

    let (lang, _) = TranslationService::detect_song_language(&[
        "Dan terjadi lagi kisah lama yang terulang kembali".to_string(),
        "Aku ingin kau merasa kamu mengerti aku mengerti kamu".to_string(),
    ]);
    assert_eq!(lang, "id");
    assert!(!TranslationService::should_translate_song(&lang, "auto", "id"));

    let mut tap = TapSyncSession::new(
        MetadataNormalizer::compute_track_key(&TrackInfo {
            id: "vid1".to_string(),
            title: "Song".to_string(),
            artist: "Artist".to_string(),
            album: None,
            duration: 180.0,
            artwork_url: None,
        }),
        &["Line 1".to_string(), "Line 2".to_string()],
    );
    tap.tap_next(10.0);
    tap.tap_next(9.5);
    assert!(tap.lines[1].timestamp.unwrap() >= 10.049);
}
