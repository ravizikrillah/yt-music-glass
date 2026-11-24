import Foundation

enum MetadataNormalizer {
    private static let noiseParensRegex = try! NSRegularExpression(
        pattern: #"\s*[\(\[\{]\s*(?:official(?:\s+(?:music|lyric|lyrics|audio|4k|hd|hq|mv|video|clip))*\s*(?:video|audio|mv|visualizer|clip)?|lyric(?:s)?(?:\s+video)?|video\s+lirik|lirik(?:\s+lagu)?|music\s+video|visualizer|audio(?:\s+only)?|full\s+(?:song|audio|video)|mv|m\/v|hd|4k|hq|explicit|clean(?:\s+version)?|color\s+coded(?:\s+lyrics)?|(?:\d{4}\s+)?remaster(?:ed)?(?:\s+\d{4})?|remastered\s+version|album\s+version|radio\s+edit|single\s+version|feat\.?\s+[^\)\]\}]+|ft\.?\s+[^\)\]\}]+|featuring\s+[^\)\]\}]+|prod\.?\s+[^\)\]\}]+)\s*[\)\]\}]"#,
        options: [.caseInsensitive]
    )

    private static let trailingFeatRegex = try! NSRegularExpression(
        pattern: #"\s+(?:feat\.?|ft\.?|featuring)\s+.+$"#,
        options: [.caseInsensitive]
    )

    private static let trailingPipeRegex = try! NSRegularExpression(
        pattern: #"\s*[\|｜]\s*(?:official|lyrics?|lirik|audio|mv|m\/v|hd|4k|video|music\s+video|visualizer).*$"#,
        options: [.caseInsensitive]
    )

    private static let trailingDashNoiseRegex = try! NSRegularExpression(
        pattern: #"\s+[-–—]\s+(?:official\s+(?:music\s+)?(?:video|audio|lyric\s+video|visualizer|mv)|lyrics?|lirik(?:\s+lagu)?|video\s+lirik|audio|mv|m\/v|remaster(?:ed)?(?:\s+\d{4})?)$"#,
        options: [.caseInsensitive]
    )

    private static let dashSplitRegex = try! NSRegularExpression(
        pattern: #"^(.+?)\s+[-–—]\s+(.+)$"#
    )

    private static let artistTopicRegex = try! NSRegularExpression(
        pattern: #"\s*-\s*Topic$"#,
        options: [.caseInsensitive]
    )

    private static let artistVevoRegex = try! NSRegularExpression(
        pattern: #"(?<=[a-z0-9])VEVO$"#
    )

    private static let artistOfficialRegex = try! NSRegularExpression(
        pattern: #"\s+(?:Official|Music|Channel)$"#,
        options: [.caseInsensitive]
    )

    private static let nonArtistPrefixRegex = try! NSRegularExpression(
        pattern: #"^(?:official|lyrics?|lirik|mv|m\/v|full\s+album|playlist|ost|audio)$"#,
        options: [.caseInsensitive]
    )

    private static func replacing(_ input: String, regex: NSRegularExpression, with template: String = "") -> String {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }

