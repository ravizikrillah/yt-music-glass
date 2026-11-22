import Foundation
import NaturalLanguage

enum TranslateSourceLanguage: String, CaseIterable, Identifiable {
    case auto = "auto"
    case english = "en"
    case indonesian = "id"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh-CN"
    case spanish = "es"
    case french = "fr"
    case thai = "th"

    var id: String { rawValue }

    var shortCode: String {
        switch self {
        case .auto: return "Auto"
        case .english: return "EN"
        case .indonesian: return "ID"
        case .japanese: return "JA"
        case .korean: return "KO"
        case .chinese: return "ZH"
        case .spanish: return "ES"
        case .french: return "FR"
        case .thai: return "TH"
        }
    }

    var displayName: String {
        switch self {
        case .auto: return "Auto Detect"
        case .english: return "English"
        case .indonesian: return "Bahasa Indonesia"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .chinese: return "Mandarin"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .thai: return "Thai"
        }
    }
}

enum TranslateTargetLanguage: String, CaseIterable, Identifiable {
    case indonesian = "id"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh-CN"
    case malay = "ms"
    case spanish = "es"

    var id: String { rawValue }

    var shortCode: String {
        switch self {
        case .indonesian: return "ID"
        case .english: return "EN"
        case .japanese: return "JA"
        case .korean: return "KO"
        case .chinese: return "ZH"
        case .malay: return "MS"
        case .spanish: return "ES"
        }
    }

    var displayName: String {
        switch self {
        case .indonesian: return "Bahasa Indonesia"
        case .english: return "English"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .chinese: return "Mandarin"
        case .malay: return "Melayu"
        case .spanish: return "Spanish"
        }
    }
}

struct TranslationCacheRecord: Codable {
    let detectedLanguage: String?
    let lines: [String?]
    var lastAccessedAt: Double
    var pinnedOffline: Bool?
    var metaKey: String?
}

final class TranslationService {
    private let session: URLSession
    private let cacheURL: URL
    private var cache: [String: TranslationCacheRecord]
    private let maxEntries = 100

    init(cacheURL: URL? = nil) {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: cfg)

        if let customURL = cacheURL {
            self.cacheURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = appSupport.appendingPathComponent("YTMKaraoke", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.cacheURL = dir.appendingPathComponent("translations-cache.json")
        }

        if let raw = try? Data(contentsOf: self.cacheURL),
           let decoded = try? JSONDecoder().decode([String: TranslationCacheRecord].self, from: raw)
        {
            self.cache = decoded
        } else {
            self.cache = [:]
        }
    }

