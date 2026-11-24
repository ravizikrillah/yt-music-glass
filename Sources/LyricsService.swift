import Foundation

struct TrackOverrideRecord: Codable {
    var offsetMs: Double
    var selectedCandidate: LrclibCandidate?
    var updatedAt: Double
}

struct CachedLyricsRecord: Codable {
    let source: LyricsSource
    let rawSyncedLyrics: String?
    let rawPlainLyrics: String?
    let candidateId: Int?
    var lastAccessedAt: Double
    var pinnedOffline: Bool?
    var videoId: String?
    var artistSlug: String?
    var titleSlug: String?
    var duration: Int?
    var savedTitle: String?
    var savedArtist: String?
}

struct PersistedStoreData: Codable {
    var overrides: [String: TrackOverrideRecord] = [:]
    var cache: [String: CachedLyricsRecord] = [:]
}

final class LyricsService {
    private let session: URLSession
    private let storeURL: URL
    private var data: PersistedStoreData
    private let maxCacheEntries = 80
    private let maxOverrideEntries = 300
    private static let wordTagHintRegex = try! NSRegularExpression(
        pattern: #"<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>"#
    )

    init(storeURL: URL? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Lrclib-Client": "YT Music Glass macOS v\(AppIdentity.currentVersion)",
        ]
        self.session = URLSession(configuration: config)

        if let customURL = storeURL {
            self.storeURL = customURL
        } else {
            let dir = AppIdentity.appSupportDirectory()
            self.storeURL = dir.appendingPathComponent("lyrics-store.json")
        }

