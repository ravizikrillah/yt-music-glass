import Foundation

enum DetectedScript {
    case latin
    case korean
    case japanese
    case chinese
    case otherNonLatin
}

enum Romanizer {
    // Revised Romanization of Korean tables
    private static let initials = [
        "g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "",
        "j", "jj", "ch", "k", "t", "p", "h",
    ]

    private static let medials = [
        "a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae",
        "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i",
    ]

    private static let finals = [
        "", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l",
        "l", "l", "p", "l", "m", "p", "p", "t", "t", "ng", "t", "t",
        "k", "t", "p", "t",
    ]

    // Liaison onset when a final consonant moves into a following vowel-initial (ㅇ) syllable
    private static let liaisonOnset: [Int: (remainFinal: String, nextOnset: String)] = [
        1: ("", "g"),   // ㄱ
        2: ("", "kk"),  // ㄲ
        3: ("k", "s"),  // ㄳ
        4: ("", "n"),   // ㄴ
        5: ("n", "j"),  // ㄵ
        6: ("", "n"),   // ㄶ (ㅎ silent before ㅇ -> e.g. 알잖아 -> aljana)
        7: ("", "d"),   // ㄷ
        8: ("", "r"),   // ㄹ
        9: ("l", "g"),  // ㄺ
        10: ("l", "m"), // ㄻ
        11: ("l", "b"), // ㄼ
        12: ("l", "s"), // ㄽ
        13: ("l", "t"), // ㄾ
        14: ("l", "p"), // ㄿ
        15: ("", "r"),  // ㅀ (ㅎ silent)
        16: ("", "m"),  // ㅁ
        17: ("", "b"),  // ㅂ
        18: ("p", "s"), // ㅄ
        19: ("", "s"),  // ㅅ
        20: ("", "ss"), // ㅆ
        21: ("ng", ""), // ㅇ (stays ng)
        22: ("", "j"),  // ㅈ
        23: ("", "ch"), // ㅊ
        24: ("", "k"),  // ㅋ
        25: ("", "t"),  // ㅌ
        26: ("", "p"),  // ㅍ
        27: ("", ""),   // ㅎ silent before vowel (좋아 -> joa)
    ]

