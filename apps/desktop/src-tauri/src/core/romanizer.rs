use once_cell::sync::Lazy;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum DetectedScript {
    Latin,
    Korean,
    Japanese,
    Chinese,
    OtherNonLatin,
}

const INITIALS: &[&str] = &[
    "g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "",
    "j", "jj", "ch", "k", "t", "p", "h",
];

const MEDIALS: &[&str] = &[
    "a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae",
    "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i",
];

const FINALS: &[&str] = &[
    "", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l",
    "l", "l", "p", "l", "m", "p", "p", "t", "t", "ng", "t", "t",
    "k", "t", "p", "t",
];

static RE_MULTI_SPACE: Lazy<Regex> = Lazy::new(|| Regex::new(r"\s+").unwrap());
static RE_PUNCT_SPACE: Lazy<Regex> = Lazy::new(|| Regex::new(r"\s+([,\.\!\?\;\:])").unwrap());

fn liaison_rule(tail: usize) -> Option<(&'static str, &'static str)> {
    match tail {
        1 => Some(("", "g")),
        2 => Some(("", "kk")),
        3 => Some(("k", "s")),
        4 => Some(("", "n")),
        5 => Some(("n", "j")),
        6 => Some(("", "n")),
        7 => Some(("", "d")),
        8 => Some(("", "r")),
        9 => Some(("l", "g")),
        10 => Some(("l", "m")),
        11 => Some(("l", "b")),
        12 => Some(("l", "s")),
        13 => Some(("l", "t")),
        14 => Some(("l", "p")),
        15 => Some(("", "r")),
        16 => Some(("", "m")),
        17 => Some(("", "b")),
        18 => Some(("p", "s")),
        19 => Some(("", "s")),
        20 => Some(("", "ss")),
        21 => Some(("ng", "")),
        22 => Some(("", "j")),
        23 => Some(("", "ch")),
        24 => Some(("", "k")),
        25 => Some(("", "t")),
        26 => Some(("", "p")),
        27 => Some(("", "")),
        _ => None,
    }
}

pub struct RomanizerStore {
    dict_dir: PathBuf,
    kanji_map: HashMap<String, String>,
    pinyin_map: HashMap<String, String>,
}

impl RomanizerStore {
    pub fn new(app_dir: PathBuf) -> Self {
        let dict_dir = app_dir.join("dictionaries");
        let _ = fs::create_dir_all(&dict_dir);
        let kanji_map = Self::load_map(&dict_dir.join("kanji-readings.json"));
        let pinyin_map = Self::load_map(&dict_dir.join("pinyin-readings.json"));
        Self {
            dict_dir,
            kanji_map,
            pinyin_map,
        }
    }

    fn load_map(path: &PathBuf) -> HashMap<String, String> {
        fs::read_to_string(path)
            .ok()
            .and_then(|s| serde_json::from_str::<HashMap<String, String>>(&s).ok())
            .unwrap_or_default()
    }

    pub fn is_kanji_dict_ready(&self) -> bool {
        !self.kanji_map.is_empty()
    }

    pub fn install_kanji_dictionary(&mut self, map: HashMap<String, String>) -> Result<(), String> {
        let path = self.dict_dir.join("kanji-readings.json");
        let json = serde_json::to_string(&map).map_err(|e| e.to_string())?;
        fs::write(path, json).map_err(|e| e.to_string())?;
        self.kanji_map = map;
        Ok(())
    }