        if let raw = try? Data(contentsOf: self.storeURL),
           let decoded = try? JSONDecoder().decode(PersistedStoreData.self, from: raw)
        {
            self.data = decoded
        } else {
            self.data = PersistedStoreData()
        }
    }

    private func persist() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: storeURL, options: .atomic)
    }

    func getOffsetMs(for trackKey: String) -> Double {
        data.overrides[trackKey]?.offsetMs ?? 0
    }

    func saveOffsetMs(_ offsetMs: Double, for trackKey: String) {
        var existing = data.overrides[trackKey] ?? TrackOverrideRecord(offsetMs: 0, selectedCandidate: nil, updatedAt: 0)
        existing.offsetMs = offsetMs
        existing.updatedAt = Date().timeIntervalSince1970
        data.overrides[trackKey] = existing
        pruneOverridesIfNeeded()
        persist()
    }

    func saveSelectedCandidate(_ candidate: LrclibCandidate, for track: CleanedTrack, pinOffline: Bool = false) {
        let trackKey = track.trackKey
        var existing = data.overrides[trackKey] ?? TrackOverrideRecord(offsetMs: 0, selectedCandidate: nil, updatedAt: 0)
        existing.selectedCandidate = candidate
        existing.updatedAt = Date().timeIntervalSince1970
        data.overrides[trackKey] = existing

        let wasPinned = (data.cache[trackKey]?.pinnedOffline == true) || pinOffline
        let hasSynced = !(candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        data.cache[trackKey] = makeCacheRecord(
            source: hasSynced ? .lrclibSynced : .lrclibPlain,
            rawSyncedLyrics: candidate.syncedLyrics,
            rawPlainLyrics: candidate.plainLyrics,
            candidateId: candidate.id,
            track: track,
            pinnedOffline: wasPinned
        )
        pruneOverridesIfNeeded()
        pruneCacheIfNeeded()
        persist()
    }

    func saveSelectedCandidate(_ candidate: LrclibCandidate, for trackKey: String) {
        var existing = data.overrides[trackKey] ?? TrackOverrideRecord(offsetMs: 0, selectedCandidate: nil, updatedAt: 0)
        existing.selectedCandidate = candidate
        existing.updatedAt = Date().timeIntervalSince1970
        data.overrides[trackKey] = existing

        let wasPinned = data.cache[trackKey]?.pinnedOffline == true
        let hasSynced = !(candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        data.cache[trackKey] = CachedLyricsRecord(
            source: hasSynced ? .lrclibSynced : .lrclibPlain,
            rawSyncedLyrics: candidate.syncedLyrics,
            rawPlainLyrics: candidate.plainLyrics,
            candidateId: candidate.id,
            lastAccessedAt: Date().timeIntervalSince1970,
            pinnedOffline: wasPinned ? true : nil,
            videoId: data.cache[trackKey]?.videoId,
            artistSlug: MetadataNormalizer.slugify(candidate.artistName),
            titleSlug: MetadataNormalizer.slugify(candidate.trackName),
            duration: Int(candidate.duration.rounded()),
            savedTitle: candidate.trackName,
            savedArtist: candidate.artistName
        )
        pruneOverridesIfNeeded()
        pruneCacheIfNeeded()
        persist()
    }

    /// Clears temporary streaming cache while preserving permanently pinned offline karaoke lyrics.
    func clearCache() {
        data.cache = data.cache.filter { $0.value.pinnedOffline == true }
        persist()
    }

    /// Explicitly removes all pinned offline lyrics from disk.
    func clearOfflineVault() {
        data.cache = data.cache.filter { $0.value.pinnedOffline != true }
        persist()
    }

    func cacheCount() -> Int {
        data.cache.values.filter { $0.pinnedOffline != true }.count
    }

    func offlineCount() -> Int {
        data.cache.values.filter { $0.pinnedOffline == true }.count
    }

    func hasOfflineLyrics(for track: CleanedTrack) -> Bool {
        if let hit = findCachedRecord(for: track), hit.record.pinnedOffline == true {
            return true
        }
        return false
    }

    @discardableResult
    func pinExistingForOffline(track: CleanedTrack) -> Bool {
        if let hit = findCachedRecord(for: track) {
            var updated = hit.record
            updated.pinnedOffline = true
            updated.lastAccessedAt = Date().timeIntervalSince1970
            if updated.videoId?.isEmpty != false && !track.raw.id.isEmpty {
                updated.videoId = track.raw.id
            }
            if updated.artistSlug?.isEmpty != false && !track.artist.isEmpty {
                updated.artistSlug = MetadataNormalizer.slugify(track.artist)
            }
            if updated.titleSlug?.isEmpty != false && !track.title.isEmpty {
                updated.titleSlug = MetadataNormalizer.slugify(track.title)
            }
            if (updated.duration ?? 0) <= 0 && track.duration > 0 {
                updated.duration = track.duration
            }
            updated.savedTitle = updated.savedTitle ?? track.title
            updated.savedArtist = updated.savedArtist ?? track.artist
            data.cache[hit.key] = updated
            persist()
            return true
        }
        if let selected = data.overrides[track.trackKey]?.selectedCandidate {
            let hasSynced = !(selected.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            data.cache[track.trackKey] = makeCacheRecord(
                source: hasSynced ? .lrclibSynced : .lrclibPlain,
                rawSyncedLyrics: selected.syncedLyrics,
                rawPlainLyrics: selected.plainLyrics,
                candidateId: selected.id,
                track: track,
                pinnedOffline: true
            )
            persist()
            return true
        }
        return false
    }

    func pinCandidateForOffline(_ candidate: LrclibCandidate, source: LyricsSource, for track: CleanedTrack) {
        data.cache[track.trackKey] = makeCacheRecord(
            source: source,
            rawSyncedLyrics: candidate.syncedLyrics,
            rawPlainLyrics: candidate.plainLyrics,
            candidateId: candidate.id,
            track: track,
            pinnedOffline: true
        )
        persist()
    }

    /// Background prefetch for downloaded/offline tracks: promotes existing cache or downloads from LRCLIB and pins permanently.
    func prefetchForOffline(track: CleanedTrack) async -> ResolvedLyrics? {
        if let hit = findCachedRecord(for: track) {
            if hit.record.pinnedOffline != true {
                _ = pinExistingForOffline(track: track)
            }
            return buildResolved(from: hit.record, duration: track.duration)
        }
        return try? await resolve(track: track, nativeFallback: nil, bypassCache: false, pinOffline: true)
    }

    func buildResolved(from candidate: LrclibCandidate, duration: Int, candidates: [LrclibCandidate]) -> ResolvedLyrics? {
        if let synced = candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !synced.isEmpty {
            let parsed = LrcParser.parseLrc(synced, trackDuration: Double(duration > 0 ? duration : Int(candidate.duration)))
            return ResolvedLyrics(
                source: parsed.mode == "synced" ? .lrclibSynced : .lrclibPlain,
                parsed: parsed,
                candidateId: candidate.id,
                candidates: candidates
            )
        }
        if let plain = candidate.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !plain.isEmpty {
            return ResolvedLyrics(
                source: .lrclibPlain,
                parsed: LrcParser.parsePlainLyrics(plain),
                candidateId: candidate.id,
                candidates: candidates
            )
        }
        return nil
    }

    private func buildResolved(from cached: CachedLyricsRecord, duration: Int) -> ResolvedLyrics? {
        let effectiveDur = duration > 0 ? duration : (cached.duration ?? 0)
        if cached.source == .lrclibSynced, let rawSynced = cached.rawSyncedLyrics {
            return ResolvedLyrics(
                source: .lrclibSynced,
                parsed: LrcParser.parseLrc(rawSynced, trackDuration: Double(effectiveDur)),
                candidateId: cached.candidateId,
                candidates: []
            )
        }
        if let rawPlain = cached.rawPlainLyrics {
            return ResolvedLyrics(
                source: cached.source,
                parsed: LrcParser.parsePlainLyrics(rawPlain),
                candidateId: cached.candidateId,
                candidates: []
            )
        }
        return nil
    }

    /// 3-tier resilient lookup so downloaded/offline tracks match even if YTM alters videoId or artist metadata offline:
    /// 1) Exact trackKey -> 2) videoId -> 3) normalized artistSlug + titleSlug (or titleSlug + duration).
    func findCachedRecord(for track: CleanedTrack) -> (key: String, record: CachedLyricsRecord)? {
        if let exact = data.cache[track.trackKey] {
            return (track.trackKey, exact)
        }

        let targetVideoId = track.raw.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !targetVideoId.isEmpty {
            var bestIdMatch: (String, CachedLyricsRecord)? = nil
            for (k, rec) in data.cache where rec.videoId == targetVideoId {
                if rec.pinnedOffline == true {
                    return (k, rec)
                }
                if bestIdMatch == nil || rec.source == .lrclibSynced {
                    bestIdMatch = (k, rec)
                }
            }
            if let hit = bestIdMatch {
                return hit
            }
        }

        let targetTitle = MetadataNormalizer.slugify(track.title)
        let targetArtist = MetadataNormalizer.slugify(track.artist)
        guard !targetTitle.isEmpty else { return nil }

        var bestMetaMatch: (key: String, record: CachedLyricsRecord, score: Int)? = nil
        for (k, rec) in data.cache {
            let recTitle = rec.titleSlug ?? extractSlugFromKey(k, part: 2)
            guard !recTitle.isEmpty, recTitle == targetTitle else { continue }

            let recArtist = rec.artistSlug ?? extractSlugFromKey(k, part: 1)
            var matchScore = 0
            if !targetArtist.isEmpty && !recArtist.isEmpty {
                if recArtist == targetArtist {
                    matchScore = 100
                } else if recArtist.contains(targetArtist) || targetArtist.contains(recArtist) {
                    matchScore = 80
                } else {
                    continue
                }
            } else {
                // One side missing artist (common in album rows): verify duration if available
                let recDur = rec.duration ?? 0
                if track.duration > 0 && recDur > 0 && abs(track.duration - recDur) > 8 {
                    continue
                }
                matchScore = 60
            }

            if rec.pinnedOffline == true { matchScore += 20 }
            if rec.source == .lrclibSynced { matchScore += 10 }

            if bestMetaMatch == nil || matchScore > bestMetaMatch!.score {
                bestMetaMatch = (k, rec, matchScore)
            }
        }

        if let hit = bestMetaMatch {
            return (hit.key, hit.record)
        }
        return nil
    }

    private func extractSlugFromKey(_ key: String, part: Int) -> String {
        let comps = key.components(separatedBy: "::")
        if key.hasPrefix("ytm:"), comps.count >= 3 {
            return part == 1 ? comps[1] : comps[2]
        }
        if key.hasPrefix("meta:"), comps.count >= 2 {
            let artistPart = comps[0].replacingOccurrences(of: "meta:", with: "")
            return part == 1 ? artistPart : comps[1]
        }
        return ""
    }

    func resolve(
        track: CleanedTrack,
        nativeFallback: String?,
        bypassCache: Bool = false,
        pinOffline: Bool = false
    ) async throws -> ResolvedLyrics? {
        if !bypassCache {
            if let selected = data.overrides[track.trackKey]?.selectedCandidate,
               let resolved = buildResolved(from: selected, duration: track.duration, candidates: [selected])
            {
                if pinOffline {
                    _ = pinExistingForOffline(track: track)
                }
                return resolved
            }

            if let hit = findCachedRecord(for: track) {
                var updated = hit.record
                updated.lastAccessedAt = Date().timeIntervalSince1970
                if pinOffline {
                    updated.pinnedOffline = true
                }
                data.cache[hit.key] = updated
                persist()

                if let resolved = buildResolved(from: updated, duration: track.duration) {
                    return resolved
                }
            }
        }

        do {
            // 1. LRCLIB exact lookup
            let exact = try await fetchExact(track: track)
            if let exact, !(exact.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
               let resolved = buildResolved(from: exact, duration: track.duration, candidates: [exact])
            {
                cacheCandidate(exact, source: resolved.source, for: track, pinOffline: pinOffline)
                return resolved
            }

            // 2. LRCLIB fuzzy search + duration/sync ranking
            let primaryQuery = [track.artist, track.title].filter { !$0.isEmpty }.joined(separator: " ")
            var searchResults = try await search(query: primaryQuery)
            if searchResults.isEmpty && !track.artist.isEmpty && !track.title.isEmpty {
                searchResults = try await search(query: track.title)
            }

            var combined = searchResults
            if let exact { combined.insert(exact, at: 0) }
            let ranked = rankCandidates(combined, for: track)

            if let best = ranked.first,
               let resolved = buildResolved(from: best, duration: track.duration, candidates: ranked)
            {
                cacheCandidate(best, source: resolved.source, for: track, pinOffline: pinOffline)
                return resolved
            }

            // 3. Fallback to YouTube Music native page lyrics
            if let native = nativeFallback?.trimmingCharacters(in: .whitespacesAndNewlines), !native.isEmpty {
                let parsed = LrcParser.parsePlainLyrics(native)
                if !parsed.plainLines.isEmpty {
                    data.cache[track.trackKey] = makeCacheRecord(
                        source: .ytmNative,
                        rawSyncedLyrics: nil,
                        rawPlainLyrics: native,
                        candidateId: nil,
                        track: track,
                        pinnedOffline: pinOffline
                    )
                    pruneCacheIfNeeded()
                    persist()
                    return ResolvedLyrics(source: .ytmNative, parsed: parsed, candidateId: nil, candidates: ranked)
                }
            }

            return nil
        } catch let urlErr as URLError where
            urlErr.code == .notConnectedToInternet ||
            urlErr.code == .networkConnectionLost ||
            urlErr.code == .dataNotAllowed
        {
            // Fallback to native page lyrics even if offline
            if let native = nativeFallback?.trimmingCharacters(in: .whitespacesAndNewlines), !native.isEmpty {
                let parsed = LrcParser.parsePlainLyrics(native)
                if !parsed.plainLines.isEmpty {
                    return ResolvedLyrics(source: .ytmNative, parsed: parsed, candidateId: nil, candidates: [])
                }
            }
            throw NSError(domain: "LyricsService", code: urlErr.errorCode, userInfo: [
                NSLocalizedDescriptionKey: "You are offline and this track's lyrics haven't been downloaded yet. Open Downloads while online to sync.",
            ])
        }
    }

    func searchCandidates(query: String, for track: CleanedTrack) async throws -> [LrclibCandidate] {
        let raw = try await search(query: query)
        return rankCandidates(raw, for: track)
    }

    private func fetchExact(track: CleanedTrack) async throws -> LrclibCandidate? {
        guard !track.title.isEmpty && !track.artist.isEmpty else { return nil }
        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        var items = [
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "track_name", value: track.title),
        ]
        if let album = track.album, !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if track.duration > 0 {
            items.append(URLQueryItem(name: "duration", value: String(track.duration)))
        }
        comps.queryItems = items

        guard let url = comps.url else { return nil }
        let (respData, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "LyricsService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "LRCLIB request failed (HTTP \(http.statusCode))",
            ])
        }
        return try? JSONDecoder().decode(LrclibCandidate.self, from: respData)
    }

    private func search(query: String) async throws -> [LrclibCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var comps = URLComponents(string: "https://lrclib.net/api/search")!
        comps.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        guard let url = comps.url else { return [] }

        let (respData, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { return [] }
        if http.statusCode == 404 { return [] }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "LyricsService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "LRCLIB search failed (HTTP \(http.statusCode))",
            ])
        }
        return (try? JSONDecoder().decode([LrclibCandidate].self, from: respData)) ?? []
    }

    private func tokenOverlap(_ expected: String, _ actual: String) -> Double {
        let eSet = Set(MetadataNormalizer.slugify(expected).split(separator: " ").map(String.init))
        let aSet = Set(MetadataNormalizer.slugify(actual).split(separator: " ").map(String.init))
        guard !eSet.isEmpty && !aSet.isEmpty else { return 0 }
        let matches = eSet.intersection(aSet).count
        return Double(matches) / Double(max(eSet.count, aSet.count))
    }

    private func scoreCandidate(_ candidate: LrclibCandidate, for track: CleanedTrack) -> Double {
        var score = 0.0
        let synced = candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let plain = candidate.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let syncedRange = NSRange(synced.startIndex..<synced.endIndex, in: synced)
        let hasWordTags = (candidate.hasWordSync == true) ||
            (!synced.isEmpty && Self.wordTagHintRegex.firstMatch(in: synced, options: [], range: syncedRange) != nil)

        if !synced.isEmpty {
            score += 110
            if hasWordTags { score += 20 }
        } else if !plain.isEmpty {
            score += 25
        } else if candidate.instrumental {
            score -= 90
        } else {
            score -= 100
        }

        if track.duration > 0 && candidate.duration > 0 {
            let delta = abs(candidate.duration - Double(track.duration))
            if delta <= 2 { score += 65 }
            else if delta <= 5 { score += 48 }
            else if delta <= 10 { score += 26 }
            else if delta <= 20 { score += 8 }
            else { score -= min(75, (delta - 18) * 1.6) }
        }

        score += tokenOverlap(track.title, candidate.trackName) * 45
        if !track.artist.isEmpty {
            score += tokenOverlap(track.artist, candidate.artistName) * 30
        }
        return score
    }

    func rankCandidates(_ candidates: [LrclibCandidate], for track: CleanedTrack) -> [LrclibCandidate] {
        var seen = Set<Int>()
        var unique: [LrclibCandidate] = []
        for c in candidates {
            if seen.insert(c.id).inserted {
                let hasSynced = !(c.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                let hasPlain = !(c.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                if hasSynced || hasPlain {
                    unique.append(c)
                }
            }
        }
        return unique.sorted { scoreCandidate($0, for: track) > scoreCandidate($1, for: track) }
    }

    private func makeCacheRecord(
        source: LyricsSource,
        rawSyncedLyrics: String?,
        rawPlainLyrics: String?,
        candidateId: Int?,
        track: CleanedTrack,
        pinnedOffline: Bool
    ) -> CachedLyricsRecord {
        let vid = track.raw.id.trimmingCharacters(in: .whitespacesAndNewlines)
        return CachedLyricsRecord(
            source: source,
            rawSyncedLyrics: rawSyncedLyrics,
            rawPlainLyrics: rawPlainLyrics,
            candidateId: candidateId,
            lastAccessedAt: Date().timeIntervalSince1970,
            pinnedOffline: pinnedOffline ? true : nil,
            videoId: vid.isEmpty ? nil : vid,
            artistSlug: MetadataNormalizer.slugify(track.artist),
            titleSlug: MetadataNormalizer.slugify(track.title),
            duration: track.duration > 0 ? track.duration : nil,
            savedTitle: track.title,
            savedArtist: track.artist
        )
    }

    private func cacheCandidate(_ candidate: LrclibCandidate, source: LyricsSource, for track: CleanedTrack, pinOffline: Bool) {
        let wasPinned = (data.cache[track.trackKey]?.pinnedOffline == true) || pinOffline
        data.cache[track.trackKey] = makeCacheRecord(
            source: source,
            rawSyncedLyrics: candidate.syncedLyrics,
            rawPlainLyrics: candidate.plainLyrics,
            candidateId: candidate.id,
            track: track,
            pinnedOffline: wasPinned
        )
        pruneCacheIfNeeded()
        persist()
    }

    private func pruneCacheIfNeeded() {
        // Never prune permanently pinned offline lyrics!
        let ephemeralKeys = data.cache.keys.filter { data.cache[$0]?.pinnedOffline != true }
        guard ephemeralKeys.count > maxCacheEntries else { return }
        let sortedKeys = ephemeralKeys.sorted {
            (data.cache[$0]?.lastAccessedAt ?? 0) < (data.cache[$1]?.lastAccessedAt ?? 0)
        }
        for key in sortedKeys.prefix(ephemeralKeys.count - maxCacheEntries) {
            data.cache.removeValue(forKey: key)
        }
    }

    private func pruneOverridesIfNeeded() {
        guard data.overrides.count > maxOverrideEntries else { return }
        let sortedKeys = data.overrides.keys.sorted {
            (data.overrides[$0]?.updatedAt ?? 0) < (data.overrides[$1]?.updatedAt ?? 0)
        }
        for key in sortedKeys.prefix(data.overrides.count - maxOverrideEntries) {
            data.overrides.removeValue(forKey: key)
        }
    }
}
