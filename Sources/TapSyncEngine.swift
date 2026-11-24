import Foundation

struct TapSyncLine: Equatable, Identifiable {
    let id: Int
    let text: String
    var timestamp: Double?
}

/// Pure state machine for live Tap-to-Sync creation of synced `[mm:ss.xx]` LRC from plain lyrics.
struct TapSyncSession: Equatable {
    let trackKey: String
    private(set) var lines: [TapSyncLine]
    private(set) var currentIndex: Int = 0

    init(trackKey: String, plainLines: [String]) {
        self.trackKey = trackKey
        let cleaned = plainLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.lines = cleaned.enumerated().map { idx, text in
            TapSyncLine(id: idx, text: text, timestamp: nil)
        }
    }

    var totalCount: Int {
        lines.count
    }

    var tappedCount: Int {
        lines.filter { $0.timestamp != nil }.count
    }

    var isComplete: Bool {
        !lines.isEmpty && currentIndex >= lines.count
    }

    mutating func tapNext(at rawSeconds: Double) {
        guard currentIndex < lines.count else { return }
        var timestamp = max(0, rawSeconds.isFinite ? rawSeconds : 0)
        if currentIndex > 0, let prevTime = lines[currentIndex - 1].timestamp {
            timestamp = max(prevTime + 0.05, timestamp)
        }
        lines[currentIndex].timestamp = timestamp
        currentIndex += 1
    }

    mutating func undoLastTap() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        lines[currentIndex].timestamp = nil
    }

    mutating func jumpToLine(index: Int) {
        guard index >= 0, index < lines.count else { return }
        for i in index..<lines.count {
            lines[i].timestamp = nil
        }
        currentIndex = index
    }

    func exportLrc() -> String? {
        let tagged: [String] = lines.compactMap { line in
            guard let ts = line.timestamp else { return nil }
            return "\(Self.formatLrcTimestamp(ts)) \(line.text)"
        }
        guard !tagged.isEmpty else { return nil }
        return tagged.joined(separator: "\n")
    }

    func exportPlainText() -> String {
        lines.map(\.text).joined(separator: "\n")
    }

    static func formatLrcTimestamp(_ seconds: Double) -> String {
        let clamped = max(0, seconds.isFinite ? seconds : 0)
        let totalCentiseconds = Int((clamped * 100.0).rounded())
        let mins = totalCentiseconds / 6000
        let secs = (totalCentiseconds % 6000) / 100
        let cs = totalCentiseconds % 100
        return String(format: "[%02d:%02d.%02d]", mins, secs, cs)
    }
}
