import Foundation

struct LyricWord: Codable, Hashable {
    let startTime: Double
    var endTime: Double
    var text: String
}

struct LyricLine: Codable, Hashable {
    let startTime: Double
    var endTime: Double
    let text: String
    var words: [LyricWord]?
    let isInstrumental: Bool
}

struct ParsedLyrics: Codable, Hashable {
    let mode: String // "synced" | "plain"
    let hasWordSync: Bool
    let lines: [LyricLine]
    let plainLines: [String]
}

struct TrackInfo: Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let duration: Double
    let artworkUrl: String?
}

struct CleanedTrack: Hashable {
    let trackKey: String
    let raw: TrackInfo
    let title: String
    let artist: String
    let album: String?
    let duration: Int
}

struct PlaybackSnapshot: Codable, Hashable {
    let currentTime: Double
    let duration: Double
    let paused: Bool
    let playbackRate: Double
    let isAdPlaying: Bool
    let capturedAtMs: Double

    static let idle = PlaybackSnapshot(
        currentTime: 0,
        duration: 0,
        paused: true,
        playbackRate: 1.0,
        isAdPlaying: false,
        capturedAtMs: Date().timeIntervalSince1970 * 1000.0
    )
}

struct LrclibCandidate: Codable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double
    let instrumental: Bool
    let hasWordSync: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?

    init(
        id: Int,
        name: String? = nil,
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: Double,
        instrumental: Bool = false,
        hasWordSync: Bool? = nil,
        plainLyrics: String? = nil,
        syncedLyrics: String? = nil
    ) {
        self.id = id
        self.name = name
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.hasWordSync = hasWordSync
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int.self, forKey: .id)
        self.name = try? c.decodeIfPresent(String.self, forKey: .name)
        self.trackName = (try? c.decodeIfPresent(String.self, forKey: .trackName)) ?? ""
        self.artistName = (try? c.decodeIfPresent(String.self, forKey: .artistName)) ?? ""
        self.albumName = try? c.decodeIfPresent(String.self, forKey: .albumName)
        self.duration = (try? c.decodeIfPresent(Double.self, forKey: .duration)) ?? 0
        self.instrumental = (try? c.decodeIfPresent(Bool.self, forKey: .instrumental)) ?? false
        self.hasWordSync = try? c.decodeIfPresent(Bool.self, forKey: .hasWordSync)
        self.plainLyrics = try? c.decodeIfPresent(String.self, forKey: .plainLyrics)
        self.syncedLyrics = try? c.decodeIfPresent(String.self, forKey: .syncedLyrics)
    }
}

enum LyricsSource: String, Codable {
    case lrclibSynced = "lrclib_synced"
    case lrclibPlain = "lrclib_plain"
    case ytmNative = "ytm_native"
}

struct ResolvedLyrics {
    let source: LyricsSource
    let parsed: ParsedLyrics
    let candidateId: Int?
    let candidates: [LrclibCandidate]
}

enum SessionStatus: String {
    case idle
    case adPlaying
    case loading
    case synced
    case plainFallback
    case notFound
    case error
}

enum HudDisplayMode: String {
    case full
    case compact
}

enum WebSiteMode: String {
    case youtubeMusic = "ytm"
    case youtube = "youtube"

    var homeURL: URL {
        switch self {
        case .youtubeMusic: return URL(string: "https://music.youtube.com")!
        case .youtube: return URL(string: "https://www.youtube.com")!
        }
    }

    var label: String {
        switch self {
        case .youtubeMusic: return "YouTube Music"
        case .youtube: return "YouTube"
        }
    }
}

struct SyncFrame: Equatable {
    let effectiveTime: Double
    let activeLineIndex: Int
    let nextVocalLineIndex: Int
    let lineProgress: Double
    let activeWordIndex: Int
    let wordProgress: Double
    let instrumentalActive: Bool
    let instrumentalProgress: Double

    static let empty = SyncFrame(
        effectiveTime: 0,
        activeLineIndex: -1,
        nextVocalLineIndex: -1,
        lineProgress: 0,
        activeWordIndex: -1,
        wordProgress: 0,
        instrumentalActive: false,
        instrumentalProgress: 0
    )
}

enum SyncCalculator {
    private static let introGapMinSeconds = 4.0
    private static let breakMinSeconds = 2.8

