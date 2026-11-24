import AppKit
import SwiftUI

final class MiniPlayerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
    }
}

@MainActor
final class MiniPlayerWindowController: NSObject, NSWindowDelegate {
    let panel: MiniPlayerPanel
    private let store: AppStore
    private static let frameKey = "mini_player_frame"

    init(store: AppStore, onShowMainWindow: @escaping () -> Void) {
        self.store = store
        let initialRect = Self.loadFrame() ?? Self.defaultFrame()
        self.panel = MiniPlayerPanel(contentRect: initialRect)
        super.init()

        self.panel.delegate = self

        let hosting = NSHostingView(
            rootView: MiniPlayerContentView(store: store, onShowMainWindow: onShowMainWindow)
        )
        if #available(macOS 13.3, *) {
            hosting.safeAreaRegions = []
        }
        hosting.sizingOptions = []
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        self.panel.contentView = hosting

        store.onMiniPlayerVisibilityChanged = { [weak self] visible in
            if visible {
                self?.panel.orderFrontRegardless()
            } else {
                self?.panel.orderOut(nil)
            }
        }
    }

    func show() {
        store.isMiniPlayerVisible = true
        panel.orderFrontRegardless()
    }

    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.frameKey)
        panel.setFrame(Self.defaultFrame(), display: true, animate: true)
    }

    func windowDidMove(_ notification: Notification) {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: Self.frameKey)
    }

    private static func loadFrame() -> NSRect? {
        guard let str = UserDefaults.standard.string(forKey: frameKey) else { return nil }
        let rect = NSRectFromString(str)
        guard rect.width >= 300, rect.height >= 100 else { return nil }
        return NSRect(x: rect.origin.x, y: rect.origin.y, width: 356, height: 136)
    }

    private static func defaultFrame() -> NSRect {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w: CGFloat = 356
        let h: CGFloat = 136
        return NSRect(x: visible.maxX - w - 24, y: visible.minY + 28, width: w, height: h)
    }
}

struct MiniPlayerContentView: View {
    @ObservedObject var store: AppStore
    let onShowMainWindow: () -> Void

    private var activeLyricIndex: Int {
        store.frame.activeLineIndex
    }

    private var activeLine: LyricLine? {
        guard store.status == .synced,
              let lines = store.resolvedLyrics?.parsed.lines,
              activeLyricIndex >= 0,
              activeLyricIndex < lines.count
        else { return nil }
        let line = lines[activeLyricIndex]
        return line.isInstrumental ? nil : line
    }

    private var activeRomaji: String? {
        guard activeLyricIndex >= 0 else { return nil }
        return store.romanizedText(at: activeLyricIndex)
    }

    private var activeTranslation: String? {
        guard activeLyricIndex >= 0 else { return nil }
        return store.translatedText(at: activeLyricIndex)
    }

    var body: some View {
        ZStack {
            // Obsidian Liquid Glass shell matching the app's unified visual language
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .opacity(0.82)

                Color(red: 0.068, green: 0.068, blue: 0.098).opacity(0.86)

                RadialGradient(
                    colors: [
                        store.palette.accentColor.opacity(0.14),
                        Color.clear,
                    ],
                    center: .topLeading,
                    startRadius: 8,
                    endRadius: 210
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.55), value: store.palette)

            // Drag handle covers background so dragging anywhere moves the Mini Player
            WindowDragHandle()

            VStack(spacing: 8) {
                // Row 1: Artwork + Track Info + Compact Playback & Window Controls
                HStack(spacing: 10) {
                    Button(action: onShowMainWindow) {
                        Group {
                            if let art = store.artworkImage {
                                Image(nsImage: art)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(Color.white.opacity(0.07))
                                    Image(systemName: "music.note")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.38), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .help("Show Main YT Music Glass Window")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.track?.title ?? "YT Music Glass")
                            .font(AppFont.styled(13.5, weight: .bold, style: store.fontStyle))
                            .foregroundStyle(.white.opacity(0.96))
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            if store.audioVisualizerEnabled && store.track != nil {
                                MiniAudioVisualizerView(
                                    phase: store.visualizerPhase,
                                    isPlaying: !store.playback.paused && !store.playback.isAdPlaying,
                                    accentColor: store.palette.accentColor,
                                    barCount: 4,
                                    maxHeight: 11,
                                    barWidth: 2,
                                    spacing: 1.5
                                )
                            }
                            Text(store.track?.artist ?? "Play a song to start")
                                .font(AppFont.styled(11.5, weight: .regular, style: store.fontStyle))
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)
                        }
                    }
                    .allowsHitTesting(false)

                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        miniCircleButton("backward.fill", size: 26, iconSize: 10, help: "Previous Track") {
                            store.prevTrack()
                        }

                        Button {
                            store.togglePlay()
                        } label: {
                            Image(systemName: store.playback.paused ? "play.fill" : "pause.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(store.palette.accentColor.opacity(0.24))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().strokeBorder(store.palette.accentColor.opacity(0.48), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Play / Pause")

                        miniCircleButton("forward.fill", size: 26, iconSize: 10, help: "Next Track") {
                            store.nextTrack()
                        }
                    }

                    VStack(spacing: 4) {
                        miniCircleButton("xmark", size: 19, iconSize: 8, help: "Close Mini Player (⇧⌘P)") {
                            store.isMiniPlayerVisible = false
                        }
                        miniCircleButton("arrow.up.left.and.arrow.down.right", size: 19, iconSize: 8, help: "Open Main Window") {
                            onShowMainWindow()
                        }
                    }
                }