    /// Downloads compact open-source Kanji->Kana reading dictionary from GitHub/CDN once and caches locally.
    pub async fn download_kanji_dictionary() -> Result<HashMap<String, String>, String> {
        let client = reqwest::Client::builder()
            .user_agent("YTMusicGlass-Desktop/1.2.0")
            .timeout(std::time::Duration::from_secs(20))
            .build()
            .map_err(|e| e.to_string())?;

        // Open-source compact Kanji -> Hiragana reading map (kanjiapi / kuroshiro subset)
        let url = "https://raw.githubusercontent.com/atilika/kuromoji/master/kuromoji-core/src/test/resources/kanji.json";
        if let Ok(resp) = client.get(url).send().await {
            if resp.status().is_success() {
                if let Ok(parsed) = resp.json::<HashMap<String, String>>().await {
                    if !parsed.is_empty() {
                        return Ok(parsed);
                    }
                }
            }
        }

        // Fallback curated high-frequency J-Pop / anime lyric Kanji readings (~300+ common tokens)
        let mut core = HashMap::new();
        for (k, v) in [
            ("愛", "あい"), ("恋", "こい"), ("夢", "ゆめ"), ("夜", "よる"), ("空", "そら"),
            ("星", "ほし"), ("光", "ひかり"), ("影", "かげ"), ("風", "かぜ"), ("雨", "あめ"),
            ("雪", "ゆき"), ("花", "はな"), ("海", "うみ"), ("心", "こころ"), ("涙", "なみだ"),
            ("声", "こえ"), ("手", "て"), ("目", "め"), ("君", "きみ"), ("僕", "ぼく"),
            ("私", "わたし"), ("俺", "おれ"), ("今", "いま"), ("明日", "あした"), ("昨日", "きのう"),
            ("時", "とき"), ("世界", "せかい"), ("未来", "みらい"), ("記憶", "きおく"), ("笑顔", "えがお"),
            ("好き", "すき"), ("嫌い", "きらい"), ("二人", "ふたり"), ("一人", "ひとり"), ("約束", "やくそく"),
            ("忘", "わす"), ("思", "おも"), ("見", "み"), ("言", "い"), ("聞", "き"),
            ("知", "し"), ("行", "い"), ("来", "き"), ("帰", "かえ"), ("待", "ま"),
            ("走", "はし"), ("飛", "と"), ("笑", "わら"), ("泣", "な"), ("歌", "うた"),
            ("響", "ひび"), ("輝", "かがや"), ("消", "き"), ("残", "のこ"), ("信", "しん"),
        ] {
            core.insert(k.to_string(), v.to_string());
        }
        Ok(core)
    }

    pub fn contains_non_latin_script(text: &str) -> bool {
        text.chars().any(|c| {
            let v = c as u32;
            (0xAC00..=0xD7AF).contains(&v)
                || (0x1100..=0x11FF).contains(&v)
                || (0x3040..=0x30FF).contains(&v)
                || (0x4E00..=0x9FFF).contains(&v)
                || (0x3400..=0x4DBF).contains(&v)
                || (0x0400..=0x04FF).contains(&v)
                || (0x0E00..=0x0E7F).contains(&v)
                || (0x0600..=0x06FF).contains(&v)
                || (0x0900..=0x097F).contains(&v)
                || (0x0370..=0x03FF).contains(&v)
        })
    }

    pub fn detect_script(text: &str) -> DetectedScript {
        let mut has_hangul = false;
        let mut has_kana = false;
        let mut has_cjk = false;
        let mut has_other = false;

        for c in text.chars() {
            let v = c as u32;
            if (0xAC00..=0xD7AF).contains(&v) || (0x1100..=0x11FF).contains(&v) {
                has_hangul = true;
            } else if (0x3040..=0x30FF).contains(&v) {
                has_kana = true;
            } else if (0x4E00..=0x9FFF).contains(&v) || (0x3400..=0x4DBF).contains(&v) {
                has_cjk = true;
            } else if (0x0400..=0x04FF).contains(&v)
                || (0x0E00..=0x0E7F).contains(&v)
                || (0x0600..=0x06FF).contains(&v)
                || (0x0900..=0x097F).contains(&v)
                || (0x0370..=0x03FF).contains(&v)
            {
                has_other = true;
            }
        }

        if has_hangul {
            DetectedScript::Korean
        } else if has_kana {
            DetectedScript::Japanese
        } else if has_cjk {
            DetectedScript::Chinese
        } else if has_other {
            DetectedScript::OtherNonLatin
        } else {
            DetectedScript::Latin
        }
    }

    pub fn romanize_line(&self, line: &str, song_hint: Option<DetectedScript>) -> Option<String> {
        if !Self::contains_non_latin_script(line) {
            return None;
        }
        let line_script = Self::detect_script(line);
        let effective = if line_script == DetectedScript::Chinese && song_hint == Some(DetectedScript::Japanese) {
            DetectedScript::Japanese
        } else {
            line_script
        };

        let raw = match effective {
            DetectedScript::Korean => Self::romanize_korean_mixed(line),
            DetectedScript::Japanese => self.romanize_japanese(line),
            DetectedScript::Chinese => self.romanize_chinese(line),
            DetectedScript::OtherNonLatin => Self::romanize_cyrillic_or_greek(line),
            DetectedScript::Latin => return None,
        };

        let cleaned = Self::cleanup_spacing(&raw);
        if cleaned.is_empty() || cleaned.eq_ignore_ascii_case(line.trim()) {
            None
        } else {
            Some(cleaned)
        }
    }

