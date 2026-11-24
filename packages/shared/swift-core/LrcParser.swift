import Foundation

enum LrcParser {
    private static let lineTagRegex = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
    )
    private static let wordTagRegex = try! NSRegularExpression(
        pattern: #"<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>"#
    )
    private static let offsetTagRegex = try! NSRegularExpression(
        pattern: #"^\[offset:\s*([+-]?\d+)\s*\]$"#,
        options: [.caseInsensitive]
    )
    private static let metaTagRegex = try! NSRegularExpression(
        pattern: #"^\[[a-z]{2,8}:[^\]]*\]$"#,
        options: [.caseInsensitive]
    )

    private static func parseSeconds(minStr: String, secStr: String, fracStr: String?) -> Double {
        let mins = Double(Int(minStr) ?? 0)
        let secs = Double(Int(secStr) ?? 0)
        var frac = 0.0
        if let f = fracStr, !f.isEmpty {
            if f.count == 1 {
                frac = Double(Int(f) ?? 0) / 10.0
            } else if f.count == 2 {
                frac = Double(Int(f) ?? 0) / 100.0
            } else {
                frac = Double(Int(String(f.prefix(3))) ?? 0) / 1000.0
            }
        }
        return mins * 60.0 + secs + frac
    }

    private static func parseEnhancedWords(body: String, lineStart: Double, offsetSec: Double) -> (text: String, words: [LyricWord]?) {
        let fullRange = NSRange(body.startIndex..<body.endIndex, in: body)
        let matches = wordTagRegex.matches(in: body, options: [], range: fullRange)
        if matches.isEmpty {
            return (body.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        struct TagHit {
            let range: Range<String.Index>
            let time: Double
        }

        var hits: [TagHit] = []
        for m in matches {
            guard let whole = Range(m.range(at: 0), in: body),
                  let minR = Range(m.range(at: 1), in: body),
                  let secR = Range(m.range(at: 2), in: body)
            else { continue }
            let fracR = m.range(at: 3).location != NSNotFound ? Range(m.range(at: 3), in: body) : nil
            let time = max(0, parseSeconds(
                minStr: String(body[minR]),
                secStr: String(body[secR]),
                fracStr: fracR.map { String(body[$0]) }
            ) - offsetSec)
            hits.append(TagHit(range: whole, time: time))
        }

        guard !hits.isEmpty else {
            return (body.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        var words: [LyricWord] = []

        let leading = String(body[body.startIndex..<hits[0].range.lowerBound])
        if !leading.trimmingCharacters(in: .whitespaces).isEmpty {
            let trimmedLeft = String(leading.drop(while: { $0.isWhitespace }))
            words.append(LyricWord(startTime: lineStart, endTime: hits[0].time, text: trimmedLeft))
        }

        for i in 0..<hits.count {
            let cur = hits[i]
            let next = (i + 1 < hits.count) ? hits[i + 1] : nil
            let segEnd = next?.range.lowerBound ?? body.endIndex
            let seg = String(body[cur.range.upperBound..<segEnd])
            if seg.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            let cleanedSeg = (i == hits.count - 1)
                ? seg.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
                : seg

            words.append(LyricWord(
                startTime: cur.time,
                endTime: next?.time ?? (cur.time + 0.6),
                text: cleanedSeg
            ))
        }

        if !words.isEmpty {
            words[0].text = String(words[0].text.drop(while: { $0.isWhitespace }))
        }

        let fullText = words.map(\.text).joined()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return words.count >= 2 ? (fullText, words) : (fullText, nil)
    }

    static func parseLrc(_ lrcText: String, trackDuration: Double? = nil) -> ParsedLyrics {
        let normalizedNewlines = lrcText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalizedNewlines.components(separatedBy: "\n")

        var lrcOffsetMs = 0.0
        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if let m = offsetTagRegex.firstMatch(in: trimmed, options: [], range: range),
               let valR = Range(m.range(at: 1), in: trimmed),
               let parsedVal = Double(trimmed[valR])
            {
                lrcOffsetMs = parsedVal
            }
        }
        let offsetSec = lrcOffsetMs / 1000.0

        var entries: [LyricLine] = []

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let fullRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            let tagMatches = lineTagRegex.matches(in: trimmed, options: [], range: fullRange)
            if tagMatches.isEmpty {
                if metaTagRegex.firstMatch(in: trimmed, options: [], range: fullRange) != nil {
                    continue
                }
                continue
            }

            var timestamps: [Double] = []
            var lastEnd = trimmed.startIndex

            for m in tagMatches {
                guard let whole = Range(m.range(at: 0), in: trimmed),
                      let minR = Range(m.range(at: 1), in: trimmed),
                      let secR = Range(m.range(at: 2), in: trimmed)
                else { continue }

                if whole.lowerBound > lastEnd {
                    let gap = String(trimmed[lastEnd..<whole.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !gap.isEmpty { break }
                }

                let fracR = m.range(at: 3).location != NSNotFound ? Range(m.range(at: 3), in: trimmed) : nil
                let seconds = max(0, parseSeconds(
                    minStr: String(trimmed[minR]),
                    secStr: String(trimmed[secR]),
                    fracStr: fracR.map { String(trimmed[$0]) }
                ) - offsetSec)

                timestamps.append(seconds)
                lastEnd = whole.upperBound
            }

            if timestamps.isEmpty { continue }
            let body = String(trimmed[lastEnd..<trimmed.endIndex])

            for start in timestamps {
                let (text, words) = parseEnhancedWords(body: body, lineStart: start, offsetSec: offsetSec)
                let isInst = text.isEmpty || text == "♪" || text == "🎵" || text == "..."
                entries.append(LyricLine(
                    startTime: start,
                    endTime: start + 4.0,
                    text: isInst ? "" : text,
                    words: isInst ? nil : words,
                    isInstrumental: isInst
                ))
            }
        }

        if entries.isEmpty {
            return parsePlainLyrics(lrcText)
        }

        entries.sort { $0.startTime < $1.startTime }

        var deduplicated: [LyricLine] = []
        for entry in entries {
            if let prev = deduplicated.last, prev.isInstrumental && entry.isInstrumental {
                continue
            }
            deduplicated.append(entry)
        }

        var hasWordSync = false
        for i in 0..<deduplicated.count {
            if i + 1 < deduplicated.count {
                deduplicated[i].endTime = max(deduplicated[i].startTime + 0.2, deduplicated[i + 1].startTime)
            } else {
                let fallbackEnd: Double
                if let dur = trackDuration, dur > deduplicated[i].startTime {
                    fallbackEnd = min(dur, deduplicated[i].startTime + 8.0)
                } else {
                    fallbackEnd = deduplicated[i].startTime + 5.0
                }
                deduplicated[i].endTime = max(deduplicated[i].startTime + 0.5, fallbackEnd)
            }

            if var words = deduplicated[i].words, words.count >= 2 {
                hasWordSync = true
                for w in 0..<words.count {
                    if w + 1 < words.count {
                        words[w].endTime = max(words[w].startTime + 0.08, words[w + 1].startTime)
                    } else {
                        let maxEnd = min(deduplicated[i].endTime, words[w].startTime + 3.5)
                        words[w].endTime = max(words[w].startTime + 0.2, maxEnd)
                    }
                }
                deduplicated[i].words = words
            }
        }

        let plainLines = deduplicated.filter { !$0.isInstrumental && !$0.text.isEmpty }.map(\.text)

        return ParsedLyrics(
            mode: "synced",
            hasWordSync: hasWordSync,
            lines: deduplicated,
            plainLines: plainLines
        )
    }

    static func parsePlainLyrics(_ text: String) -> ParsedLyrics {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var result: [String] = []
        for (idx, line) in normalized.enumerated() {
            if !line.isEmpty {
                result.append(line)
            } else if idx > 0 && idx < normalized.count - 1 && !normalized[idx - 1].isEmpty {
                result.append("")
            }
        }

        return ParsedLyrics(mode: "plain", hasWordSync: false, lines: [], plainLines: result)
    }
}
