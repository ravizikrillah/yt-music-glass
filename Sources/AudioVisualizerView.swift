import SwiftUI

/// Smooth 5-bar Obsidian Glass audio visualizer synced to playback cadence (zero WebAudio CORS risk).
struct MiniAudioVisualizerView: View {
    let phase: Double
    let isPlaying: Bool
    let accentColor: Color
    var barCount: Int = 5
    var maxHeight: CGFloat = 14
    var barWidth: CGFloat = 2.5
    var spacing: CGFloat = 2

    private static let freqWeights: [(speed: Double, offset: Double, amp: Double)] = [
        (5.4, 0.0, 0.88),
        (7.1, 1.3, 1.00),
        (6.2, 2.7, 0.94),
        (8.3, 0.9, 0.85),
        (4.9, 3.8, 0.78),
    ]

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { idx in
                let h = heightForBar(idx)
                Capsule()
                    .fill(isPlaying ? accentColor.opacity(0.92) : Color.white.opacity(0.28))
                    .frame(width: barWidth, height: h)
            }
        }
        .frame(height: maxHeight)
        .animation(.easeOut(duration: 0.14), value: isPlaying)
    }

    private func heightForBar(_ index: Int) -> CGFloat {
        let minH: CGFloat = 3.0
        guard isPlaying else { return minH }
        let profile = Self.freqWeights[index % Self.freqWeights.count]
        let wave1 = sin(phase * profile.speed + profile.offset)
        let wave2 = cos(phase * (profile.speed * 0.63) + profile.offset * 1.7)
        let normalized = max(0.0, min(1.0, (wave1 * 0.55 + wave2 * 0.45 + 1.0) * 0.5))
        let curved = pow(normalized, 1.25) * profile.amp
        return minH + CGFloat(curved) * (maxHeight - minH)
    }
}
