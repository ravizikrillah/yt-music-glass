import AppKit
import SwiftUI

struct FullScreenLyricsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            dynamicAmbientBackground

            // Main Centered Stage
            ZStack {
                if store.isPickerOpen {
                    centeredPickerModal
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if store.isTapSyncActive {
                    TapSyncPanelView(store: store, compactLayout: false)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    lyricsCenterStage
                        .transition(.opacity)
                }

                // Top Header & Bottom Floating Dock (auto-fade when mouse is idle)
                VStack(spacing: 0) {
                    topOverlayBar
                        .padding(.horizontal, 28)
                        .padding(.top, store.isNativeWindowFullScreen ? 24 : 44)
                        .opacity(effectiveControlsVisible ? 1.0 : 0.18)
                        .offset(y: effectiveControlsVisible ? 0 : -4)

                    Spacer(minLength: 0)

                    if !store.isPickerOpen && !store.isTapSyncActive {
                        bottomFloatingControlDock
                            .padding(.horizontal, 28)
                            .padding(.bottom, 26)
                            .opacity(effectiveControlsVisible ? 1.0 : 0.0)
                            .offset(y: effectiveControlsVisible ? 0 : 16)
                            .allowsHitTesting(effectiveControlsVisible)
                    }
                }
                .animation(.easeInOut(duration: 0.38), value: effectiveControlsVisible)
            }
            .scaleEffect(store.isFullScreenLyricsStagePresented ? 1.0 : 0.965)
            .opacity(store.isFullScreenLyricsStagePresented ? 1.0 : 0.0)
            .animation(.spring(response: 0.40, dampingFraction: 0.86), value: store.isFullScreenLyricsStagePresented)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onContinuousHover { phase in
            switch phase {
            case .active:
                store.notifyFullScreenUserActivity()
            case .ended:
                store.scheduleFullScreenControlsAutoHide()
            }
        }
        .onChange(of: store.playback.paused) { _, _ in
            store.scheduleFullScreenControlsAutoHide()
        }
        .onAppear {
            store.notifyFullScreenUserActivity()
        }
    }

    private var effectiveControlsVisible: Bool {
        store.fullScreenControlsVisible || store.isHoveringFullScreenControls || store.isPickerOpen || store.isTapSyncActive || store.playback.paused
    }

    // MARK: - Dynamic Album Art Mesh & Blurred Glow Background

    private var dynamicAmbientBackground: some View {
        GeometryReader { geo in
            ZStack {
                // Deep Obsidian base canvas
                Color(red: 0.020, green: 0.020, blue: 0.028)

                // Dynamic palette gradient
                LinearGradient(
                    colors: [
                        store.palette.bgTopColor.opacity(0.92),
                        store.palette.bgBottomColor.opacity(0.96),
                        Color(red: 0.016, green: 0.016, blue: 0.022),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Blurred Album Cover Mesh Layer
                if let art = store.artworkImage {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width * 1.18, height: geo.size.height * 1.18)
                        .saturation(1.30)
                        .blur(radius: 86)
                        .opacity(0.36)
                        .blendMode(.plusLighter)
                }

                // Ambient Accent Glow Orbs
                RadialGradient(
                    colors: [
                        store.palette.accentColor.opacity(0.26),
                        store.palette.bgTopColor.opacity(0.14),
                        Color.clear,
                    ],
                    center: .top,
                    startRadius: 24,
                    endRadius: max(geo.size.width, geo.size.height) * 0.72
                )

                RadialGradient(
                    colors: [
                        store.palette.accentColor.opacity(0.16),
                        Color.clear,
                    ],
                    center: .bottom,
                    startRadius: 20,
                    endRadius: max(geo.size.width, geo.size.height) * 0.58
                )

                // Subtle dark readability veil so centered white karaoke lyrics always pop cleanly
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.46),
                        Color.black.opacity(0.24),
                        Color.black.opacity(0.54),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 0.75), value: store.palette)
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Header (Centered Compact Track Info + Full Screen / End Full Screen Controls)

    private var topOverlayBar: some View {
        ZStack {
            // Centered Track Info Capsule
            HStack(spacing: 12) {
                Group {
                    if let art = store.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.42), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.track?.title ?? "Ready to Sing")
                        .font(AppFont.styled(15, weight: .bold, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(1)

                    HStack(spacing: 6) {
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
                        Text(trackSubtitle)
                            .font(AppFont.styled(12.5, weight: .medium, style: store.fontStyle))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(obsidianGlassPill)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.32), radius: 14, x: 0, y: 6)

            // Right-aligned Full Screen & End Full Screen Controls
            HStack(spacing: 8) {
                Spacer()

                if effectiveControlsVisible {
                    // Toggle macOS Native Full Screen Space
                    Button {
                        store.toggleNativeWindowFullScreen()
                    } label: {
                        HStack(spacing: 5) {
                            Image(
                                systemName: store.isNativeWindowFullScreen
                                    ? "rectangle.arrowtriangle.2.inward"
                                    : "rectangle.arrowtriangle.2.outward"
                            )
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(store.isNativeWindowFullScreen ? store.palette.accentColor : .white.opacity(0.84))

                            Text(store.isNativeWindowFullScreen ? "Windowed" : "Full Monitor")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            store.isNativeWindowFullScreen
                                ? store.palette.accentColor.opacity(0.20)
                                : obsidianGlassPill
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(
                                store.isNativeWindowFullScreen
                                    ? store.palette.accentColor.opacity(0.45)
                                    : Color.white.opacity(0.13),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .help(store.isNativeWindowFullScreen ? "Return Window from macOS Full Screen Space" : "Expand Window to macOS Native Full Screen Space")

                    // End Full Screen Lyrics button (smooth exit transition back to player)
                    Button {
                        store.exitFullScreenLyrics()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(store.palette.accentColor)
                            Text("End Full Screen")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                            Text("Esc")
                                .font(.system(size: 9.5, weight: .bold).monospaced())
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(obsidianGlassPill)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("End Full Screen Lyrics (⇧⌘F or Esc)")
                }
            }
        }
        .onHover { hovering in
            store.setFullScreenControlsHovering(hovering)
        }
    }

    private var trackSubtitle: String {
        guard let track = store.track else {
            return "Play a song to start singing"
        }
        if let album = track.album, !album.isEmpty, album.lowercased() != track.title.lowercased() {
            return "\(track.artist) · \(album)"
        }
        return track.artist
    }

    // MARK: - Centered Karaoke Lyrics Stage

    @ViewBuilder
    private var lyricsCenterStage: some View {
        switch store.status {
        case .synced:
            if let lyrics = store.resolvedLyrics?.parsed {
                syncedCenteredList(lyrics: lyrics)
            }
        case .plainFallback:
            if let lyrics = store.resolvedLyrics?.parsed {
                plainCenteredList(lines: lyrics.plainLines)
            }
        case .adPlaying:
            centeredEmptyStatus(
                icon: "sparkles.tv",
                title: "Waiting for ad to finish...",
                subtitle: "Synced full screen lyrics will resume automatically."
            )
        case .loading:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(store.palette.accentColor)
                centeredEmptyStatus(
                    icon: nil,
                    title: "Finding synced lyrics...",
                    subtitle: store.track?.title ?? ""
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notFound:
            VStack(spacing: 14) {
                centeredEmptyStatus(
                    icon: "music.mic",
                    title: "Synced lyrics not found",
                    subtitle: "No automatic match found for this track yet."
                )
                glassActionButton("Search Lyrics Manually", icon: "magnifyingglass") {
                    store.openPicker()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            VStack(spacing: 14) {
                centeredEmptyStatus(
                    icon: "exclamationmark.triangle",
                    title: "Could not load lyrics",
                    subtitle: store.errorMessage ?? "Network error while reaching LRCLIB."
                )
                glassActionButton("Retry", icon: "arrow.clockwise") {
                    store.retryCurrentTrack()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .idle:
            centeredEmptyStatus(
                icon: "music.mic",
                title: "Full Screen Karaoke Ready",
                subtitle: "Play any song on YouTube Music or YouTube. Click any lyric line to seek."
            )
        }
    }

    private func syncedCenteredList(lyrics: ParsedLyrics) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .center, spacing: 24) {
                    if store.frame.instrumentalActive && store.frame.activeLineIndex < 0 {
                        centeredDotsView(progress: store.frame.instrumentalProgress)
                            .id("fullscreen-intro-dots")
                    }

                    ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { idx, line in
                        if line.isInstrumental {
                            let isCurrentBreak =
                                store.frame.instrumentalActive &&
                                store.frame.effectiveTime >= line.startTime &&
                                store.frame.effectiveTime < line.endTime
                            if isCurrentBreak {
                                centeredDotsView(progress: store.frame.instrumentalProgress)
                                    .id(idx)
                            }
                        } else {
                            centeredLyricRow(idx: idx, line: line)
                                .id(idx)
                        }
                    }
                }
                .frame(maxWidth: 1400)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 185)
                .padding(.bottom, 225)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.14),
                        .init(color: .black, location: 0.25),
                        .init(color: .black, location: 0.78),
                        .init(color: .clear, location: 0.92),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: store.frame.activeLineIndex) { _, newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.38)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                if store.frame.activeLineIndex >= 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.32)) {
                            proxy.scrollTo(store.frame.activeLineIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func centeredLyricRow(idx: Int, line: LyricLine) -> some View {
        let activeIdx = store.frame.activeLineIndex
        let isActive = idx == activeIdx
        let isPast = activeIdx >= 0 && idx < activeIdx
        let distance = activeIdx >= 0 ? abs(idx - activeIdx) : 1
        let romaji = store.romanizedText(at: idx)
        let translated = store.translatedText(at: idx)

        let inactiveOpacity: Double = {
            if distance == 1 { return isPast ? 0.44 : 0.38 }
            if distance == 2 { return isPast ? 0.30 : 0.26 }
            return 0.18
        }()

        VStack(alignment: .center, spacing: 6) {
            // Tier 1 (Top): Original Non-Latin script (Hangul / Kanji / Hanzi) when Romanization is active
            if romaji != nil {
                Text(line.text)
                    .font(AppFont.styled((isActive ? 17.5 : 15.0) * store.fontScale, weight: isActive ? .semibold : .regular, style: store.fontStyle))
                    .foregroundStyle(.white.opacity(isActive ? 0.84 : inactiveOpacity * 0.95))
                    .multilineTextAlignment(.center)
            }

            // Tier 2 (Center Hero): Progressive Word-Flow Karaoke Line
            if isActive {
                activeCenteredLineView(line: line, displayOverride: romaji)
                    .multilineTextAlignment(.center)
            } else {
                Text(romaji ?? line.text)
                    .font(AppFont.styled(25.0 * store.fontScale, weight: .bold, style: store.fontStyle))
                    .foregroundStyle(.white.opacity(inactiveOpacity))
                    .multilineTextAlignment(.center)
            }

            // Tier 3 (Bottom): Smart Translation
            if let translated, !translated.isEmpty {
                Text(translated)
                    .font(AppFont.styled((isActive ? 17.0 : 14.5) * store.fontScale, weight: isActive ? .medium : .regular, style: store.fontStyle))
                    .foregroundStyle(
                        isActive
                            ? .white.opacity(0.76)
                            : .white.opacity(inactiveOpacity * 0.85)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, isActive ? 14 : 8)
        .padding(.horizontal, 22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isActive ? Color.white.opacity(0.065) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    isActive ? store.palette.accentColor.opacity(0.32) : Color.clear,
                    lineWidth: 1
                )
        )
        .scaleEffect(isActive ? 1.0 : 0.94)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isActive)
        .contentShape(Rectangle())
        .onTapGesture {
            store.notifyFullScreenUserActivity()
            store.seekToLyricLine(line.startTime)
        }
    }

    @ViewBuilder
    private func activeCenteredLineView(line: LyricLine, displayOverride: String? = nil) -> some View {
        let baseSize = 31.5 * store.fontScale
        if displayOverride == nil, let words = line.words, words.count >= 2 {
            let combined = words.enumerated().reduce(Text("")) { acc, pair in
                let (wIdx, word) = pair
                let color: Color = wIdx <= store.frame.activeWordIndex ? .white : .white.opacity(0.38)
                return acc + Text(word.text).foregroundStyle(color)
            }
            combined
                .font(AppFont.styled(baseSize, weight: .bold, style: store.fontStyle))
                .shadow(color: store.palette.accentColor.opacity(0.45), radius: 16, x: 0, y: 2)
        } else {
            let heroText = displayOverride ?? line.text
            progressiveKaraokeText(heroText, progress: store.frame.lineProgress)
                .font(AppFont.styled(baseSize, weight: .bold, style: store.fontStyle))
                .shadow(color: store.palette.accentColor.opacity(0.42), radius: 16, x: 0, y: 2)
        }
    }

    private func progressiveKaraokeText(_ text: String, progress: Double) -> Text {
        let rawParts = text.split(separator: " ", omittingEmptySubsequences: false)
        guard rawParts.count >= 2 else {
            return Text(text).foregroundStyle(.white)
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
            let mid = cursor + w * 0.35
            let opacity: Double
            if litBudget >= cursor + w * 0.72 {
                opacity = 1.0
            } else if litBudget >= mid {
                opacity = 0.88
            } else {
                opacity = 0.38
            }
            combined = combined + Text(token).foregroundStyle(.white.opacity(opacity))
            cursor += w
        }
        return combined
    }

    private func plainCenteredList(lines: [String]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .center, spacing: 18) {
                HStack(spacing: 10) {
                    Text(store.lyricsSource == .ytmNative ? "YOUTUBE MUSIC · UNSYNCED LYRICS" : "LRCLIB · UNSYNCED LYRICS")
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.10))
                        .foregroundStyle(.white.opacity(0.72))
                        .clipShape(Capsule())

                    if store.canStartTapSync {
                        Button {
                            store.notifyFullScreenUserActivity()
                            store.startTapSync()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(store.palette.accentColor)
                                Text("Tap to Sync")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(store.palette.accentColor.opacity(0.22))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(store.palette.accentColor.opacity(0.48), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Tap Space line-by-line to convert these lyrics into synced karaoke")
                    }
                }
                .padding(.bottom, 8)

                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    if line.isEmpty {
                        Text(" ").font(.system(size: 12))
                    } else {
                        let romaji = store.romanizedText(at: idx)
                        let translated = store.translatedText(at: idx)
                        VStack(alignment: .center, spacing: 4) {
                            if romaji != nil {
                                Text(line)
                                    .font(AppFont.styled(15 * store.fontScale, weight: .regular, style: store.fontStyle))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .multilineTextAlignment(.center)
                            }
                            Text(romaji ?? line)
                                .font(AppFont.styled(23 * store.fontScale, weight: .bold, style: store.fontStyle))
                                .foregroundStyle(.white.opacity(0.94))
                                .multilineTextAlignment(.center)
                            if let translated, !translated.isEmpty {
                                Text(translated)
                                    .font(AppFont.styled(15 * store.fontScale, weight: .regular, style: store.fontStyle))
                                    .foregroundStyle(.white.opacity(0.54))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 1400, alignment: .center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 180)
            .padding(.bottom, 200)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.14),
                    .init(color: .black, location: 0.24),
                    .init(color: .black, location: 0.80),
                    .init(color: .clear, location: 0.93),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func centeredDotsView(progress: Double) -> some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { idx in
                let lit = progress >= (Double(idx) + 0.15) / 3.0
                Circle()
                    .fill(lit ? Color.white : Color.white.opacity(0.30))
                    .frame(width: lit ? 13 : 10, height: lit ? 13 : 10)
                    .shadow(color: lit ? store.palette.accentColor.opacity(0.9) : .clear, radius: 12)
                    .animation(.easeInOut(duration: 0.2), value: lit)
            }
        }
        .padding(.vertical, 12)
    }

    private func centeredEmptyStatus(icon: String?, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(store.palette.accentColor.opacity(0.85))
                    .padding(.bottom, 4)
            }
            Text(title)
                .font(AppFont.styled(20, weight: .bold, style: store.fontStyle))
                .foregroundStyle(.white.opacity(0.94))
                .multilineTextAlignment(.center)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppFont.styled(14, weight: .regular, style: store.fontStyle))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Floating Player & Karaoke Utility Dock

    private var bottomFloatingControlDock: some View {
        VStack(spacing: 10) {
            // Row 1: Interactive Seekbar with Elapsed & Total Duration
            HStack(spacing: 10) {
                Text(formatTime(store.playback.duration * store.playbackProgress))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(minWidth: 36, alignment: .trailing)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(height: 5)
                        Capsule()
                            .fill(store.palette.accentColor)
                            .frame(width: max(0, geo.size.width * store.playbackProgress), height: 5)
                            .shadow(color: store.palette.accentColor.opacity(0.6), radius: 6)
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
                .frame(height: 14)

                Text(formatTime(store.playback.duration))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(minWidth: 36, alignment: .leading)
            }

            // Row 2: Left (Sync Offset & Font Size) | Center (Prev / Play-Pause / Next) | Right (Translate, Romaji, Offline, Picker, End Full Screen)
            HStack(spacing: 10) {
                // Left utility cluster: Sync Offset & Font Size
                HStack(spacing: 6) {
                    HStack(spacing: 1) {
                        dockChip("-0.2s", help: "Lyrics Earlier (-200ms)") { store.adjustOffset(deltaMs: -200) }
                        dockChip(formatOffset(store.offsetMs), help: "Reset Lyrics Sync Offset") { store.resetOffset() }
                        dockChip("+0.2s", help: "Lyrics Later (+200ms)") { store.adjustOffset(deltaMs: 200) }
                    }
                    .padding(2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

                    HStack(spacing: 1) {
                        dockChip("A-", help: "Decrease Lyric Font Size") { store.adjustFont(delta: -0.1) }
                        dockChip("A+", help: "Increase Lyric Font Size") { store.adjustFont(delta: 0.1) }
                    }
                    .padding(2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                }

                Spacer(minLength: 8)

                // Center playback controls
                HStack(spacing: 12) {
                    dockIconCircle("backward.fill", size: 32, iconSize: 12, help: "Previous Track") {
                        store.prevTrack()
                    }

                    Button {
                        store.togglePlay()
                    } label: {
                        Image(systemName: store.playback.paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(store.palette.accentColor.opacity(0.28))
                            .clipShape(Circle())
                            .overlay(
                                Circle().strokeBorder(store.palette.accentColor.opacity(0.58), lineWidth: 1)
                            )
                            .shadow(color: store.palette.accentColor.opacity(0.35), radius: 8)
                    }
                    .buttonStyle(.plain)
                    .help("Play / Pause")

                    dockIconCircle("forward.fill", size: 32, iconSize: 12, help: "Next Track") {
                        store.nextTrack()
                    }
                }

                Spacer(minLength: 8)

                // Right karaoke & window controls
                HStack(spacing: 6) {
                    // Auto-Romanize Toggle
                    Button {
                        store.autoRomanizeEnabled.toggle()
                    } label: {
                        Text("Romaji")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(store.autoRomanizeEnabled ? .white.opacity(0.95) : .white.opacity(0.68))
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(
                                store.autoRomanizeEnabled
                                    ? store.palette.accentColor.opacity(0.20)
                                    : Color.white.opacity(0.06)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    store.autoRomanizeEnabled
                                        ? store.palette.accentColor.opacity(0.45)
                                        : Color.white.opacity(0.10),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Auto-Romanization / Romaji (⇧⌘R)")

                    // Smart Translate Toggle
                    Button {
                        store.translateEnabled.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "character.bubble")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(store.translateEnabled ? store.palette.accentColor : .white.opacity(0.74))
                            Text(store.translateEnabled ? store.translateTarget.shortCode : "TR")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(store.translateEnabled ? .white.opacity(0.95) : .white.opacity(0.74))
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(
                            store.translateEnabled
                                ? store.palette.accentColor.opacity(0.20)
                                : Color.white.opacity(0.06)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(
                                store.translateEnabled
                                    ? store.palette.accentColor.opacity(0.45)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Smart Lyrics Translation (⇧⌘E)")

                    if store.track != nil {
                        dockIconCircle(
                            store.isCurrentTrackOfflineSaved ? "checkmark.circle.fill" : "arrow.down.circle",
                            size: 28,
                            iconSize: 12,
                            tint: store.isCurrentTrackOfflineSaved ? store.palette.accentColor : nil,
                            help: store.isCurrentTrackOfflineSaved ? "Lyrics Saved Offline" : "Save Lyrics Offline (⇧⌘D)"
                        ) {
                            store.saveCurrentTrackOffline()
                        }

                        dockIconCircle("magnifyingglass", size: 28, iconSize: 11.5, help: "Choose / Search Lyrics Version") {
                            store.openPicker()
                        }
                    }

                    dockIconCircle(
                        "arrow.down.right.and.arrow.up.left",
                        size: 28,
                        iconSize: 11,
                        tint: store.palette.accentColor,
                        help: "End Full Screen Lyrics (⇧⌘F / Esc)"
                    ) {
                        store.exitFullScreenLyrics()
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 780)
        .background {
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                    .opacity(0.84)
                Color(red: 0.075, green: 0.075, blue: 0.110).opacity(0.86)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.52), radius: 24, x: 0, y: 10)
        .onHover { hovering in
            store.setFullScreenControlsHovering(hovering)
        }
    }

    // MARK: - Centered Lyrics Picker Modal inside Full Screen

    private var centeredPickerModal: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Choose Lyrics Version")
                    .font(AppFont.styled(16, weight: .bold, style: store.fontStyle))
                    .foregroundStyle(.white)
                Spacer()
                glassActionButton("Close", icon: "xmark") {
                    store.closePicker()
                }
            }

            HStack(spacing: 8) {
                TextField("Search artist & song...", text: $store.pickerQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { store.runManualPickerSearch() }
                glassActionButton("Search", icon: "magnifyingglass") {
                    store.runManualPickerSearch()
                }
            }

            if store.isPickerSearching {
                Spacer()
                ProgressView().controlSize(.regular).tint(store.palette.accentColor)
                Text("Searching LRCLIB...")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
            } else if store.pickerCandidates.isEmpty {
                Spacer()
                Text("No matching lyrics found. Edit the query above and press Search.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 8) {
                        ForEach(store.pickerCandidates) { candidate in
                            let isSelected = candidate.id == store.resolvedLyrics?.candidateId
                            let hasSynced = !(candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                            Button {
                                store.selectPickerCandidate(candidate)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(candidate.trackName)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text([candidate.artistName, formatTime(candidate.duration)].joined(separator: " · "))
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(.white.opacity(0.64))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(hasSynced ? "SYNCED" : "PLAIN")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(hasSynced ? store.palette.accentColor.opacity(0.34) : Color.white.opacity(0.14))
                                        .foregroundStyle(.white.opacity(0.94))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(isSelected ? store.palette.accentColor.opacity(0.24) : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(isSelected ? store.palette.accentColor : Color.white.opacity(0.10), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: 560, maxHeight: 460)
        .background {
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                    .opacity(0.90)
                Color(red: 0.075, green: 0.075, blue: 0.112).opacity(0.90)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 28, x: 0, y: 12)
    }

    // MARK: - Helpers

    private var obsidianGlassPill: Color {
        Color(red: 0.085, green: 0.085, blue: 0.125).opacity(0.82)
    }

    private func dockChip(_ label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.86))
                .padding(.horizontal, 7)
                .frame(height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func dockIconCircle(
        _ symbol: String,
        size: CGFloat,
        iconSize: CGFloat,
        tint: Color? = nil,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint ?? .white.opacity(0.86))
                .frame(width: size, height: size)
                .background(tint != nil ? tint!.opacity(0.18) : Color.white.opacity(0.07))
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(
                        tint != nil ? tint!.opacity(0.42) : Color.white.opacity(0.11),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func glassActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(obsidianGlassPill)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func formatOffset(_ offsetMs: Double) -> String {
        let sec = offsetMs / 1000.0
        return String(format: "%@%.1fs", sec > 0 ? "+" : "", sec)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
