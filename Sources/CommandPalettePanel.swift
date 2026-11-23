import AppKit
import SwiftUI

struct PaletteAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let shortcut: String?
    let keywords: String
    let perform: () -> Void
}

final class CommandPalettePanel: NSPanel {
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
    }
}

@MainActor
final class CommandPaletteController: NSObject, NSWindowDelegate {
    let panel: CommandPalettePanel
    private let store: AppStore
    private let onOpenSettings: () -> Void
    private let onOpenAbout: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onShowMainWindow: () -> Void
    private let onReloadPage: () -> Void

    init(
        store: AppStore,
        onOpenSettings: @escaping () -> Void,
        onOpenAbout: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onShowMainWindow: @escaping () -> Void,
        onReloadPage: @escaping () -> Void
    ) {
        self.store = store
        self.onOpenSettings = onOpenSettings
        self.onOpenAbout = onOpenAbout
        self.onCheckForUpdates = onCheckForUpdates
        self.onShowMainWindow = onShowMainWindow
        self.onReloadPage = onReloadPage

        let initialRect = NSRect(x: 0, y: 0, width: 540, height: 390)
        self.panel = CommandPalettePanel(contentRect: initialRect)
        super.init()

        self.panel.delegate = self

        let root = CommandPaletteView(
            store: store,
            actionsProvider: { [weak self] query in
                self?.buildActions(for: query) ?? []
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.safeAreaRegions = []
        hosting.sizingOptions = []
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        self.panel.contentView = hosting
    }

    func toggle(relativeTo anchorWindow: NSWindow?) {
        if panel.isVisible {
            close()
        } else {
            open(relativeTo: anchorWindow)
        }
    }

    func open(relativeTo anchorWindow: NSWindow?) {
        store.commandQuery = ""
        store.commandSelectedIndex = 0
        store.isCommandPaletteOpen = true

        let w: CGFloat = 540
        let h: CGFloat = 390
        if let anchor = anchorWindow, anchor.isVisible {
            let f = anchor.frame
            let x = f.midX - w / 2
            let y = f.maxY - h - 78
            panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        } else if let screen = NSScreen.main?.visibleFrame {
            let x = screen.midX - w / 2
            let y = screen.maxY - h - 110
            panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        store.commandFocusToken += 1
    }

    func close() {
        store.isCommandPaletteOpen = false
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        if panel.isVisible {
            close()
        }
    }

    private func buildActions(for rawQuery: String) -> [PaletteAction] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let qLower = query.lowercased()

        let baseActions: [PaletteAction] = [
            PaletteAction(
                id: "nav-home",
                title: "Go to Home",
                subtitle: "Open YouTube Music Home feed",
                icon: "house",
                shortcut: nil,
                keywords: "home beranda ytm music",
                perform: { [weak self] in
                    self?.onShowMainWindow()
                    self?.store.navigateToYtmPath("/")
                }
            ),
            PaletteAction(
                id: "nav-downloads",
                title: "Go to Downloads (Offline)",
                subtitle: "View downloaded songs & auto-sync offline karaoke lyrics",
                icon: "arrow.down.circle",
                shortcut: nil,
                keywords: "downloads offline unduh sync library",
                perform: { [weak self] in
                    self?.onShowMainWindow()
                    self?.store.navigateToYtmPath("/library/downloads")
                }
            ),
            PaletteAction(
                id: "nav-library",
                title: "Go to Library",
                subtitle: "Open saved albums, playlists & songs",
                icon: "books.vertical",
                shortcut: nil,
                keywords: "library koleksi playlist album",
                perform: { [weak self] in
                    self?.onShowMainWindow()
                    self?.store.navigateToYtmPath("/library")
                }
            ),
            PaletteAction(
                id: "nav-explore",
                title: "Go to Explore",
                subtitle: "Charts, new releases, moods & genres",
                icon: "safari",
                shortcut: nil,
                keywords: "explore charts trending discover",
                perform: { [weak self] in
                    self?.onShowMainWindow()
                    self?.store.navigateToYtmPath("/explore")
                }
            ),
            PaletteAction(
                id: "play-toggle",
                title: store.playback.paused ? "Play Music" : "Pause Music",
                subtitle: store.track.map { "\($0.title) — \($0.artist)" } ?? "Toggle playback",
                icon: store.playback.paused ? "play.fill" : "pause.fill",
                shortcut: nil,
                keywords: "play pause music playback",
                perform: { [weak self] in self?.store.togglePlay() }
            ),
            PaletteAction(
                id: "play-next",
                title: "Next Track",
                subtitle: "Skip to next song",
                icon: "forward.fill",
                shortcut: nil,
                keywords: "next skip track song",
                perform: { [weak self] in self?.store.nextTrack() }
            ),
            PaletteAction(
                id: "play-prev",
                title: "Previous Track",
                subtitle: "Return to previous song",
                icon: "backward.fill",
                shortcut: nil,
                keywords: "previous back track song",
                perform: { [weak self] in self?.store.prevTrack() }
            ),
            PaletteAction(
                id: "toggle-sidebar",
                title: store.isSidebarVisible ? "Hide Lyrics Sidebar" : "Show Lyrics Sidebar",
                subtitle: "Docked resizable karaoke sidebar",
                icon: "sidebar.right",
                shortcut: "⇧⌘S",
                keywords: "lyrics lirik sidebar panel",
                perform: { [weak self] in
                    self?.onShowMainWindow()
                    self?.store.toggleSidebar()
                }
            ),
            PaletteAction(
                id: "toggle-fullscreen-lyrics",
                title: store.isFullScreenLyricsVisible ? "End Full Screen Lyrics" : "Open Full Screen Lyrics",
                subtitle: "Centered karaoke stage with dynamic album art glow",
                icon: store.isFullScreenLyricsVisible ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                shortcut: "⇧⌘F",
                keywords: "fullscreen full screen lyrics lirik centered stage karaoke",
                perform: { [weak self] in
                    guard let self else { return }
                    if !self.store.isFullScreenLyricsVisible {
                        self.onShowMainWindow()
                    }
                    self.store.toggleFullScreenLyrics()
                }
            ),
            PaletteAction(
                id: "toggle-hud",
                title: store.isHudVisible ? "Hide Floating Lyrics" : "Show Floating Lyrics",
                subtitle: "True-transparent floating karaoke overlay",
                icon: "pip.enter",
                shortcut: "⇧⌘L",
                keywords: "floating hud transparent overlay lyrics",
                perform: { [weak self] in self?.store.isHudVisible.toggle() }
            ),
            PaletteAction(
                id: "toggle-mini",
                title: store.isMiniPlayerVisible ? "Hide Mini Player" : "Show Mini Player",
                subtitle: "Compact floating Apple Music-style widget",
                icon: "rectangle.inset.bottomright.filled",
                shortcut: "⇧⌘P",
                keywords: "mini player widget compact floating",
                perform: { [weak self] in self?.store.isMiniPlayerVisible.toggle() }
            ),
            PaletteAction(
                id: "toggle-menubar-lyrics",
                title: store.menuBarLyricsEnabled ? "Turn Off Menu Bar Lyrics" : "Turn On Menu Bar Lyrics",
                subtitle: "Live 1-line lyrics in macOS top Menu Bar",
                icon: "music.mic",
                shortcut: "⇧⌘B",
                keywords: "menu bar menubar top bar live lyrics",
                perform: { [weak self] in self?.store.menuBarLyricsEnabled.toggle() }
            ),
            PaletteAction(
                id: "toggle-translate",
                title: store.translateEnabled ? "Turn Off Smart Translate" : "Turn On Smart Translate",
                subtitle: "Current: \(store.translateSource.shortCode) → \(store.translateTarget.shortCode)",
                icon: "character.bubble",
                shortcut: "⇧⌘E",
                keywords: "translate terjemahan bahasa indo english",
                perform: { [weak self] in self?.store.translateEnabled.toggle() }
            ),
            PaletteAction(
                id: "translate-id",
                title: "Translate Lyrics to Indonesian (ID)",
                subtitle: "Auto-hides for Indonesian songs",
                icon: "globe.asia.australia",
                shortcut: nil,
                keywords: "translate indonesia indo id terjemahan",
                perform: { [weak self] in
                    self?.store.translateTarget = .indonesian
                    self?.store.translateEnabled = true
                }
            ),
            PaletteAction(
                id: "translate-en",
                title: "Translate Lyrics to English (EN)",
                subtitle: "Auto-hides for English songs",
                icon: "globe",
                shortcut: nil,
                keywords: "translate english inggris en",
                perform: { [weak self] in
                    self?.store.translateTarget = .english
                    self?.store.translateEnabled = true
                }
            ),
            PaletteAction(
                id: "toggle-romaji",
                title: store.autoRomanizeEnabled ? "Turn Off Auto Romaji" : "Turn On Auto Romaji",
                subtitle: "Offline Korean, Japanese & Mandarin pronunciation",
                icon: "textformat.abc",
                shortcut: "⇧⌘R",
                keywords: "romaji romanize korean japanese pinyin",
                perform: { [weak self] in self?.store.autoRomanizeEnabled.toggle() }
            ),
            PaletteAction(
                id: "offline-save-current",
                title: "Save Current Track Lyrics Offline",
                subtitle: store.isCurrentTrackOfflineSaved ? "Already saved in Offline Vault" : "Pin lyrics & translation permanently",
                icon: "arrow.down.circle",
                shortcut: "⇧⌘D",
                keywords: "save offline download vault pin current",
                perform: { [weak self] in self?.store.saveCurrentTrackOffline() }
            ),
            PaletteAction(
                id: "offline-sync-page",
                title: "Download Offline Lyrics for This Page",
                subtitle: "Scan visible album, playlist or Downloads list",
                icon: "square.and.arrow.down.on.square",
                shortcut: "⇧⌘O",
                keywords: "download offline page album playlist sync vault",
                perform: { [weak self] in self?.store.downloadOfflineLyricsForCurrentPage() }
            ),
            PaletteAction(
                id: "font-switch",
                title: store.fontStyle == .roboto ? "Switch Font to SF Pro (macOS Native)" : "Switch Font to Roboto (YouTube Music)",
                subtitle: "Current font: \(store.fontStyle.displayLabel)",
                icon: "textformat",
                shortcut: nil,
                keywords: "font roboto sf pro typography huruf",
                perform: { [weak self] in
                    guard let self else { return }
                    self.store.fontStyle = self.store.fontStyle == .roboto ? .sfPro : .roboto
                }
            ),
            PaletteAction(
                id: "toggle-visualizer",
                title: store.audioVisualizerEnabled ? "Hide Audio Visualizer" : "Show Audio Visualizer",
                subtitle: "Theme-colored mini equalizer bars",
                icon: "waveform",
                shortcut: nil,
                keywords: "visualizer equalizer bars waveform",
                perform: { [weak self] in self?.store.audioVisualizerEnabled.toggle() }
            ),
            PaletteAction(
                id: "switch-platform",
                title: store.siteMode == .youtubeMusic ? "Switch to YouTube" : "Switch to YouTube Music",
                subtitle: "Toggle between music.youtube.com and www.youtube.com",
                icon: "arrow.left.arrow.right",
                shortcut: nil,
                keywords: "switch platform youtube music video",
                perform: { [weak self] in
                    guard let self else { return }
                    self.onShowMainWindow()
                    self.store.switchSite(to: self.store.siteMode == .youtubeMusic ? .youtube : .youtubeMusic)
                }
            ),
            PaletteAction(
                id: "open-settings",
                title: "Open Settings",
                subtitle: "Font, Launch at Login, Translate & Offline Vault",
                icon: "gearshape",
                shortcut: "⌘,",
                keywords: "settings preferences pengaturan launch login",
                perform: { [weak self] in self?.onOpenSettings() }
            ),
            PaletteAction(
                id: "check-updates",
                title: "Check for Updates",
                subtitle: "Check GitHub Releases for newer macOS DMG",
                icon: "arrow.triangle.2.circlepath",
                shortcut: nil,
                keywords: "update upgrade version github release dmg",
                perform: { [weak self] in self?.onCheckForUpdates() }
            ),
            PaletteAction(
                id: "open-about",
                title: "About \(AppIdentity.appName)",
                subtitle: "Developer (\(AppIdentity.developerName)) & GitHub Repo",
                icon: "info.circle",
                shortcut: nil,
                keywords: "about developer github author ravi info",
                perform: { [weak self] in self?.onOpenAbout() }
            ),
            PaletteAction(
                id: "reload-page",
                title: "Reload Player Page",
                subtitle: "Refresh YouTube Music view",
                icon: "arrow.clockwise",
                shortcut: "⌘R",
                keywords: "reload refresh page",
                perform: { [weak self] in self?.onReloadPage() }
            ),
        ]

        var matched: [PaletteAction]
        if qLower.isEmpty {
            matched = baseActions
        } else {
            let tokens = qLower.split(separator: " ").map(String.init)
            matched = baseActions.filter { item in
                let haystack = "\(item.title) \(item.subtitle) \(item.keywords)".lowercased()
                return tokens.allSatisfy { haystack.contains($0) }
            }
        }

        // Whenever user types any query, offer instant 1-Enter search on YouTube Music / YouTube!
        if !query.isEmpty {
            let searchTarget = store.siteMode == .youtubeMusic ? "YouTube Music" : "YouTube"
            let searchAction = PaletteAction(
                id: "web-search-\(query)",
                title: "Search \(searchTarget) for \"\(query)\"",
                subtitle: "Press Enter to search songs, artists, or albums directly",
                icon: "magnifyingglass",
                shortcut: "↵",
                keywords: query,
                perform: { [weak self] in
                    self?.onShowMainWindow()
                    self?.store.searchInWeb(query)
                }
            )
            if matched.isEmpty {
                matched.insert(searchAction, at: 0)
            } else {
                matched.append(searchAction)
            }
        }

        return matched
    }
}

/// Native AppKit NSTextField wrapper providing instant auto-focus and arrow/Enter/Esc key handling without SwiftUI macros.
struct PaletteInputField: NSViewRepresentable {
    @Binding var text: String
    let focusToken: Int
    let placeholder: String
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        field.textColor = .white
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.42),
                .font: NSFont.systemFont(ofSize: 15, weight: .regular),
            ]
        )
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.currentEditor()?.moveToEndOfLine(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PaletteInputField
        var lastFocusToken: Int = -1

        init(_ parent: PaletteInputField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onMoveUp()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onMoveDown()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

struct CommandPaletteView: View {
    @ObservedObject var store: AppStore
    let actionsProvider: (String) -> [PaletteAction]
    let onClose: () -> Void

    var body: some View {
        let items = actionsProvider(store.commandQuery)
        let safeIndex = items.isEmpty ? 0 : max(0, min(items.count - 1, store.commandSelectedIndex))

        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.88)

            Color(red: 0.062, green: 0.062, blue: 0.090).opacity(0.90)

            VStack(spacing: 0) {
                // Search Input Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(store.palette.accentColor)

                    PaletteInputField(
                        text: $store.commandQuery,
                        focusToken: store.commandFocusToken,
                        placeholder: "Type a command or search songs on YouTube Music...",
                        onMoveUp: {
                            guard !items.isEmpty else { return }
                            store.commandSelectedIndex = max(0, safeIndex - 1)
                        },
                        onMoveDown: {
                            guard !items.isEmpty else { return }
                            store.commandSelectedIndex = min(items.count - 1, safeIndex + 1)
                        },
                        onSubmit: {
                            guard !items.isEmpty else { return }
                            let target = items[safeIndex]
                            onClose()
                            target.perform()
                        },
                        onCancel: onClose
                    )
                    .frame(height: 24)

                    Text("ESC")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(Color.white.opacity(0.09))
                    .frame(height: 1)

                // Results List
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, action in
                                let selected = idx == safeIndex
                                Button {
                                    onClose()
                                    action.perform()
                                } label: {
                                    HStack(spacing: 11) {
                                        Image(systemName: action.icon)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(selected ? store.palette.accentColor : .white.opacity(0.66))
                                            .frame(width: 26, height: 26)
                                            .background(selected ? store.palette.accentColor.opacity(0.18) : Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(action.title)
                                                .font(AppFont.styled(13, weight: .medium, style: store.fontStyle))
                                                .foregroundStyle(.white.opacity(selected ? 0.98 : 0.86))
                                                .lineLimit(1)
                                            Text(action.subtitle)
                                                .font(.system(size: 10.5))
                                                .foregroundStyle(.white.opacity(selected ? 0.62 : 0.44))
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: 8)

                                        if let shortcut = action.shortcut {
                                            Text(shortcut)
                                                .font(.system(size: 10, weight: .semibold).monospaced())
                                                .foregroundStyle(.white.opacity(selected ? 0.86 : 0.48))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(Color.white.opacity(selected ? 0.12 : 0.06))
                                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(selected ? store.palette.accentColor.opacity(0.14) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(selected ? store.palette.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(idx)
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: store.commandSelectedIndex) { _, newIdx in
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(newIdx, anchor: .center)
                        }
                    }
                    .onChange(of: store.commandQuery) { _, _ in
                        store.commandSelectedIndex = 0
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .frame(width: 540, height: 390)
    }
}