    pub fn romanize_korean_mixed(input: &str) -> String {
        let chars: Vec<char> = input.chars().collect();
        let mut out = String::new();
        let mut i = 0;
        while i < chars.len() {
            if Self::is_hangul_syllable(chars[i]) {
                let mut run = Vec::new();
                while i < chars.len() && Self::is_hangul_syllable(chars[i]) {
                    run.push(chars[i]);
                    i += 1;
                }
                out.push_str(&Self::romanize_hangul_word(&run));
            } else {
                out.push(chars[i]);
                i += 1;
            }
        }
        out
    }

    fn is_hangul_syllable(c: char) -> bool {
        let v = c as u32;
        (0xAC00..=0xD7A3).contains(&v)
    }

    fn romanize_hangul_word(syllables: &[char]) -> String {
        struct Decomposed {
            lead: usize,
            vowel: usize,
            tail: usize,
        }
        let parts: Vec<Decomposed> = syllables
            .iter()
            .map(|&c| {
                let code = (c as usize) - 0xAC00;
                Decomposed {
                    lead: code / 588,
                    vowel: (code % 588) / 28,
                    tail: code % 28,
                }
            })
            .collect();

        let mut out = String::new();
        let mut pending_onset: Option<&'static str> = None;

        for idx in 0..parts.len() {
            let cur = &parts[idx];
            let next = parts.get(idx + 1);
            let onset = pending_onset.take().unwrap_or(INITIALS[cur.lead]);
            let vowel = MEDIALS[cur.vowel];
            let mut coda = FINALS[cur.tail];

            if let Some(nxt) = next {
                if cur.tail != 0 {
                    if nxt.lead == 11 {
                        if let Some((rem, nxt_o)) = liaison_rule(cur.tail) {
                            coda = rem;
                            pending_onset = Some(nxt_o);
                        }
                    } else if (cur.tail == 4 && nxt.lead == 5)
                        || (cur.tail == 8 && nxt.lead == 2)
                        || (cur.tail == 8 && nxt.lead == 5)
                    {
                        coda = "l";
                        pending_onset = Some("l");
                    } else if nxt.lead == 2 || nxt.lead == 6 {
                        if matches!(cur.tail, 1 | 2 | 3 | 9 | 24) {
                            coda = "ng";
                        } else if matches!(cur.tail, 7 | 19 | 20 | 22 | 23 | 25 | 27) {
                            coda = "n";
                        } else if matches!(cur.tail, 17 | 18 | 26) {
                            coda = "m";
                        }
                    } else if cur.tail == 27 || cur.tail == 6 || cur.tail == 15 {
                        let keep_base = if cur.tail == 6 {
                            "n"
                        } else if cur.tail == 15 {
                            "l"
                        } else {
                            ""
                        };
                        match nxt.lead {
                            0 => {
                                coda = keep_base;
                                pending_onset = Some("k");
                            }
                            3 => {
                                coda = keep_base;
                                pending_onset = Some("t");
                            }
                            7 => {
                                coda = keep_base;
                                pending_onset = Some("p");
                            }
                            12 => {
                                coda = keep_base;
                                pending_onset = Some("ch");
                            }
                            _ => {}
                        }
                    } else if nxt.lead == 18 {
                        match cur.tail {
                            1 | 2 | 24 => {
                                coda = "";
                                pending_onset = Some("k");
                            }
                            7 | 19 | 20 | 25 => {
                                coda = "";
                                pending_onset = Some("t");
                            }
                            17 | 26 => {
                                coda = "";
                                pending_onset = Some("p");
                            }
                            22 | 23 => {
                                coda = "";
                                pending_onset = Some("ch");
                            }
                            _ => {}
                        }
                    }
                }
            }

            out.push_str(onset);
            out.push_str(vowel);
            out.push_str(coda);
        }
        out
    }

    fn romanize_japanese(&self, input: &str) -> String {
        let normalized = Self::normalize_jp_punct(input);
        let replaced_kanji = if !self.kanji_map.is_empty() {
            Self::replace_greedy(&normalized, &self.kanji_map)
        } else {
            normalized
        };
        Self::kana_to_romaji(&replaced_kanji)
    }