    static func containsNonLatinScript(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0xAC00...0xD7AF).contains(v) || // Hangul Syllables
               (0x1100...0x11FF).contains(v) || // Hangul Jamo
               (0x3040...0x30FF).contains(v) || // Hiragana & Katakana
               (0x4E00...0x9FFF).contains(v) || // CJK Unified Ideographs
               (0x3400...0x4DBF).contains(v) || // CJK Extension A
               (0x0400...0x04FF).contains(v) || // Cyrillic
               (0x0E00...0x0E7F).contains(v) || // Thai
               (0x0600...0x06FF).contains(v) || // Arabic
               (0x0900...0x097F).contains(v) || // Devanagari
               (0x0370...0x03FF).contains(v)    // Greek
            {
                return true
            }
        }
        return false
    }

    static func detectScript(_ text: String) -> DetectedScript {
        var hasHangul = false
        var hasKana = false
        var hasCJK = false
        var hasOther = false

        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0xAC00...0xD7AF).contains(v) || (0x1100...0x11FF).contains(v) {
                hasHangul = true
            } else if (0x3040...0x30FF).contains(v) {
                hasKana = true
            } else if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) {
                hasCJK = true
            } else if (0x0400...0x04FF).contains(v) ||
                      (0x0E00...0x0E7F).contains(v) ||
                      (0x0600...0x06FF).contains(v) ||
                      (0x0900...0x097F).contains(v) ||
                      (0x0370...0x03FF).contains(v)
            {
                hasOther = true
            }
        }

        if hasHangul { return .korean }
        if hasKana { return .japanese }
        if hasCJK { return .chinese }
        if hasOther { return .otherNonLatin }
        return .latin
    }

    /// Returns romanized pronunciation ONLY when the line contains non-Latin script;
    /// returns nil for pure Latin lines (English, Indonesian, etc.) so there is zero duplication.
    static func romanizeLine(_ line: String, songHint: DetectedScript? = nil) -> String? {
        guard containsNonLatinScript(line) else { return nil }
        let lineScript = detectScript(line)
        let effectiveScript: DetectedScript = {
            // In Japanese songs, a line containing only Kanji (no Kana) should still use Japanese Romaji
            if lineScript == .chinese && songHint == .japanese {
                return .japanese
            }
            return lineScript
        }()

        let raw: String
        switch effectiveScript {
        case .korean:
            raw = romanizeKoreanMixed(line)
        case .japanese:
            raw = romanizeJapanese(line)
        case .chinese:
            raw = romanizeWithCFTransform(line, mandarin: true)
        case .otherNonLatin:
            raw = romanizeWithCFTransform(line, mandarin: false)
        case .latin:
            return nil
        }

        let cleaned = cleanupSpacing(raw)
        if cleaned.isEmpty || cleaned.caseInsensitiveCompare(line.trimmingCharacters(in: .whitespaces)) == .orderedSame {
            return nil
        }
        return cleaned
    }

    /// Pure Swift Revised Romanization of Korean with phonological rules (liaison, assimilation, liquid, aspiration).
    static func romanizeKoreanMixed(_ input: String) -> String {
        let scalars = Array(input.unicodeScalars)
        var result = ""
        var i = 0

        while i < scalars.count {
            if isHangulSyllable(scalars[i]) {
                var run: [UnicodeScalar] = []
                while i < scalars.count && isHangulSyllable(scalars[i]) {
                    run.append(scalars[i])
                    i += 1
                }
                result += romanizeHangulWord(run)
            } else {
                result.unicodeScalars.append(scalars[i])
                i += 1
            }
        }
        return result
    }

    private static func isHangulSyllable(_ scalar: UnicodeScalar) -> Bool {
        (0xAC00...0xD7A3).contains(scalar.value)
    }

    private static func romanizeHangulWord(_ syllables: [UnicodeScalar]) -> String {
        struct Decomposed {
            var lead: Int
            var vowel: Int
            var tail: Int
        }

        let parts: [Decomposed] = syllables.map { s in
            let code = Int(s.value) - 0xAC00
            let lead = code / 588
            let vowel = (code % 588) / 28
            let tail = code % 28
            return Decomposed(lead: lead, vowel: vowel, tail: tail)
        }

        var out = ""
        var pendingOnset: String? = nil

        for idx in 0..<parts.count {
            let cur = parts[idx]
            let next = (idx + 1 < parts.count) ? parts[idx + 1] : nil

            let onset: String
            if let overrideOnset = pendingOnset {
                onset = overrideOnset
                pendingOnset = nil
            } else {
                onset = initials[cur.lead]
            }

            let vowel = medials[cur.vowel]
            var coda = finals[cur.tail]

            if let nxt = next, cur.tail != 0 {
                // 1. Liaison before vowel-initial ㅇ (lead == 11)
                if nxt.lead == 11, let rule = liaisonOnset[cur.tail] {
                    coda = rule.remainFinal
                    pendingOnset = rule.nextOnset
                }
                // 2. Liquid assimilation: ㄴ+ㄹ or ㄹ+ㄴ -> l + l
                else if (cur.tail == 4 && nxt.lead == 5) || (cur.tail == 8 && nxt.lead == 2) || (cur.tail == 8 && nxt.lead == 5) {
                    coda = "l"
                    pendingOnset = "l"
                }
                // 3. Nasal assimilation before ㄴ(2) or ㅁ(6)
                else if nxt.lead == 2 || nxt.lead == 6 {
                    if [1, 2, 3, 9, 24].contains(cur.tail) {
                        coda = "ng"
                    } else if [7, 19, 20, 22, 23, 25, 27].contains(cur.tail) {
                        coda = "n"
                    } else if [17, 18, 26].contains(cur.tail) {
                        coda = "m"
                    }
                }
                // 4. Aspiration with ㅎ (tail 27 or lead 18)
                else if cur.tail == 27 || cur.tail == 6 || cur.tail == 15 {
                    let keepBase = cur.tail == 6 ? "n" : (cur.tail == 15 ? "l" : "")
                    switch nxt.lead {
                    case 0: coda = keepBase; pendingOnset = "k"
                    case 3: coda = keepBase; pendingOnset = "t"
                    case 7: coda = keepBase; pendingOnset = "p"
                    case 12: coda = keepBase; pendingOnset = "ch"
                    default: break
                    }
                } else if nxt.lead == 18 {
                    switch cur.tail {
                    case 1, 2, 24: coda = ""; pendingOnset = "k"
                    case 7, 19, 20, 25: coda = ""; pendingOnset = "t"
                    case 17, 26: coda = ""; pendingOnset = "p"
                    case 22, 23: coda = ""; pendingOnset = "ch"
                    default: break
                    }
                }
            }

            out += onset + vowel + coda
        }

        return out
    }

    /// 100% offline Japanese Kanji + Hiragana + Katakana -> Romaji via Apple CFStringTokenizer.
    static func romanizeJapanese(_ input: String) -> String {
        let nsStr = input as NSString
        let cfStr = input as CFString
        let fullLen = CFStringGetLength(cfStr)
        guard fullLen > 0 else { return input }

        let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault,
            cfStr,
            CFRangeMake(0, fullLen),
            kCFStringTokenizerUnitWord,
            Locale(identifier: "ja") as CFLocale
        )

        var out = ""
        var pos = 0

        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            if range.location > pos {
                let gap = nsStr.substring(with: NSRange(location: pos, length: range.location - pos))
                out += normalizeJapanesePunctuation(gap)
            }

            let tokenText = nsStr.substring(with: NSRange(location: range.location, length: range.length))
            if containsNonLatinScript(tokenText),
               let latin = CFStringTokenizerCopyCurrentTokenAttribute(
                   tokenizer,
                   kCFStringTokenizerAttributeLatinTranscription
               ) as? String,
               !latin.isEmpty
            {
                if !out.isEmpty && !out.hasSuffix(" ") && !out.hasSuffix("\"") && !out.hasSuffix("(") {
                    out += " "
                }
                out += latin
            } else {
                out += tokenText
            }
            pos = range.location + range.length
        }

        if pos < fullLen {
            out += normalizeJapanesePunctuation(nsStr.substring(from: pos))
        }
        return out
    }

    private static func normalizeJapanesePunctuation(_ text: String) -> String {
        text
            .replacingOccurrences(of: "、", with: ", ")
            .replacingOccurrences(of: "。", with: ". ")
            .replacingOccurrences(of: "！", with: "! ")
            .replacingOccurrences(of: "？", with: "? ")
            .replacingOccurrences(of: "「", with: " \"")
            .replacingOccurrences(of: "」", with: "\" ")
            .replacingOccurrences(of: "　", with: " ")
    }

    /// 100% offline Mandarin Pinyin & multi-script transliteration via CFStringTransform.
    static func romanizeWithCFTransform(_ input: String, mandarin: Bool) -> String {
        let mutable = NSMutableString(string: input)
        if mandarin {
            CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        } else {
            CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        }
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return String(mutable)
    }

    private static func cleanupSpacing(_ input: String) -> String {
        input
            .replacingOccurrences(of: #"\s+([,\.\!\?\;\:])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