    static func clamp(_ value: Double, min lo: Double, max hi: Double) -> Double {
        Swift.min(hi, Swift.max(lo, value))
    }

    static func computeSeekTarget(lineStartTime: Double, offsetMs: Double, duration: Double) -> Double {
        let raw = lineStartTime - offsetMs / 1000.0
        let maxTime = duration > 0 ? duration : Double.greatestFiniteMagnitude
        return clamp(raw, min: 0, max: maxTime)
    }

    static func extrapolateTime(playback: PlaybackSnapshot, nowMs: Double) -> Double {
        if playback.paused {
            return max(0, playback.currentTime)
        }
        let elapsedSec = max(0, (nowMs - playback.capturedAtMs) / 1000.0)
        let rate = playback.playbackRate > 0 ? playback.playbackRate : 1.0
        let raw = playback.currentTime + elapsedSec * rate
        if playback.duration > 0 {
            return clamp(raw, min: 0, max: playback.duration)
        }
        return max(0, raw)
    }

    private static func findNextVocalIndex(_ lines: [LyricLine], from start: Int) -> Int {
        guard start < lines.count else { return -1 }
        for i in max(0, start)..<lines.count {
            let line = lines[i]
            if !line.isInstrumental && !line.text.isEmpty {
                return i
            }
        }
        return -1
    }

    static func computeFrame(parsed: ParsedLyrics, currentTime: Double, offsetMs: Double) -> SyncFrame {
        let effectiveTime = currentTime + offsetMs / 1000.0
        guard parsed.mode == "synced", !parsed.lines.isEmpty else {
            return .empty
        }

        let lines = parsed.lines
        let firstVocalIdx = findNextVocalIndex(lines, from: 0)

        if effectiveTime < lines[0].startTime {
            let introDuration = firstVocalIdx >= 0 ? lines[firstVocalIdx].startTime : lines[0].startTime
            let showDots = introDuration >= introGapMinSeconds
            return SyncFrame(
                effectiveTime: effectiveTime,
                activeLineIndex: -1,
                nextVocalLineIndex: firstVocalIdx,
                lineProgress: 0,
                activeWordIndex: -1,
                wordProgress: 0,
                instrumentalActive: showDots,
                instrumentalProgress: showDots ? clamp(effectiveTime / introDuration, min: 0, max: 1) : 0
            )
        }

        var lo = 0
        var hi = lines.count - 1
        var idx = 0
        while lo <= hi {
            let mid = (lo + hi) >> 1
            if lines[mid].startTime <= effectiveTime {
                idx = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        let activeLine = lines[idx]
        let nextVocalIdx = findNextVocalIndex(lines, from: idx + 1)

        if activeLine.isInstrumental {
            let span = max(0.1, activeLine.endTime - activeLine.startTime)
            let showDots = span >= breakMinSeconds && nextVocalIdx >= 0
            return SyncFrame(
                effectiveTime: effectiveTime,
                activeLineIndex: -1,
                nextVocalLineIndex: nextVocalIdx,
                lineProgress: 0,
                activeWordIndex: -1,
                wordProgress: 0,
                instrumentalActive: showDots,
                instrumentalProgress: showDots ? clamp((effectiveTime - activeLine.startTime) / span, min: 0, max: 1) : 0
            )
        }

        let lineSpan = max(0.2, activeLine.endTime - activeLine.startTime)
        let lineProgress = clamp((effectiveTime - activeLine.startTime) / lineSpan, min: 0, max: 1)

        var activeWordIdx = -1
        var wordProg = 0.0

        if let words = activeLine.words, !words.isEmpty {
            for w in 0..<words.count {
                let word = words[w]
                if effectiveTime >= word.startTime {
                    activeWordIdx = w
                    let wSpan = max(0.08, word.endTime - word.startTime)
                    wordProg = clamp((effectiveTime - word.startTime) / wSpan, min: 0, max: 1)
                } else {
                    break
                }
            }
        }

        return SyncFrame(
            effectiveTime: effectiveTime,
            activeLineIndex: idx,
            nextVocalLineIndex: nextVocalIdx,
            lineProgress: lineProgress,
            activeWordIndex: activeWordIdx,
            wordProgress: wordProg,
            instrumentalActive: false,
            instrumentalProgress: 0
        )
    }
}