    private static func normalizeWhitespace(_ input: String) -> String {
        input.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimQuotes(_ input: String) -> String {
        input.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
    }

    private static func stripVideoNoise(_ input: String) -> String {
        var cleaned = input
        var prev = ""
        while prev != cleaned {
            prev = cleaned
            cleaned = replacing(cleaned, regex: noiseParensRegex)
        }
        for _ in 0..<2 {
            cleaned = replacing(cleaned, regex: trailingPipeRegex)
            cleaned = replacing(cleaned, regex: trailingDashNoiseRegex)
        }
        return normalizeWhitespace(cleaned)
    }

    static func cleanArtistName(_ rawArtist: String) -> String {
        guard !rawArtist.isEmpty else { return "" }
        let primary = rawArtist.components(separatedBy: "•").first
            ?? rawArtist.components(separatedBy: "·").first
            ?? rawArtist

        var cleaned = replacing(primary, regex: artistTopicRegex)
        cleaned = replacing(cleaned, regex: artistVevoRegex)
        cleaned = replacing(cleaned, regex: artistOfficialRegex)
        cleaned = normalizeWhitespace(cleaned)
        return cleaned.isEmpty ? normalizeWhitespace(primary) : cleaned
    }

    static func slugify(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        return normalizeWhitespace(String(allowed)).lowercased()
    }

    static func extractArtistAndTitle(rawTitle: String, rawArtist: String = "") -> (artist: String, title: String) {
        let cleanedChannel = cleanArtistName(rawArtist)
        let denoised = stripVideoNoise(rawTitle)

        let fullRange = NSRange(denoised.startIndex..<denoised.endIndex, in: denoised)
        if let match = dashSplitRegex.firstMatch(in: denoised, options: [], range: fullRange),
           let leftRange = Range(match.range(at: 1), in: denoised),
           let rightRange = Range(match.range(at: 2), in: denoised)
        {
            let left = normalizeWhitespace(trimQuotes(String(denoised[leftRange])))
            let right = normalizeWhitespace(trimQuotes(String(denoised[rightRange])))
            let leftCheckRange = NSRange(left.startIndex..<left.endIndex, in: left)
            let isNoisePrefix = nonArtistPrefixRegex.firstMatch(in: left, options: [], range: leftCheckRange) != nil

            if !left.isEmpty && !right.isEmpty && !isNoisePrefix {
                let leftSlug = slugify(left)
                let rightSlug = slugify(right)
                let chanSlug = slugify(cleanedChannel)

                let rightMatchesChan = !chanSlug.isEmpty && !rightSlug.isEmpty &&
                    (rightSlug == chanSlug || rightSlug.contains(chanSlug) || chanSlug.contains(rightSlug))
                let leftMatchesChan = !chanSlug.isEmpty && !leftSlug.isEmpty &&
                    (leftSlug == chanSlug || leftSlug.contains(chanSlug) || chanSlug.contains(leftSlug))

                if rightMatchesChan && !leftMatchesChan {
                    return (
                        artist: cleanArtistName(right),
                        title: finalizeTitle(left, fallback: rawTitle)
                    )
                }

                let leftNoFeat = replacing(left, regex: trailingFeatRegex)
                return (
                    artist: cleanArtistName(leftNoFeat),
                    title: finalizeTitle(right, fallback: rawTitle)
                )
            }
        }

        return (
            artist: cleanedChannel,
            title: finalizeTitle(denoised, fallback: rawTitle)
        )
    }

    private static func finalizeTitle(_ candidate: String, fallback: String) -> String {
        let cleaned = normalizeWhitespace(trimQuotes(replacing(candidate, regex: trailingFeatRegex)))
        return cleaned.isEmpty ? normalizeWhitespace(fallback) : cleaned
    }

    static func computeTrackKey(_ track: TrackInfo) -> String {
        let (artist, title) = extractArtistAndTitle(rawTitle: track.title, rawArtist: track.artist)
        let artistSlug = slugify(artist)
        let titleSlug = slugify(title)
        let trimmedId = track.id.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedId.isEmpty && (!artistSlug.isEmpty || !titleSlug.isEmpty) {
            return "ytm:\(trimmedId)::\(artistSlug)::\(titleSlug)"
        }
        if !trimmedId.isEmpty {
            return "ytm:\(trimmedId)"
        }
        return "meta:\(artistSlug)::\(titleSlug)"
    }

    static func normalize(_ track: TrackInfo) -> CleanedTrack {
        let (artist, title) = extractArtistAndTitle(rawTitle: track.title, rawArtist: track.artist)
        let album = track.album.map { normalizeWhitespace($0) }
        let dur = track.duration.isFinite && track.duration > 0 ? Int(track.duration.rounded()) : 0
        return CleanedTrack(
            trackKey: computeTrackKey(track),
            raw: track,
            title: title,
            artist: artist,
            album: album?.isEmpty == true ? nil : album,
            duration: dur
        )
    }
}