                // Row 2: Live 1-line karaoke lyric strip (+ subtle translation line when active)
                VStack(alignment: .leading, spacing: 2) {
                    if store.frame.instrumentalActive {
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { idx in
                                let lit = store.frame.instrumentalProgress >= (Double(idx) + 0.15) / 3.0
                                Circle()
                                    .fill(lit ? Color.white : Color.white.opacity(0.32))
                                    .frame(width: lit ? 6.5 : 5.5, height: lit ? 6.5 : 5.5)
                            }
                            Spacer()
                        }
                        .frame(height: 18)
                    } else if let line = activeLine {
                        let heroText = activeRomaji ?? line.text
                        miniProgressiveText(heroText, progress: store.frame.lineProgress)
                            .font(AppFont.styled(13.5, weight: .bold, style: store.fontStyle))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let translated = activeTranslation, !translated.isEmpty {
                            Text(translated)
                                .font(AppFont.styled(10.5, weight: .regular, style: store.fontStyle))
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text(store.status == .loading ? "Finding synced lyrics..." : "Live lyrics appear here while playing")
                            .font(AppFont.styled(11.5, weight: .regular, style: store.fontStyle))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .allowsHitTesting(false)

                // Row 3: Interactive Spotify-style mini progress bar with elapsed/duration
                HStack(spacing: 8) {
                    Text(formatTime(store.playback.duration * store.playbackProgress))
                        .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.50))
                        .frame(minWidth: 28, alignment: .trailing)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.20))
                                .frame(height: 4)
                            Capsule()
                                .fill(store.palette.accentColor)
                                .frame(width: max(0, geo.size.width * store.playbackProgress), height: 4)
                        }
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard geo.size.width > 0, store.playback.duration > 0 else { return }
                                    let ratio = SyncCalculator.clamp(value.location.x / geo.size.width, min: 0, max: 1)
                                    store.seekToRawTime(ratio * store.playback.duration)
                                }
                        )
                    }
                    .frame(height: 12)

                    Text(formatTime(store.playback.duration))
                        .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.50))
                        .frame(minWidth: 28, alignment: .leading)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
        }
        .frame(width: 356, height: 136)
    }

    private func miniProgressiveText(_ text: String, progress: Double) -> Text {
        let rawParts = text.split(separator: " ", omittingEmptySubsequences: false)
        guard rawParts.count >= 2 else {
            return Text(text).foregroundColor(.white)
        }
        let tokens: [String] = rawParts.enumerated().map { idx, part in
            idx < rawParts.count - 1 ? String(part) + " " : String(part)
        }
        let totalWeight = Double(max(1, tokens.reduce(0) { $0 + max(1, $1.count) }))
        let litBudget = max(0.0, min(1.0, progress)) * totalWeight

        var cursor = 0.0
        var combined = Text("")
        for token in tokens {
            let w = Double(max(1, token.count))
            let opacity: Double
            if litBudget >= cursor + w * 0.72 {
                opacity = 1.0
            } else if litBudget >= cursor + w * 0.35 {
                opacity = 0.86
            } else {
                opacity = 0.42
            }
            combined = combined + Text(token).foregroundColor(.white.opacity(opacity))
            cursor += w
        }
        return combined
    }

    private func miniCircleButton(
        _ symbol: String,
        size: CGFloat,
        iconSize: CGFloat,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.07))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
