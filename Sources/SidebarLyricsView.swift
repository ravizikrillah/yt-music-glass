import AppKit
import SwiftUI

struct SidebarLyricsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Group {
            if store.isPickerOpen {
                pickerContent
            } else if store.isTapSyncActive {
                VStack(spacing: 0) {
                    sidebarHeader
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                    TapSyncPanelView(store: store, compactLayout: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        sidebarHeader
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 1)
                        sidebarStage
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Floating Obsidian Glass Dock — identical silhouette & 12px bottom lift as the Floating Player Bar
                    sidebarFooter
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background {
            // Seamless pure dark canvas matching YouTube Music web (#030303 -> #070709)
            Color(red: 0.024, green: 0.024, blue: 0.028)
        }
        .clipped()
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var obsidianSurface: Color {
        Color(red: 0.092, green: 0.092, blue: 0.135).opacity(0.84)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            // Crisp Apple Music album thumbnail
            Group {
                if let art = store.artworkImage {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                        Image(systemName: "music.note")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.track?.title ?? "Lyrics")
                    .font(AppFont.styled(14, weight: .bold, style: store.fontStyle))
                    .foregroundStyle(.white.opacity(0.95))
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
                    Text(store.track?.artist ?? "Play a song to start singing")
                        .font(AppFont.styled(12, weight: .regular, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if store.track != nil {
                Button {
                    store.saveCurrentTrackOffline()
                } label: {
                    Image(systemName: store.isCurrentTrackOfflineSaved ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(store.isCurrentTrackOfflineSaved ? store.palette.accentColor : .white.opacity(0.80))
                        .frame(width: 28, height: 28)
                        .background(store.isCurrentTrackOfflineSaved ? store.palette.accentColor.opacity(0.18) : obsidianSurface)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(
                                store.isCurrentTrackOfflineSaved ? store.palette.accentColor.opacity(0.42) : Color.white.opacity(0.11),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .help(
                    store.isCurrentTrackOfflineSaved
                        ? "Lyrics saved offline — ready for karaoke without internet"
                        : "Save this track's lyrics for offline karaoke (⇧⌘D)"
                )

                iconButton("magnifyingglass", help: "Switch / Search Lyrics Version") {
                    store.openPicker()
                }
            }

            Button {
                store.enterFullScreenLyrics()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.isFullScreenLyricsVisible ? store.palette.accentColor : .white.opacity(0.84))
                    .frame(width: 28, height: 28)
                    .background(store.isFullScreenLyricsVisible ? store.palette.accentColor.opacity(0.20) : obsidianSurface)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(
                            store.isFullScreenLyricsVisible ? store.palette.accentColor.opacity(0.45) : Color.white.opacity(0.11),
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
            .help("Open Full Screen Lyrics (⇧⌘F)")

            Button {
                store.popOutToFloating()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pip.enter")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(store.palette.accentColor)
                    Text("Float")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(store.palette.accentColor.opacity(0.18))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(store.palette.accentColor.opacity(0.40), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Pop out into Transparent Floating Lyrics window (⇧⌘L)")

            iconButton("xmark", help: "Close Lyrics Sidebar") {
                store.isSidebarVisible = false
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var sidebarStage: some View {
        switch store.status {
        case .synced:
            if let lyrics = store.resolvedLyrics?.parsed {
                syncedList(lyrics: lyrics)
            }
        case .plainFallback:
            if let lyrics = store.resolvedLyrics?.parsed {
                plainList(lines: lyrics.plainLines)
            }
        case .adPlaying:
            emptyStatus(title: "Waiting for ad...", subtitle: "Lyrics resume automatically after the ad.")
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(store.palette.accentColor)
                emptyStatus(title: "Finding synced lyrics...", subtitle: store.track?.title ?? "")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notFound:
            VStack(spacing: 10) {
                emptyStatus(title: "Lyrics not found", subtitle: "No synced lyrics matched this track yet.")
                actionPill("Search Manually", icon: "magnifyingglass") {
                    store.openPicker()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            VStack(spacing: 10) {
                emptyStatus(
                    title: "Could not load lyrics",
                    subtitle: store.errorMessage ?? "Network error while reaching LRCLIB."
                )
                actionPill("Retry", icon: "arrow.clockwise") {
                    store.retryCurrentTrack()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .idle:
            emptyStatus(
                title: "Ready to sing",
                subtitle: "Play any song on YouTube Music or YouTube. Click any lyric line to seek."
            )
        }
    }

    private func syncedList(lyrics: ParsedLyrics) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if store.frame.instrumentalActive && store.frame.activeLineIndex < 0 {
                        dotsView(progress: store.frame.instrumentalProgress)
                            .id("sidebar-intro-dots")
                    }

                    ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { idx, line in
                        if line.isInstrumental {
                            let isCurrentBreak =
                                store.frame.instrumentalActive &&
                                store.frame.effectiveTime >= line.startTime &&
                                store.frame.effectiveTime < line.endTime
                            if isCurrentBreak {
                                dotsView(progress: store.frame.instrumentalProgress)
                                    .id(idx)
                            }
                        } else {
                            let isActive = idx == store.frame.activeLineIndex
                            let isPast = store.frame.activeLineIndex >= 0 && idx < store.frame.activeLineIndex
                            let romaji = store.romanizedText(at: idx)
                            let translated = store.translatedText(at: idx)

                            VStack(alignment: .leading, spacing: 3) {
                                // Tier 1 (Top, small): Original non-Latin script (exact phone-screenshot hierarchy)
                                if romaji != nil {
                                    Text(line.text)
                                        .font(AppFont.styled(12.5 * store.fontScale, weight: isActive ? .medium : .regular, style: store.fontStyle))
                                        .foregroundStyle(.white.opacity(isActive ? 0.80 : (isPast ? 0.42 : 0.34)))
                                }

                                // Tier 2 (Middle, BIG hero): Romaji if non-Latin, else original Latin line
                                if isActive {
                                    activeLineView(line: line, displayOverride: romaji)
                                } else {
                                    Text(romaji ?? line.text)
                                        .font(AppFont.styled(19 * store.fontScale, weight: .bold, style: store.fontStyle))
                                        .foregroundStyle(.white.opacity(isPast ? 0.46 : 0.34))
                                }

                                // Tier 3 (Bottom, muted): Translation (only when enabled & language differs)
                                if let translated, !translated.isEmpty {
                                    Text(translated)
                                        .font(AppFont.styled(12.5 * store.fontScale, weight: .regular, style: store.fontStyle))
                                        .foregroundStyle(.white.opacity(isActive ? 0.64 : (isPast ? 0.32 : 0.26)))
                                        .padding(.top, 1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                isActive
                                    ? Color.white.opacity(0.055)
                                    : Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        isActive ? Color.white.opacity(0.09) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .animation(.easeOut(duration: 0.22), value: isActive)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.seekToLyricLine(line.startTime)
                            }
                            .id(idx)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 56)
                .padding(.bottom, 104)
            }
            .onChange(of: store.frame.activeLineIndex) { _, newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.34)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func activeLineView(line: LyricLine, displayOverride: String? = nil) -> some View {
        let baseSize = 21.0 * store.fontScale
        if displayOverride == nil, let words = line.words, words.count >= 2 {
            let combined = words.enumerated().reduce(Text("")) { acc, pair in
                let (wIdx, word) = pair
                let color: Color = wIdx <= store.frame.activeWordIndex ? .white : .white.opacity(0.40)
                return acc + Text(word.text).foregroundStyle(color)
            }
            combined
                .font(AppFont.styled(baseSize, weight: .bold, style: store.fontStyle))
                .shadow(color: store.palette.accentColor.opacity(0.32), radius: 10, x: 0, y: 1)
        } else {
            let heroText = displayOverride ?? line.text
            progressiveKaraokeText(heroText, progress: store.frame.lineProgress)
                .font(AppFont.styled(baseSize, weight: .bold, style: store.fontStyle))
                .shadow(color: store.palette.accentColor.opacity(0.30), radius: 10, x: 0, y: 1)
        }
    }

    /// Word-by-word progressive illumination along wrapped multi-line lyrics (never slices line 2 early).
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
                opacity = 0.40
            }
            combined = combined + Text(token).foregroundStyle(.white.opacity(opacity))
            cursor += w
        }
        return combined
    }

    private func plainList(lines: [String]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Text(store.lyricsSource == .ytmNative ? "YOUTUBE MUSIC · UNSYNCED" : "LRCLIB · UNSYNCED")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .foregroundStyle(.white.opacity(0.68))
                        .clipShape(Capsule())

                    if store.canStartTapSync {
                        Button {
                            store.startTapSync()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(store.palette.accentColor)
                                Text("Tap to Sync")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3.5)
                            .background(store.palette.accentColor.opacity(0.20))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(store.palette.accentColor.opacity(0.45), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Tap Space line-by-line to convert these lyrics into synced karaoke")
                    }
                }
                .padding(.bottom, 6)

                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    if line.isEmpty {
                        Text(" ").font(.system(size: 10))
                    } else {
                        let romaji = store.romanizedText(at: idx)
                        let translated = store.translatedText(at: idx)
                        VStack(alignment: .leading, spacing: 2) {
                            if romaji != nil {
                                Text(line)
                                    .font(AppFont.styled(12 * store.fontScale, weight: .regular, style: store.fontStyle))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Text(romaji ?? line)
                                .font(AppFont.styled(16.5 * store.fontScale, weight: .medium, style: store.fontStyle))
                                .foregroundStyle(.white.opacity(0.92))
                            if let translated, !translated.isEmpty {
                                Text(translated)
                                    .font(AppFont.styled(12 * store.fontScale, weight: .regular, style: store.fontStyle))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 92)
        }
    }

    private func dotsView(progress: Double) -> some View {
        HStack(spacing: 9) {
            ForEach(0..<3, id: \.self) { idx in
                let lit = progress >= (Double(idx) + 0.15) / 3.0
                Circle()
                    .fill(lit ? Color.white : Color.white.opacity(0.32))
                    .frame(width: lit ? 10 : 8, height: lit ? 10 : 8)
                    .shadow(color: lit ? store.palette.accentColor.opacity(0.85) : .clear, radius: 9)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }

    private func emptyStatus(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            // Sync offset segmented glass capsule
            HStack(spacing: 1) {
                textChip("-0.2s") { store.adjustOffset(deltaMs: -200) }
                textChip(formatOffset(store.offsetMs)) { store.resetOffset() }
                textChip("+0.2s") { store.adjustOffset(deltaMs: 200) }
            }
            .padding(2)
            .background(Color.white.opacity(0.055))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            .fixedSize()

            Spacer(minLength: 4)

            if store.offlineSyncActive && store.offlineSyncTotal > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(store.palette.accentColor)
                    Text("\(min(store.offlineSyncCompleted, store.offlineSyncTotal))/\(store.offlineSyncTotal)")
                        .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.76))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(store.palette.accentColor.opacity(0.14))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(store.palette.accentColor.opacity(0.32), lineWidth: 1))
                .layoutPriority(-1)
            } else if let sourceLabel = sourceBadgeLabel {
                HStack(spacing: 3) {
                    if store.isCurrentTrackOfflineSaved {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(store.palette.accentColor)
                    }
                    Text(sourceLabel)
                        .font(.system(size: 9.5, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.56))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .layoutPriority(-1)
            }

            // Quick Translate pill — Soft Tinted Obsidian Glass (matches Floating Player Bar lyrics button)
            Button {
                store.translateEnabled.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "character.bubble")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(store.translateEnabled ? store.palette.accentColor : .white.opacity(0.74))
                    Text(store.translateEnabled ? store.translateTarget.shortCode : "TR")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(store.translateEnabled ? .white.opacity(0.95) : .white.opacity(0.76))
                }
                .padding(.horizontal, 9)
                .frame(height: 26)
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
            .fixedSize()
            .help("Toggle Smart Lyrics Translation (\(store.translateSource.shortCode) → \(store.translateTarget.shortCode))")

            // Font size segmented glass capsule
            HStack(spacing: 1) {
                textChip("A-") { store.adjustFont(delta: -0.1) }
                textChip("A+") { store.adjustFont(delta: 0.1) }
            }
            .padding(2)
            .background(Color.white.opacity(0.055))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .frame(minWidth: 0, maxWidth: .infinity)
        .background {
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                    .opacity(0.75)
                Color(red: 0.080, green: 0.080, blue: 0.116).opacity(0.84)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.48), radius: 18, x: 0, y: 8)
    }

    private var sourceBadgeLabel: String? {
        switch store.lyricsSource {
        case .lrclibSynced:
            return store.resolvedLyrics?.parsed.hasWordSync == true ? "Word Sync" : "Synced"
        case .userSynced:
            return "Tap Sync"
        case .lrclibPlain:
            return "LRCLIB"
        case .ytmNative:
            return "YTM"
        case nil:
            return nil
        }
    }

    private var pickerContent: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Choose Lyrics Version")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                actionPill("Close", icon: "xmark") {
                    store.closePicker()
                }
            }

            HStack(spacing: 6) {
                TextField("Search artist & song...", text: $store.pickerQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { store.runManualPickerSearch() }
                actionPill("Search", icon: "magnifyingglass") {
                    store.runManualPickerSearch()
                }
            }

            if store.isPickerSearching {
                Spacer()
                ProgressView().controlSize(.small).tint(store.palette.accentColor)
                Text("Searching LRCLIB...")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
            } else if store.pickerCandidates.isEmpty {
                Spacer()
                Text("No matching lyrics found. Edit the query above and press Search.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
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
                                            .foregroundStyle(.white.opacity(0.62))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(hasSynced ? "SYNCED" : "PLAIN")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(hasSynced ? store.palette.accentColor.opacity(0.32) : Color.white.opacity(0.14))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(isSelected ? store.palette.accentColor.opacity(0.24) : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(isSelected ? store.palette.accentColor : Color.white.opacity(0.09), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        return String(format: "%d:%02d", Int(sec) / 60, Int(sec) % 60)
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.80))
                .frame(width: 28, height: 28)
                .background(obsidianSurface)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func textChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.84))
                .padding(.horizontal, 6)
                .frame(height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionPill(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10.5, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(obsidianSurface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
