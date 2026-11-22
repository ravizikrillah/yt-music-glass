import AppKit
import SwiftUI

final class DraggableVisualEffectView: NSVisualEffectView {
    override var mouseDownCanMoveWindow: Bool { true }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = DraggableVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

final class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct HudContentView: View {
    @ObservedObject var store: AppStore

    private var showChrome: Bool {
        (store.isHovering || store.isPickerOpen) && !store.isClickThrough
    }

    private var effectiveOpacity: Double {
        if store.isPickerOpen {
            return 0.88
        }
        if showChrome {
            return max(store.backgroundOpacity, 0.42)
        }
        return store.backgroundOpacity
    }

    var body: some View {
        ZStack {
            // Transparent (0%) -> Native macOS Frosted Glass tinted with live Album Accent
            if effectiveOpacity > 0.01 {
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .opacity(min(1.0, effectiveOpacity * 1.35))
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.115).opacity(effectiveOpacity * 0.92),
                                    Color(red: 0.055, green: 0.055, blue: 0.082).opacity(effectiveOpacity * 0.96),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(showChrome ? 0.24 : effectiveOpacity * 0.22),
                            lineWidth: 1
                        )
                )
            }

            // Full-window drag surface behind interactive controls so grabbing empty space moves the HUD
            if !store.isClickThrough {
                WindowDragHandle()
            }

            if store.isPickerOpen {
                lyricsPickerOverlay
            } else {
                VStack(spacing: 0) {
                    if showChrome {
                        // Full-width top drag strip with subtle macOS grab pill
                        ZStack {
                            WindowDragHandle()
                            Capsule()
                                .fill(Color.white.opacity(0.36))
                                .frame(width: 42, height: 4)
                                .allowsHitTesting(false)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 14)
                        .transition(.opacity)

                        headerBar
                            .transition(.opacity)
                    }

                    stageContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showChrome {
                        footerBar
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, showChrome ? 8 : 8)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: showChrome)
        .onHover { hovering in
            store.isHovering = hovering
        }
    }