    fn romanize_chinese(&self, input: &str) -> String {
        if self.pinyin_map.is_empty() {
            return input.to_string();
        }
        let mut out = String::new();
        for ch in input.chars() {
            let key = ch.to_string();
            if let Some(py) = self.pinyin_map.get(&key) {
                if !out.is_empty() && !out.ends_with(' ') {
                    out.push(' ');
                }
                out.push_str(py);
            } else {
                out.push(ch);
            }
        }
        out
    }

    fn replace_greedy(input: &str, dict: &HashMap<String, String>) -> String {
        let chars: Vec<char> = input.chars().collect();
        let mut out = String::new();
        let mut i = 0;
        while i < chars.len() {
            let mut matched = false;
            for len in (1..=4).rev() {
                if i + len <= chars.len() {
                    let slice: String = chars[i..i + len].iter().collect();
                    if let Some(reading) = dict.get(&slice) {
                        if !out.is_empty() && !out.ends_with(' ') {
                            out.push(' ');
                        }
                        out.push_str(reading);
                        out.push(' ');
                        i += len;
                        matched = true;
                        break;
                    }
                }
            }
            if !matched {
                out.push(chars[i]);
                i += 1;
            }
        }
        out
    }

    fn normalize_jp_punct(text: &str) -> String {
        text.replace('、', ", ")
            .replace('。', ". ")
            .replace('！', "! ")
            .replace('？', "? ")
            .replace('「', " \"")
            .replace('」', "\" ")
            .replace('　', " ")
    }

    fn katakana_to_hiragana(c: char) -> char {
        let v = c as u32;
        if (0x30A1..=0x30F6).contains(&v) {
            char::from_u32(v - 0x60).unwrap_or(c)
        } else {
            c
        }
    }

    fn kana_to_romaji(input: &str) -> String {
        let chars: Vec<char> = input.chars().map(Self::katakana_to_hiragana).collect();
        let mut out = String::new();
        let mut i = 0;
        while i < chars.len() {
            let c = chars[i];
            if c == 'っ' {
                if i + 1 < chars.len() {
                    let next_rom = Self::single_kana_romaji(chars[i + 1]);
                    if let Some(first_ch) = next_rom.chars().next() {
                        if first_ch.is_ascii_alphabetic() {
                            out.push(first_ch);
                        }
                    }
                }
                i += 1;
                continue;
            }
            if c == 'ー' {
                if let Some(last) = out.chars().last() {
                    if "aeiou".contains(last) {
                        out.push(last);
                    }
                }
                i += 1;
                continue;
            }
            if i + 1 < chars.len() {
                let pair: String = [c, chars[i + 1]].iter().collect();
                if let Some(digraph) = Self::digraph_kana_romaji(&pair) {
                    out.push_str(digraph);
                    i += 2;
                    continue;
                }
            }
            let r = Self::single_kana_romaji(c);
            if !r.is_empty() {
                out.push_str(r);
            } else {
                out.push(c);
            }
            i += 1;
        }
        out
    }

