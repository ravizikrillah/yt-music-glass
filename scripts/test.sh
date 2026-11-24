#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BIN="/tmp/yt_music_glass_swift_tests"
TMP_TEST="/tmp/yt_music_glass_swift_tests.swift"

cat > "${TMP_TEST}" <<'SWIFT'
import Foundation

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
    if actual != expected {
        fputs("FAIL [\(label)]: expected \(expected), got \(actual)\n", stderr)
        exit(1)
    }
}

func assertTrue(_ cond: Bool, _ label: String) {
    if !cond {
        fputs("FAIL [\(label)]\n", stderr)
        exit(1)
    }
}

@main
enum SwiftCoreTests {
    static func main() {
        // 1. Metadata normalizer (YouTube Music & YouTube label channels)
        let r1 = MetadataNormalizer.extractArtistAndTitle(rawTitle: "NOAH - Separuh Aku (Official Music Video)", rawArtist: "Musica Studios")
        assertEqual(r1.artist, "NOAH", "yt label artist")
        assertEqual(r1.title, "Separuh Aku", "yt label title")

        let r2 = MetadataNormalizer.extractArtistAndTitle(rawTitle: "Bohemian Rhapsody - Queen (Official Video)", rawArtist: "Queen Official")
        assertEqual(r2.artist, "Queen", "reversed title-artist")
        assertEqual(r2.title, "Bohemian Rhapsody", "reversed title")

        let r3 = MetadataNormalizer.extractArtistAndTitle(rawTitle: "Hati-Hati di Jalan (Lirik Lagu)", rawArtist: "Tulus - Topic")
        assertEqual(r3.artist, "Tulus", "topic artist")
        assertEqual(r3.title, "Hati-Hati di Jalan", "lirik lagu cleaned")

        // Collision-resistant track keys
        let k1 = MetadataNormalizer.computeTrackKey(TrackInfo(id: "sameId", title: "Song One", artist: "Artist A", album: nil, duration: 200, artworkUrl: nil))
        let k2 = MetadataNormalizer.computeTrackKey(TrackInfo(id: "sameId", title: "Song Two", artist: "Artist B", album: nil, duration: 210, artworkUrl: nil))
        assertTrue(k1 != k2, "different songs with stale id produce distinct keys")

        // 2. LRC + Enhanced LRC parser
        let lrc = """
        [offset:500]
        [00:05.50] <00:05.50>Hello <00:06.10>karaoke <00:06.90>world
        [00:10.50][00:30.50] Chorus line
        [00:15.50]
        [00:22.50] After bridge
        """
        let parsed = LrcParser.parseLrc(lrc, trackDuration: 120)
        assertEqual(parsed.mode, "synced", "parsed synced mode")
        assertTrue(parsed.hasWordSync, "detected word sync")
        assertEqual(parsed.lines.count, 5, "expanded multi-timestamp lines")
        assertTrue(abs(parsed.lines[0].startTime - 5.0) < 0.01, "offset tag applied")
        assertEqual(parsed.lines[0].words?.count ?? 0, 3, "three timed words")

        // 3. Sync frame + intro dots + word progress + inverse seek math
        let introFrame = SyncCalculator.computeFrame(parsed: parsed, currentTime: 2.0, offsetMs: 0)
        assertTrue(introFrame.instrumentalActive, "intro dots active before 5s")
        assertEqual(introFrame.nextVocalLineIndex, 0, "next vocal is line 0")

        let wordFrame = SyncCalculator.computeFrame(parsed: parsed, currentTime: 6.0, offsetMs: 0)
        assertEqual(wordFrame.activeLineIndex, 0, "active line 0")
        assertEqual(wordFrame.activeWordIndex, 1, "active word 1 (karaoke)")

        let breakFrame = SyncCalculator.computeFrame(parsed: parsed, currentTime: 18.0, offsetMs: 0)
        assertTrue(breakFrame.instrumentalActive, "mid-song break dots active")
        assertEqual(breakFrame.nextVocalLineIndex, 3, "next vocal after bridge")

        let seekTarget = SyncCalculator.computeSeekTarget(lineStartTime: 10.0, offsetMs: 1000, duration: 200)
        assertTrue(abs(seekTarget - 9.0) < 0.01, "inverse offset seek math")

        // 4. Auto-Romanization (Korean Revised Romanization, Japanese Kanji Romaji, Latin skip)
        let ko1 = Romanizer.romanizeLine("But you DM me, \"니가 궁금해서\"") ?? ""
        assertEqual(ko1, "But you DM me, \"niga gunggeumhaeseo\"", "korean mixed line 1")

        let ko2 = Romanizer.romanizeLine("널 부를래, baby") ?? ""
        assertEqual(ko2, "neol bureullae, baby", "korean liquid assimilation")

        let ko3 = Romanizer.romanizeLine("사실은 너도 알잖아, 뜨거운 계절 속에") ?? ""
        assertTrue(ko3.contains("sasireun") && ko3.contains("aljana") && ko3.contains("soge"), "korean liaison & h-silent: \(ko3)")

        let ja1 = Romanizer.romanizeLine("君のことが好きだよ") ?? ""
        assertTrue(ja1.contains("kimi") && ja1.contains("suki"), "japanese kanji romaji: \(ja1)")

        assertEqual(Romanizer.romanizeLine("Like unbothered, don't fade"), nil, "pure latin returns nil")
        assertEqual(Romanizer.romanizeLine("Dan terjadi lagi kisah lama"), nil, "indonesian returns nil")

        // 5. Smart Language Detection & Same-Language Auto-Skip
        let (idLang, _) = TranslationService.detectSongLanguage(lines: [
            "Dan terjadi lagi kisah lama yang terulang kembali",
            "Kau terluka lagi dari cinta rumit yang kau jalani",
            "Aku ingin kau merasa kamu mengerti aku mengerti kamu",
        ])
        assertEqual(idLang, "id", "detect indonesian song")
        assertEqual(TranslationService.shouldTranslateSong(detectedLang: idLang, source: .auto, target: .indonesian), false, "skip indo->indo")
        assertEqual(TranslationService.shouldTranslateSong(detectedLang: idLang, source: .auto, target: .english), true, "allow indo->en")

        let (enLang, _) = TranslationService.detectSongLanguage(lines: [
            "Tell me that I'm special, tell me I look pretty",
            "Tell me I'm a little angel, sweetheart of your city",
            "Say what I'm dying to hear, cause I'm dying to hear you",
        ])
        assertEqual(enLang, "en", "detect english song")
        assertEqual(TranslationService.shouldTranslateSong(detectedLang: enLang, source: .auto, target: .indonesian), true, "allow en->id")
        assertEqual(TranslationService.shouldTranslateSong(detectedLang: enLang, source: .auto, target: .english), false, "skip en->en")

        let (koLang, koScript) = TranslationService.detectSongLanguage(lines: [
            "Like unbothered, don't fade, don't fade",
            "But you DM me, \"니가 궁금해서\"",
            "사실은 너도 알잖아, 뜨거운 계절 속에",
        ])
        assertEqual(koLang, "ko", "detect mixed kpop as ko")
        assertEqual(koScript, .korean, "detect mixed kpop script hint")
        assertEqual(TranslationService.shouldTranslateSong(detectedLang: koLang, source: .auto, target: .indonesian), true, "allow ko->id")
        assertEqual(TranslationService.shouldTranslateSong(detectedLang: koLang, source: .auto, target: .english), true, "allow ko->en")

        // 6. Offline Karaoke Vault: permanent pinning, clearCache preservation, 3-tier offline matching
        let tempDir = FileManager.default.temporaryDirectory
        let tmpLyricsURL = tempDir.appendingPathComponent("ytmg_test_offline_lyrics_\(UUID().uuidString).json")
        let tmpTransURL = tempDir.appendingPathComponent("ytmg_test_offline_trans_\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: tmpLyricsURL)
            try? FileManager.default.removeItem(at: tmpTransURL)
        }

        let offlineLyrics = LyricsService(storeURL: tmpLyricsURL)
        let downloadedTrack = MetadataNormalizer.normalize(TrackInfo(
            id: "abc123XYZ89",
            title: "The Chase",
            artist: "Hearts2Hearts",
            album: "The Chase",
            duration: 179,
            artworkUrl: nil
        ))
        let sampleCandidate = LrclibCandidate(
            id: 9991,
            trackName: "The Chase",
            artistName: "Hearts2Hearts",
            duration: 179,
            syncedLyrics: "[00:05.00] I love the way you love the chase\n[00:10.00] 온통 수수께끼 난 더 알고 싶어"
        )
        offlineLyrics.pinCandidateForOffline(sampleCandidate, source: .lrclibSynced, for: downloadedTrack)
        assertEqual(offlineLyrics.offlineCount(), 1, "offline vault has 1 pinned track")
        assertTrue(offlineLyrics.hasOfflineLyrics(for: downloadedTrack), "exact offline track hit")

        // Clearing temp cache MUST preserve pinned offline lyrics
        offlineLyrics.clearCache()
        assertEqual(offlineLyrics.offlineCount(), 1, "clearCache preserves offline vault")

        // Tier 2 offline lookup: same videoId even if offline artist metadata differs slightly
        let alteredArtistTrack = MetadataNormalizer.normalize(TrackInfo(
            id: "abc123XYZ89",
            title: "The Chase",
            artist: "Hearts2Hearts • The Chase",
            album: nil,
            duration: 179,
            artworkUrl: nil
        ))
        assertTrue(offlineLyrics.hasOfflineLyrics(for: alteredArtistTrack), "offline videoId match succeeds")

        // Tier 3 offline lookup: empty videoId (YTM offline player fallback) still hits via artist+title slug
        let noIdOfflineTrack = MetadataNormalizer.normalize(TrackInfo(
            id: "",
            title: "The Chase",
            artist: "Hearts2Hearts",
            album: nil,
            duration: 179,
            artworkUrl: nil
        ))
        assertTrue(offlineLyrics.hasOfflineLyrics(for: noIdOfflineTrack), "offline artist+title slug match succeeds without videoId")

        // Reload from disk to verify offline persistence across app restarts
        let reloadedLyrics = LyricsService(storeURL: tmpLyricsURL)
        assertEqual(reloadedLyrics.offlineCount(), 1, "offline vault persists to disk")
        assertTrue(reloadedLyrics.hasOfflineLyrics(for: noIdOfflineTrack), "reloaded offline vault resolves without network")

        // Offline translation pinning + metaKey lookup without videoId
        let offlineTrans = TranslationService(cacheURL: tmpTransURL)
        let metaKey = TranslationService.makeMetaKey(artist: "Hearts2Hearts", title: "The Chase", source: .auto, target: .indonesian)
        offlineTrans.saveOfflineTranslationForTesting(
            trackKey: downloadedTrack.trackKey,
            metaKey: metaKey,
            detectedLang: "ko",
            lines: ["Aku suka caramu menyukai pengejaran", "Ini semua misteri, aku ingin tahu lebih banyak"],
            source: .auto,
            target: .indonesian
        )
        offlineTrans.clearCache() // preserves pinned offline translations
        let reloadedTrans = TranslationService(cacheURL: tmpTransURL)
        let transHit = reloadedTrans.lookupCachedTranslation(
            trackKey: noIdOfflineTrack.trackKey,
            metaKey: metaKey,
            lineCount: 2,
            source: .auto,
            target: .indonesian
        )
        assertTrue(transHit != nil, "offline translation hits via metaKey after restart & clearCache")
        assertEqual(transHit?.record.lines[1], "Ini semua misteri, aku ingin tahu lebih banyak", "offline translation line preserved")

        // 7. SemVer Comparator (GitHub Releases Auto-Updater)
        assertEqual(SemVerComparator.isNewer("v1.0.1", than: "1.0.0"), true, "patch bump is newer")
        assertEqual(SemVerComparator.isNewer("1.2.0", than: "1.1.9"), true, "minor bump is newer")
        assertEqual(SemVerComparator.isNewer("v1.0.10", than: "1.0.2"), true, "double digit patch is newer")
        assertEqual(SemVerComparator.isNewer("v1.0.0", than: "1.0.0"), false, "same version is not newer")
        assertEqual(SemVerComparator.isNewer("0.9.9", than: "1.0.0"), false, "older version is not newer")

        // 8. Legacy Application Support auto-migration (YTMKaraoke -> YTMusicGlass)
        let migBase = tempDir.appendingPathComponent("ytmg_mig_test_\(UUID().uuidString)", isDirectory: true)
        let legacyDir = migBase.appendingPathComponent(AppIdentity.legacyAppSupportFolderName, isDirectory: true)
        try! FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        let legacyFile = legacyDir.appendingPathComponent("lyrics-store.json")
        try! Data("{\"overrides\":{},\"cache\":{}}".utf8).write(to: legacyFile)
        defer {
            try? FileManager.default.removeItem(at: migBase)
        }
        let resolvedDir = AppIdentity.appSupportDirectory(in: migBase)
        assertEqual(resolvedDir.lastPathComponent, AppIdentity.appSupportFolderName, "app support uses YTMusicGlass folder")
        assertTrue(FileManager.default.fileExists(atPath: resolvedDir.appendingPathComponent("lyrics-store.json").path), "legacy lyrics-store.json migrated")
        assertTrue(!FileManager.default.fileExists(atPath: legacyDir.path), "legacy YTMKaraoke folder moved cleanly")

        print("ALL_SWIFT_CORE_TESTS_PASSED")
    }
}
SWIFT

swiftc \
  -parse-as-library \
  -target "$(uname -m)-apple-macos14.0" \
  -framework NaturalLanguage \
  "${ROOT_DIR}/Sources/Models.swift" \
  "${ROOT_DIR}/Sources/MetadataNormalizer.swift" \
  "${ROOT_DIR}/Sources/LrcParser.swift" \
  "${ROOT_DIR}/Sources/LyricsService.swift" \
  "${ROOT_DIR}/Sources/UpdateService.swift" \
  "${ROOT_DIR}/Sources/Romanizer.swift" \
  "${ROOT_DIR}/Sources/TranslationService.swift" \
  "${TMP_TEST}" \
  -o "${TMP_BIN}"

"${TMP_BIN}"
rm -f "${TMP_BIN}" "${TMP_TEST}"