    private var headerBar: some View {
        ZStack {
            WindowDragHandle()

            HStack(spacing: 6) {
                if store.audioVisualizerEnabled && store.track != nil {
                    MiniAudioVisualizerView(
                        phase: store.visualizerPhase,
                        isPlaying: !store.playback.paused && !store.playback.isAdPlaying,
                        accentColor: store.palette.accentColor,
                        barCount: 4,
                        maxHeight: 12,
                        barWidth: 2,
                        spacing: 1.5
                    )
                } else {
                    Circle()
                        .fill(store.track != nil ? store.palette.accentColor : Color.white.opacity(0.35))
                        .frame(width: 7, height: 7)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(store.track?.title ?? "YT Music Glass")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)

                    if store.displayMode == .full {
                        Text(store.track?.artist ?? "Drag here to move")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }
                .allowsHitTesting(false)

                Spacer(minLength: 6)

                if store.track != nil {
                    hudIconButton(
                        systemImage: "character.bubble",
                        helpText: "Toggle Smart Translate (\(store.translateSource.shortCode) → \(store.translateTarget.shortCode))",
                        accent: store.translateEnabled
                    ) {
                        store.translateEnabled.toggle()
                    }

                    hudPillButton(title: "Lyrics", systemImage: "magnifyingglass") {
                        store.openPicker()
                    }
                }

                hudPillButton(
                    title: store.displayMode == .compact ? "Full" : "Compact",
                    systemImage: store.displayMode == .compact ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
                ) {
                    store.toggleDisplayMode()
                }

                hudIconButton(systemImage: "sidebar.right", helpText: "Dock back to Right Sidebar") {
                    store.dockToSidebar()
                }

                hudIconButton(systemImage: "lock.open", helpText: "Click-Through Lock (unlock from Menu Bar or Toolbar)") {
                    store.isClickThrough = true
                }

                hudIconButton(systemImage: "xmark", helpText: "Hide Floating HUD") {
                    store.isHudVisible = false
                }
            }
        }
        .frame(height: store.displayMode == .full ? 34 : 26)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var stageContent: some View {
        switch store.status {
        case .synced:
            if let lyrics = store.resolvedLyrics?.parsed {
                if store.displayMode == .compact {
                    compactSyncedView(lyrics: lyrics)
                } else {
                    fullSyncedView(lyrics: lyrics)
                }
            }
        case .plainFallback:
            if let lyrics = store.resolvedLyrics?.parsed {
                plainLyricsView(lines: lyrics.plainLines)
            }
        case .adPlaying:
            statusMessage(title: "Waiting for ad...", subtitle: "Lyrics resume automatically after the ad.")
        case .loading:
            statusMessage(title: "Finding synced lyrics...", subtitle: store.track?.title ?? "")
        case .notFound:
            VStack(spacing: 8) {
                statusMessage(title: "Lyrics not found", subtitle: "Try searching another title or artist.")
                hudPillButton(title: "Search Manually", systemImage: "magnifyingglass") {
                    store.openPicker()
                }
            }
        case .error:
            VStack(spacing: 8) {
                statusMessage(
                    title: "Could not load lyrics",
                    subtitle: store.errorMessage ?? "Network error while reaching LRCLIB."
                )
                hudPillButton(title: "Retry", systemImage: "arrow.clockwise") {
                    store.retryCurrentTrack()
                }
            }
        case .idle:
            statusMessage(
                title: "Play a song in YT Music Glass",
                subtitle: "Hover here to adjust transparency (0%–85%), switch Compact/Full, or lock click-through."
            )
        }
    }

    private func compactSyncedView(lyrics: ParsedLyrics) -> some View {
        let activeIdx = store.frame.activeLineIndex
        let nextIdx = store.frame.nextVocalLineIndex
        let activeLine = activeIdx >= 0 && activeIdx < lyrics.lines.count ? lyrics.lines[activeIdx] : nil
        let nextLine = nextIdx >= 0 && nextIdx < lyrics.lines.count ? lyrics.lines[nextIdx] : nil
        let activeRomaji = activeIdx >= 0 ? store.romanizedText(at: activeIdx) : nil
        let activeTranslation = activeIdx >= 0 ? store.translatedText(at: activeIdx) : nil
        let nextRomaji = nextIdx >= 0 ? store.romanizedText(at: nextIdx) : nil

        return VStack(alignment: .center, spacing: 4) {
            if store.frame.instrumentalActive {
                instrumentalDotsView(progress: store.frame.instrumentalProgress)
                if let next = nextLine {
                    Text("Next: \(nextRomaji ?? next.text)")
                        .font(.system(size: 13.5 * store.fontScale, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .modifier(CrispLyricsShadow())
                }
            } else if let active = activeLine, !active.isInstrumental {
                if activeRomaji != nil {
                    Text(active.text)
                        .font(AppFont.styled(11.5 * store.fontScale, weight: .medium, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .modifier(CrispLyricsShadow())
                }

                karaokeActiveLineView(
                    line: active,
                    baseSize: 21.5 * store.fontScale,
                    centered: true,
                    displayOverride: activeRomaji
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    store.seekToLyricLine(active.startTime)
                }

                if let translated = activeTranslation, !translated.isEmpty {
                    Text(translated)
                        .font(AppFont.styled(12.5 * store.fontScale, weight: .regular, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .modifier(CrispLyricsShadow())
                } else if let next = nextLine {
                    Text(nextRomaji ?? next.text)
                        .font(AppFont.styled(13.5 * store.fontScale, weight: .medium, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.56))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .modifier(CrispLyricsShadow())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.seekToLyricLine(next.startTime)
                        }
                }
            } else if let next = nextLine {
                Text(nextRomaji ?? next.text)
                    .font(AppFont.styled(20 * store.fontScale, weight: .bold, style: store.fontStyle))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .modifier(CrispLyricsShadow())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fullSyncedView(lyrics: ParsedLyrics) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 15) {
                    if store.frame.instrumentalActive && store.frame.activeLineIndex < 0 {
                        instrumentalDotsView(progress: store.frame.instrumentalProgress)
                            .id("intro-dots")
                    }

                    ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { idx, line in
                        if line.isInstrumental {
                            let isCurrentBreak =
                                store.frame.instrumentalActive &&
                                store.frame.effectiveTime >= line.startTime &&
                                store.frame.effectiveTime < line.endTime
                            if isCurrentBreak {
                                instrumentalDotsView(progress: store.frame.instrumentalProgress)
                                    .id(idx)
                            }
                        } else {
                            let isActive = idx == store.frame.activeLineIndex
                            let isPast = store.frame.activeLineIndex >= 0 && idx < store.frame.activeLineIndex
                            let romaji = store.romanizedText(at: idx)
                            let translated = store.translatedText(at: idx)

                            VStack(alignment: .leading, spacing: 3) {
                                if romaji != nil {
                                    Text(line.text)
                                        .font(AppFont.styled(12 * store.fontScale, weight: isActive ? .medium : .regular, style: store.fontStyle))
                                        .foregroundStyle(.white.opacity(isActive ? 0.80 : (isPast ? 0.44 : 0.34)))
                                        .modifier(CrispLyricsShadow())
                                }

                                if isActive {
                                    karaokeActiveLineView(
                                        line: line,
                                        baseSize: 22 * store.fontScale,
                                        centered: false,
                                        displayOverride: romaji
                                    )
                                } else {
                                    Text(romaji ?? line.text)
                                        .font(AppFont.styled(19 * store.fontScale, weight: .bold, style: store.fontStyle))
                                        .foregroundStyle(.white.opacity(isPast ? 0.48 : 0.36))
                                        .modifier(CrispLyricsShadow())
                                }

                                if let translated, !translated.isEmpty {
                                    Text(translated)
                                        .font(AppFont.styled(12.5 * store.fontScale, weight: .regular, style: store.fontStyle))
                                        .foregroundStyle(.white.opacity(isActive ? 0.68 : (isPast ? 0.34 : 0.28)))
                                        .modifier(CrispLyricsShadow())
                                        .padding(.top, 1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 3)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.seekToLyricLine(line.startTime)
                            }
                            .id(idx)
                        }
                    }
                }
                .padding(.vertical, 72)
                .padding(.horizontal, 4)
            }
            .onChange(of: store.frame.activeLineIndex) { _, newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.32)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func plainLyricsView(lines: [String]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.lyricsSource == .ytmNative ? "YOUTUBE MUSIC · UNSYNCED" : "LRCLIB · UNSYNCED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.bottom, 4)

                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    if line.isEmpty {
                        Text(" ").font(.system(size: 10))
                    } else {
                        let romaji = store.romanizedText(at: idx)
                        let translated = store.translatedText(at: idx)
                        VStack(alignment: .leading, spacing: 2) {
                            if romaji != nil {
                                Text(line)
                                    .font(.system(size: 12 * store.fontScale, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .modifier(CrispLyricsShadow())
                            }
                            Text(romaji ?? line)
                                .font(.system(size: 16 * store.fontScale, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .modifier(CrispLyricsShadow())
                            if let translated, !translated.isEmpty {
                                Text(translated)
                                    .font(.system(size: 12 * store.fontScale, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.56))
                                    .modifier(CrispLyricsShadow())
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func karaokeActiveLineView(
        line: LyricLine,
        baseSize: Double,
        centered: Bool,
        displayOverride: String? = nil
    ) -> some View {
        if displayOverride == nil, let words = line.words, words.count >= 2 {
            let combined = words.enumerated().reduce(Text("")) { acc, pair in
                let (wIdx, word) = pair
                let color: Color = wIdx <= store.frame.activeWordIndex ? .white : .white.opacity(0.42)
                return acc + Text(word.text).foregroundStyle(color)
            }
            combined
                .font(AppFont.styled(baseSize, weight: .bold, style: store.fontStyle))
                .multilineTextAlignment(centered ? .center : .leading)
                .modifier(CrispLyricsShadow(glow: true, accentColor: store.palette.accentColor))
        } else {
            let heroText = displayOverride ?? line.text
            progressiveKaraokeText(heroText, progress: store.frame.lineProgress)
                .font(AppFont.styled(baseSize, weight: .bold, style: store.fontStyle))
                .multilineTextAlignment(centered ? .center : .leading)
                .modifier(CrispLyricsShadow(glow: true, accentColor: store.palette.accentColor))
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
                opacity = 0.86
            } else {
                opacity = 0.42
            }
            combined = combined + Text(token).foregroundStyle(.white.opacity(opacity))
            cursor += w
        }
        return combined
    }

    private func instrumentalDotsView(progress: Double) -> some View {
        HStack(spacing: 9) {
            ForEach(0..<3, id: \.self) { idx in
                let threshold = (Double(idx) + 0.15) / 3.0
                let lit = progress >= threshold
                Circle()
                    .fill(lit ? Color.white : Color.white.opacity(0.35))
                    .frame(width: lit ? 10 : 8, height: lit ? 10 : 8)
                    .shadow(color: lit ? store.palette.accentColor.opacity(0.75) : .clear, radius: 8)
                    .animation(.easeInOut(duration: 0.18), value: lit)
            }
        }
        .padding(.vertical, 6)
    }

    private func statusMessage(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .modifier(CrispLyricsShadow())
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .modifier(CrispLyricsShadow())
            }
        }
        .padding(.horizontal, 12)
        .allowsHitTesting(false)
    }

    private var footerBar: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [store.palette.accentColor, Color.white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * store.playbackProgress))
                }
            }
            .frame(height: 3)

            HStack(spacing: 7) {
                HStack(spacing: 4) {
                    hudIconButton(systemImage: "backward.fill", helpText: "Previous") {
                        store.prevTrack()
                    }
                    hudIconButton(
                        systemImage: store.playback.paused ? "play.fill" : "pause.fill",
                        helpText: "Play / Pause",
                        accent: true
                    ) {
                        store.togglePlay()
                    }
                    hudIconButton(systemImage: "forward.fill", helpText: "Next") {
                        store.nextTrack()
                    }
                }

                HStack(spacing: 3) {
                    hudTextButton("-0.2s") { store.adjustOffset(deltaMs: -200) }
                    hudTextButton(formatOffset(store.offsetMs)) { store.resetOffset() }
                    hudTextButton("+0.2s") { store.adjustOffset(deltaMs: 200) }
                }

                Spacer(minLength: 4)

                HStack(spacing: 3) {
                    hudTextButton("A-") { store.adjustFont(delta: -0.1) }
                    hudTextButton("A+") { store.adjustFont(delta: 0.1) }
                }

                HStack(spacing: 4) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                    Slider(value: $store.backgroundOpacity, in: 0.0...0.85)
                        .controlSize(.mini)
                        .frame(width: 66)
                        .tint(store.palette.accentColor)
                }
                .help("Background Opacity (0% = Pure Transparent)")
            }
        }
        .padding(.top, 6)
    }

    private var lyricsPickerOverlay: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Choose Lyrics Version")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                hudPillButton(title: "Close", systemImage: "xmark") {
                    store.closePicker()
                }
            }

            HStack(spacing: 6) {
                TextField("Search artist & song...", text: $store.pickerQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        store.runManualPickerSearch()
                    }
                hudPillButton(title: "Search", systemImage: "magnifyingglass") {
                    store.runManualPickerSearch()
                }
            }

            if store.isPickerSearching {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .tint(store.palette.accentColor)
                Text("Searching LRCLIB...")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
            } else if store.pickerCandidates.isEmpty {
                Spacer()
                Text("No matching lyrics found. Edit the query above and press Search.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 6) {
                        ForEach(store.pickerCandidates) { candidate in
                            let isSelected = candidate.id == store.resolvedLyrics?.candidateId
                            let hasSynced = !(candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                            Button {
                                store.selectPickerCandidate(candidate)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.trackName)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text([candidate.artistName, formatDuration(candidate.duration)].joined(separator: " · "))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.65))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(hasSynced ? "SYNCED" : "PLAIN")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(hasSynced ? store.palette.accentColor.opacity(0.22) : Color.white.opacity(0.10))
                                        .foregroundStyle(.white.opacity(0.88))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(isSelected ? store.palette.accentColor.opacity(0.18) : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(isSelected ? store.palette.accentColor.opacity(0.50) : Color.white.opacity(0.10), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
    }

    private func formatOffset(_ offsetMs: Double) -> String {
        let sec = offsetMs / 1000.0
        return String(format: "%@%.1fs", sec > 0 ? "+" : "", sec)
    }

    private func formatDuration(_ sec: Double) -> String {
        guard sec.isFinite && sec > 0 else { return "0:00" }
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func hudIconButton(
        systemImage: String,
        helpText: String,
        accent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(accent ? store.palette.accentColor : .white.opacity(0.86))
                .frame(width: 26, height: 26)
                .background(accent ? store.palette.accentColor.opacity(0.20) : Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(
                        accent ? store.palette.accentColor.opacity(0.45) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private func hudTextButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func hudPillButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct CrispLyricsShadow: ViewModifier {
    var glow: Bool = false
    var accentColor: Color = .white

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.92), radius: 2, x: 0, y: 1)
            .shadow(color: glow ? accentColor.opacity(0.40) : .black.opacity(0.6), radius: glow ? 10 : 5, x: 0, y: 2)
    }
}