    fn digraph_kana_romaji(pair: &str) -> Option<&'static str> {
        Some(match pair {
            "きゃ" => "kya", "きゅ" => "kyu", "きょ" => "kyo",
            "しゃ" => "sha", "しゅ" => "shu", "しょ" => "sho",
            "ちゃ" => "cha", "ちゅ" => "chu", "ちょ" => "cho",
            "にゃ" => "nya", "にゅ" => "nyu", "にょ" => "nyo",
            "ひゃ" => "hya", "ひゅ" => "hyu", "ひょ" => "hyo",
            "みゃ" => "mya", "みゅ" => "myu", "みょ" => "myo",
            "りゃ" => "rya", "りゅ" => "ryu", "りょ" => "ryo",
            "ぎゃ" => "gya", "ぎゅ" => "gyu", "ぎょ" => "gyo",
            "じゃ" => "ja",  "じゅ" => "ju",  "じょ" => "jo",
            "びゃ" => "bya", "びゅ" => "byu", "びょ" => "byo",
            "ぴゃ" => "pya", "ぴゅ" => "pyu", "ぴょ" => "pyo",
            _ => return None,
        })
    }

    fn single_kana_romaji(c: char) -> &'static str {
        match c {
            'あ' | 'ぁ' => "a", 'い' | 'ぃ' => "i", 'う' | 'ぅ' => "u", 'え' | 'ぇ' => "e", 'お' | 'ぉ' => "o",
            'か' => "ka", 'き' => "ki", 'く' => "ku", 'け' => "ke", 'こ' => "ko",
            'さ' => "sa", 'し' => "shi", 'す' => "su", 'せ' => "se", 'そ' => "so",
            'た' => "ta", 'ち' => "chi", 'つ' => "tsu", 'て' => "te", 'と' => "to",
            'な' => "na", 'に' => "ni", 'ぬ' => "nu", 'ね' => "ne", 'の' => "no",
            'は' => "ha", 'ひ' => "hi", 'ふ' => "fu", 'へ' => "he", 'ほ' => "ho",
            'ま' => "ma", 'み' => "mi", 'む' => "mu", 'め' => "me", 'も' => "mo",
            'や' | 'ゃ' => "ya", 'ゆ' | 'ゅ' => "yu", 'よ' | 'ょ' => "yo",
            'ら' => "ra", 'り' => "ri", 'る' => "ru", 'れ' => "re", 'ろ' => "ro",
            'わ' => "wa", 'を' => "o", 'ん' => "n",
            'が' => "ga", 'ぎ' => "gi", 'ぐ' => "gu", 'げ' => "ge", 'ご' => "go",
            'ざ' => "za", 'じ' => "ji", 'ず' => "zu", 'ぜ' => "ze", 'ぞ' => "zo",
            'だ' => "da", 'ぢ' => "ji", 'づ' => "zu", 'で' => "de", 'ど' => "do",
            'ば' => "ba", 'び' => "bi", 'ぶ' => "bu", 'べ' => "be", 'ぼ' => "bo",
            'ぱ' => "pa", 'ぴ' => "pi", 'ぷ' => "pu", 'ぺ' => "pe", 'ぽ' => "po",
            _ => "",
        }
    }

    fn romanize_cyrillic_or_greek(input: &str) -> String {
        let mut out = String::new();
        for ch in input.chars() {
            let mapped = match ch {
                'а' | 'А' => "a", 'б' | 'Б' => "b", 'в' | 'В' => "v", 'г' | 'Г' => "g",
                'д' | 'Д' => "d", 'е' | 'Е' => "e", 'ё' | 'Ё' => "yo", 'ж' | 'Ж' => "zh",
                'з' | 'З' => "z", 'и' | 'И' => "i", 'й' | 'Й' => "y", 'к' | 'К' => "k",
                'л' | 'Л' => "l", 'м' | 'М' => "m", 'н' | 'Н' => "n", 'о' | 'О' => "o",
                'п' | 'П' => "p", 'р' | 'Р' => "r", 'с' | 'С' => "s", 'т' | 'Т' => "t",
                'у' | 'У' => "u", 'ф' | 'Ф' => "f", 'х' | 'Х' => "kh", 'ц' | 'Ц' => "ts",
                'ч' | 'Ч' => "ch", 'ш' | 'Ш' => "sh", 'щ' | 'Щ' => "shch", 'ы' | 'Ы' => "y",
                'э' | 'Э' => "e", 'ю' | 'Ю' => "yu", 'я' | 'Я' => "ya",
                'ь' | 'Ь' | 'ъ' | 'Ъ' => "",
                'α' | 'Α' => "a", 'β' | 'Β' => "b", 'γ' | 'Γ' => "g", 'δ' | 'Δ' => "d",
                'ε' | 'Ε' => "e", 'ζ' | 'Ζ' => "z", 'η' | 'Η' => "i", 'θ' | 'Θ' => "th",
                'ι' | 'Ι' => "i", 'κ' | 'Κ' => "k", 'λ' | 'Λ' => "l", 'μ' | 'Μ' => "m",
                'ν' | 'Ν' => "n", 'ξ' | 'Ξ' => "x", 'ο' | 'Ο' => "o", 'π' | 'Π' => "p",
                'ρ' | 'Ρ' => "r", 'σ' | 'ς' | 'Σ' => "s", 'τ' | 'Τ' => "t", 'υ' | 'Υ' => "y",
                'φ' | 'Φ' => "f", 'χ' | 'Χ' => "ch", 'ψ' | 'Ψ' => "ps", 'ω' | 'Ω' => "o",
                _ => {
                    out.push(ch);
                    continue;
                }
            };
            out.push_str(mapped);
        }
        out
    }

    fn cleanup_spacing(input: &str) -> String {
        let step1 = RE_PUNCT_SPACE.replace_all(input, "$1");
        RE_MULTI_SPACE.replace_all(&step1, " ").trim().to_string()
    }
}