    static func normalizeLangCode(_ code: String?) -> String {
        guard let raw = code?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return ""
        }
        if raw.hasPrefix("zh") { return "zh" }
        if raw == "in" { return "id" } // legacy Indonesian ISO code
        return String(raw.prefix(2))
    }

    /// Detects the primary song language 100% offline using script ratios + Apple NLLanguageRecognizer.
    static func detectSongLanguage(lines: [String]) -> (langCode: String, scriptHint: DetectedScript) {
        let nonEmpty = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return ("", .latin) }

        var koCount = 0
        var jaCount = 0
        var zhCount = 0
        var otherCount = 0

        for line in nonEmpty {
            switch Romanizer.detectScript(line) {
            case .korean: koCount += 1
            case .japanese: jaCount += 1
            case .chinese: zhCount += 1
            case .otherNonLatin: otherCount += 1
            case .latin: break
            }
        }

        let threshold = max(1, Int(ceil(Double(nonEmpty.count) * 0.12)))
        if koCount >= threshold { return ("ko", .korean) }
        if jaCount >= threshold { return ("ja", .japanese) }
        if zhCount >= threshold { return ("zh", .chinese) }

        let sample = nonEmpty.prefix(30).joined(separator: "\n")
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        let nlCode = normalizeLangCode(recognizer.dominantLanguage?.rawValue)

        if otherCount >= threshold {
            return (nlCode.isEmpty ? "und" : nlCode, .otherNonLatin)
        }
        return (nlCode, .latin)
    }

    /// Determines whether translation should be shown: ONLY when the song's language differs from target!
    static func shouldTranslateSong(
        detectedLang: String,
        source: TranslateSourceLanguage,
        target: TranslateTargetLanguage
    ) -> Bool {
        let normTarget = normalizeLangCode(target.rawValue)
        let normDetected = normalizeLangCode(detectedLang)

        if source != .auto {
            let normSource = normalizeLangCode(source.rawValue)
            if normSource == normTarget { return false }
        }

        // If the song is already in the target language (e.g. Indonesian song when target is Indonesian), skip!
        if !normDetected.isEmpty && normDetected == normTarget {
            return false
        }

        // Indonesian & Malay are mutually intelligible enough that NLLanguageRecognizer occasionally flags
        // short Indonesian lyrics as "ms" — treat "ms" as matching when target is "id" and source is Auto.
        if source == .auto && normTarget == "id" && normDetected == "ms" {
            return false
        }

        return true
    }

    static func makeMetaKey(artist: String, title: String, source: TranslateSourceLanguage, target: TranslateTargetLanguage) -> String? {
        let t = MetadataNormalizer.slugify(title)
        guard !t.isEmpty else { return nil }
        let a = MetadataNormalizer.slugify(artist)
        return "\(a)::\(t)::\(source.rawValue)->\(target.rawValue)"
    }

    func lookupCachedTranslation(
        trackKey: String,
        metaKey: String?,
        lineCount: Int,
        source: TranslateSourceLanguage,
        target: TranslateTargetLanguage
    ) -> (key: String, record: TranslationCacheRecord)? {
        let cacheKey = "\(trackKey)::\(source.rawValue)->\(target.rawValue)"
        if let hit = cache[cacheKey], hit.lines.count == lineCount {
            return (cacheKey, hit)
        }
        if let mk = metaKey, !mk.isEmpty {
            for (k, rec) in cache where rec.metaKey == mk && rec.lines.count == lineCount {
                return (k, rec)
            }
        }
        return nil
    }

    func saveOfflineTranslationForTesting(
        trackKey: String,
        metaKey: String?,
        detectedLang: String,
        lines: [String?],
        source: TranslateSourceLanguage,
        target: TranslateTargetLanguage
    ) {
        let cacheKey = "\(trackKey)::\(source.rawValue)->\(target.rawValue)"
        cache[cacheKey] = TranslationCacheRecord(
            detectedLanguage: detectedLang,
            lines: lines,
            lastAccessedAt: Date().timeIntervalSince1970,
            pinnedOffline: true,
            metaKey: metaKey
        )
        persist()
    }

    func pinExistingOffline(
        trackKey: String,
        metaKey: String?,
        lineCount: Int,
        source: TranslateSourceLanguage,
        target: TranslateTargetLanguage
    ) {
        guard let found = lookupCachedTranslation(
            trackKey: trackKey,
            metaKey: metaKey,
            lineCount: lineCount,
            source: source,
            target: target
        ) else { return }
        var rec = found.record
        rec.pinnedOffline = true
        rec.metaKey = rec.metaKey ?? metaKey
        cache[found.key] = rec
        persist()
    }

    func translateLyrics(
        trackKey: String,
        metaKey: String? = nil,
        lines: [String],
        source: TranslateSourceLanguage,
        target: TranslateTargetLanguage,
        pinOffline: Bool = false
    ) async -> (detectedLang: String, translations: [String?]) {
        let (detectedLang, _) = Self.detectSongLanguage(lines: lines)
        guard Self.shouldTranslateSong(detectedLang: detectedLang, source: source, target: target) else {
            return (detectedLang, Array(repeating: nil, count: lines.count))
        }

        let cacheKey = "\(trackKey)::\(source.rawValue)->\(target.rawValue)"
        if let found = lookupCachedTranslation(
            trackKey: trackKey,
            metaKey: metaKey,
            lineCount: lines.count,
            source: source,
            target: target
        ) {
            var hit = found.record
            hit.lastAccessedAt = Date().timeIntervalSince1970
            if pinOffline { hit.pinnedOffline = true }
            if hit.metaKey == nil { hit.metaKey = metaKey }
            cache[found.key] = hit
            persist()
            return (hit.detectedLanguage ?? detectedLang, hit.lines)
        }

        // Deduplicate non-empty lines to minimize network payload (choruses translate once!)
        var uniqueOrder: [String] = []
        var uniqueIndex: [String: Int] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if uniqueIndex[trimmed] == nil {
                uniqueIndex[trimmed] = uniqueOrder.count
                uniqueOrder.append(trimmed)
            }
        }

        guard !uniqueOrder.isEmpty else {
            return (detectedLang, Array(repeating: nil, count: lines.count))
        }

        let normTarget = Self.normalizeLangCode(target.rawValue)
        var translatedMap: [String: String?] = [:]
        var detectedFromAPI = detectedLang

        // Process in clean batches of 22 lines
        let batchSize = 22
        var offset = 0
        while offset < uniqueOrder.count {
            if Task.isCancelled { return (detectedLang, Array(repeating: nil, count: lines.count)) }
            let end = min(uniqueOrder.count, offset + batchSize)
            let batch = Array(uniqueOrder[offset..<end])

            if let batchResults = await translateBatchClients5(batch, source: source.rawValue, target: target.rawValue) {
                for (i, original) in batch.enumerated() where i < batchResults.count {
                    let (translated, lineLang) = batchResults[i]
                    let normLineLang = Self.normalizeLangCode(lineLang)
                    if detectedFromAPI.isEmpty && !normLineLang.isEmpty {
                        detectedFromAPI = normLineLang
                    }

                    // Skip line translation if this specific line is already in the target language
                    // (e.g., pure English lines in a K-Pop song when translating to English).
                    // Never skip mixed non-Latin lines (e.g. `But you DM me, "니가 궁금해서"`) when translating
                    // into a Latin target, even if the API tags the mixed line as the target language.
                    let isMixedNonLatinToLatin = Romanizer.containsNonLatinScript(original)
                        && !["ko", "ja", "zh"].contains(normTarget)
                    let sameLineLang = !normLineLang.isEmpty && (
                        normLineLang == normTarget ||
                        (source == .auto && normTarget == "id" && normLineLang == "ms")
                    )
                    if !isMixedNonLatinToLatin && sameLineLang {
                        translatedMap[original] = nil
                    } else if isEffectivelySame(original, translated) {
                        translatedMap[original] = nil
                    } else {
                        translatedMap[original] = translated
                    }
                }
            } else {
                // Fallback to MyMemory per-line if clients5 is unavailable
                let srcFallback = source == .auto ? (detectedLang.isEmpty ? "en" : detectedLang) : source.rawValue
                for original in batch {
                    if Task.isCancelled { return (detectedLang, Array(repeating: nil, count: lines.count)) }
                    if let translated = await translateSingleMyMemory(original, source: srcFallback, target: target.rawValue),
                       !isEffectivelySame(original, translated)
                    {
                        translatedMap[original] = translated
                    } else {
                        translatedMap[original] = nil
                    }
                }
            }

            offset = end
        }

        let mappedLines: [String?] = lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return translatedMap[trimmed] ?? nil
        }

        if mappedLines.contains(where: { $0 != nil }) {
            let wasPinned = (cache[cacheKey]?.pinnedOffline == true) || pinOffline
            cache[cacheKey] = TranslationCacheRecord(
                detectedLanguage: detectedFromAPI,
                lines: mappedLines,
                lastAccessedAt: Date().timeIntervalSince1970,
                pinnedOffline: wasPinned ? true : nil,
                metaKey: metaKey
            )
            pruneCacheIfNeeded()
            persist()
        }

        return (detectedFromAPI, mappedLines)
    }

    func clearCache() {
        cache = cache.filter { $0.value.pinnedOffline == true }
        persist()
    }

    func clearOfflineCache() {
        cache = cache.filter { $0.value.pinnedOffline != true }
        persist()
    }

    private func isEffectivelySame(_ a: String, _ b: String) -> Bool {
        let sa = MetadataNormalizer.slugify(a)
        let sb = MetadataNormalizer.slugify(b)
        return sa == sb || sb.isEmpty
    }

    private func translateBatchClients5(
        _ lines: [String],
        source: String,
        target: String
    ) async -> [(String, String?)]? {
        var comps = URLComponents(string: "https://clients5.google.com/translate_a/t")!
        comps.queryItems = [
            URLQueryItem(name: "client", value: "dict-chrome-ex"),
            URLQueryItem(name: "sl", value: source),
            URLQueryItem(name: "tl", value: target),
        ]
        guard let url = comps.url else { return nil }

        // Encode multiple q=... fields in application/x-www-form-urlencoded POST body
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        let formBody = lines.map { line in
            "q=" + (line.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        }.joined(separator: "&")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = formBody.data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
                return nil
            }

            var out: [(String, String?)] = []
            for item in json {
                if let pair = item as? [Any], let text = pair.first as? String {
                    let lang = pair.count > 1 ? (pair[1] as? String) : nil
                    out.append((text.trimmingCharacters(in: .whitespacesAndNewlines), lang))
                } else if let text = item as? String {
                    out.append((text.trimmingCharacters(in: .whitespacesAndNewlines), nil))
                }
            }
            return out.count == lines.count ? out : nil
        } catch {
            return nil
        }
    }

    private func translateSingleMyMemory(_ text: String, source: String, target: String) async -> String? {
        let src = Self.normalizeLangCode(source)
        let dst = Self.normalizeLangCode(target)
        guard !src.isEmpty && !dst.isEmpty && src != dst else { return nil }

        var comps = URLComponents(string: "https://api.mymemory.translated.net/get")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "\(src)|\(dst)"),
        ]
        guard let url = comps.url else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let respData = obj["responseData"] as? [String: Any],
                  let translated = respData["translatedText"] as? String
            else { return nil }
            return translated.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func persist() {
        guard let encoded = try? JSONEncoder().encode(cache) else { return }
        try? encoded.write(to: cacheURL, options: .atomic)
    }

    private func pruneCacheIfNeeded() {
        let ephemeralKeys = cache.keys.filter { cache[$0]?.pinnedOffline != true }
        guard ephemeralKeys.count > maxEntries else { return }
        let sorted = ephemeralKeys.sorted { (cache[$0]?.lastAccessedAt ?? 0) < (cache[$1]?.lastAccessedAt ?? 0) }
        for key in sorted.prefix(ephemeralKeys.count - maxEntries) {
            cache.removeValue(forKey: key)
        }
    }
}
