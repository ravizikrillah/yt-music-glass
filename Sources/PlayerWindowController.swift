import AppKit
import SwiftUI
import WebKit

private let SAFARI_MAC_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"

struct PlayerToolbarView: View {
    @ObservedObject var store: AppStore
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onResetHudPosition: () -> Void
    let onOpenCommandPalette: () -> Void
    let onOpenSettings: () -> Void
    let onOpenAbout: () -> Void

    var body: some View {
        ZStack {
            // Seamless pure dark titlebar matching YouTube Music's native web canvas (#030303)
            Color(red: 0.012, green: 0.012, blue: 0.012)

            // Drag window smoothly from any empty region of the unified titlebar
            WindowDragHandle()

            HStack(spacing: 8) {
                // Grouped Obsidian Glass navigation capsule after macOS traffic lights
                HStack(spacing: 1) {
                    navCapsuleIcon("chevron.left", help: "Back", action: onBack)
                    navCapsuleIcon("chevron.right", help: "Forward", action: onForward)
                    Rectangle()
                        .fill(Color.white.opacity(0.09))
                        .frame(width: 1, height: 14)
                        .padding(.horizontal, 2)
                    navCapsuleIcon("arrow.clockwise", help: "Reload Page", action: onReload)
                }
                .padding(.horizontal, 4)
                .frame(height: 28)
                .background(obsidianPillSurface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))

                // Quick Command Palette button (⌘K)
                Button(action: onOpenCommandPalette) {
                    HStack(spacing: 4) {
                        Image(systemName: "command")
                            .font(.system(size: 10, weight: .semibold))
                        Text("K")
                            .font(.system(size: 10.5, weight: .semibold).monospaced())
                    }
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(obsidianPillSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Quick Command Palette & Song Search (⌘K)")

                updateToolbarPill

                Spacer(minLength: 8)

                // Centered Obsidian Glass platform switcher capsule
                HStack(spacing: 2) {
                    siteTabButton(.youtubeMusic)
                    siteTabButton(.youtube)
                }
                .padding(3)
                .frame(height: 28)
                .background(obsidianPillSurface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))

                Spacer(minLength: 8)

                // Subtle Offline Lyrics Sync Progress Pill (appears only while downloading offline lyrics)
                if store.offlineSyncActive && store.offlineSyncTotal > 0 {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.60)
                            .tint(store.palette.accentColor)
                        Text("Offline \(min(store.offlineSyncCompleted, store.offlineSyncTotal))/\(store.offlineSyncTotal)")
                            .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(store.palette.accentColor.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(store.palette.accentColor.opacity(0.32), lineWidth: 1))
                    .help("Saving synced lyrics locally for offline karaoke")
                }

                // Smart Translate Toggle + Source->Target Language Selector (single seamless capsule, 1 clean chevron)
                HStack(spacing: 0) {
                    Button {
                        store.translateEnabled.toggle()
                    } label: {
                        HStack(spacing: 5) {
                            if store.isTranslating {
                                ProgressView()
                                    .controlSize(.mini)
                                    .scaleEffect(0.62)
                                    .tint(.white)
                            } else {
                                Image(systemName: "character.bubble")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(store.translateEnabled ? store.palette.accentColor : .white.opacity(0.76))
                            }
                            Text(store.translateEnabled ? "Translate" : "Translate")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(store.translateEnabled ? .white.opacity(0.96) : .white.opacity(0.80))
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 8)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Smart Lyrics Translation (⇧⌘E — auto-hides when song matches target language)")

                    Rectangle()
                        .fill(store.translateEnabled ? store.palette.accentColor.opacity(0.28) : Color.white.opacity(0.10))
                        .frame(width: 1, height: 14)

                    Menu {
                        if !store.detectedSongLanguage.isEmpty {
                            let detectedLabel = store.isTranslationSkippedSameLanguage
                                ? "Song: \(store.detectedSongLanguage.uppercased()) (same as target · hidden)"
                                : "Detected song: \(store.detectedSongLanguage.uppercased())"
                            Text(detectedLabel)
                            Divider()
                        }

                        Menu("From: \(store.translateSource.displayName)") {
                            ForEach(TranslateSourceLanguage.allCases) { src in
                                Button {
                                    store.translateSource = src
                                } label: {
                                    if store.translateSource == src {
                                        Label(src.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(src.displayName)
                                    }
                                }
                            }
                        }

                        Menu("To: \(store.translateTarget.displayName)") {
                            ForEach(TranslateTargetLanguage.allCases) { dst in
                                Button {
                                    store.translateTarget = dst
                                    if !store.translateEnabled {
                                        store.translateEnabled = true
                                    }
                                } label: {
                                    if store.translateTarget == dst {
                                        Label(dst.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(dst.displayName)
                                    }
                                }
                            }
                        }

                        Divider()

                        Button {
                            store.autoRomanizeEnabled.toggle()
                        } label: {
                            if store.autoRomanizeEnabled {
                                Label("Auto Romaji / Romanization", systemImage: "checkmark")
                            } else {
                                Text("Auto Romaji / Romanization")
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("\(store.translateSource.shortCode)→\(store.translateTarget.shortCode)")
                                .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .opacity(0.75)
                        }
                        .foregroundStyle(store.translateEnabled ? .white.opacity(0.92) : .white.opacity(0.72))
                        .padding(.leading, 8)
                        .padding(.trailing, 10)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Choose source/target translation languages & Auto Romaji")
                }
                .background(
                    store.translateEnabled
                        ? store.palette.accentColor.opacity(0.20)
                        : obsidianPillSurface
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        store.translateEnabled
                            ? store.palette.accentColor.opacity(0.45)
                            : Color.white.opacity(0.11),
                        lineWidth: 1
                    )
                )

                // Button 1: Docked Right Sidebar Lyrics (Soft Tinted Obsidian Glass — matches Player Bar Lyrics button)
                toolbarTogglePill(
                    icon: "sidebar.right",
                    label: "Lyrics",
                    active: store.isSidebarVisible,
                    help: "Toggle Docked Right Lyrics Sidebar (⇧⌘S / Shift+L)"
                ) {
                    store.toggleSidebar()
                }

                // Button 2: Separate Transparent Floating Lyrics Window (same unified Obsidian Glass language)
                toolbarTogglePill(
                    icon: store.isHudVisible ? "pip.exit" : "pip.enter",
                    label: store.isHudVisible ? "Floating" : "Float",
                    active: store.isHudVisible,
                    help: "Open / Hide Separate Transparent Floating Lyrics Window (⇧⌘L)"
                ) {
                    store.isHudVisible.toggle()
                }

                // Button 3: Apple Music-style Floating Mini Player
                Button {
                    store.isMiniPlayerVisible.toggle()
                } label: {
                    Image(systemName: "rectangle.inset.bottomright.filled")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(store.isMiniPlayerVisible ? store.palette.accentColor : .white.opacity(0.76))
                        .frame(width: 28, height: 28)
                        .background(store.isMiniPlayerVisible ? store.palette.accentColor.opacity(0.20) : obsidianPillSurface)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(
                                store.isMiniPlayerVisible ? store.palette.accentColor.opacity(0.45) : Color.white.opacity(0.11),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .help("Toggle Compact Floating Mini Player (⇧⌘P)")

                // Button 4: Native Settings Window (⌘,)
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .frame(width: 28, height: 28)
                        .background(obsidianPillSurface)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Open Settings (⌘,)")

                // Floating window quick controls grouped in one sleek Obsidian Glass capsule
                if store.isHudVisible {
                    HStack(spacing: 6) {
                        Button {
                            store.isClickThrough.toggle()
                        } label: {
                            Image(systemName: store.isClickThrough ? "lock.fill" : "lock.open")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(
                                    store.isClickThrough
                                        ? Color(red: 1.0, green: 0.78, blue: 0.44)
                                        : .white.opacity(0.78)
                                )
                                .frame(width: 22, height: 22)
                                .background(
                                    store.isClickThrough
                                        ? Color.orange.opacity(0.18)
                                        : Color.white.opacity(0.06)
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle().strokeBorder(
                                        store.isClickThrough
                                            ? Color.orange.opacity(0.42)
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .help(store.isClickThrough ? "Unlock Floating Window to drag (⇧⌘K)" : "Lock Click-Through on Floating Window (⇧⌘K)")

                        Slider(value: $store.backgroundOpacity, in: 0.0...0.85)
                            .controlSize(.mini)
                            .frame(width: 58)
                            .tint(store.palette.accentColor)
                            .help("Floating Lyrics Background Opacity (0% = Pure Transparent)")

                        Button(action: onResetHudPosition) {
                            Image(systemName: "scope")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.78))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Reset Floating Lyrics Position")
                    }
                    .padding(.horizontal, 5)
                    .frame(height: 28)
                    .background(obsidianPillSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
                }
            }
            .padding(.leading, 82)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var updateToolbarPill: some View {
        switch store.updateState {
        case .available(let release):
            Button(action: onOpenAbout) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(store.palette.accentColor)
                    Text("Update v\(release.version)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.95))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(store.palette.accentColor.opacity(0.18))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(store.palette.accentColor.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("YT Music Glass v\(release.version) is available — click to download & install")

        case .downloading(let progress, let version):
            Button(action: onOpenAbout) {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.60)
                        .tint(store.palette.accentColor)
                    Text("Downloading \(Int((progress * 100).rounded()))%")
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.90))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(store.palette.accentColor.opacity(0.16))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(store.palette.accentColor.opacity(0.38), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Downloading v\(version) DMG...")

        case .readyToInstall(_, let version):
            Button(action: onOpenAbout) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(store.palette.accentColor)
                    Text("Install v\(version)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.95))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(store.palette.accentColor.opacity(0.22))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(store.palette.accentColor.opacity(0.48), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("v\(version) DMG is ready — click to open installer")

        default:
            EmptyView()
        }
    }

    private var obsidianPillSurface: Color {
        Color(red: 0.095, green: 0.095, blue: 0.138).opacity(0.82)
    }

    private func toolbarTogglePill(
        icon: String,
        label: String,
        active: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? store.palette.accentColor : .white.opacity(0.76))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? .white.opacity(0.96) : .white.opacity(0.80))
            }
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(active ? store.palette.accentColor.opacity(0.20) : obsidianPillSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    active ? store.palette.accentColor.opacity(0.45) : Color.white.opacity(0.11),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func siteTabButton(_ mode: WebSiteMode) -> some View {
        let active = store.siteMode == mode
        return Button {
            store.switchSite(to: mode)
        } label: {
            Text(mode.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? .white.opacity(0.96) : .white.opacity(0.56))
                .padding(.horizontal, 12)
                .frame(height: 22)
                .background(active ? Color.white.opacity(0.14) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(active ? Color.white.opacity(0.12) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func navCapsuleIcon(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

final class SidebarResizeHandleView: NSView {
    var onDragStart: (() -> Void)?
    var onDragTotalDelta: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    private let lineLayer = CALayer()
    private let pillLayer = CALayer()
    private var trackingAreaRef: NSTrackingArea?
    private var startScreenX: CGFloat?
    private var isHovering = false
    private var isDragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.zPosition = 999

        lineLayer.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.addSublayer(lineLayer)

        pillLayer.backgroundColor = NSColor.white.withAlphaComponent(0.28).cgColor
        pillLayer.cornerRadius = 2
        layer?.addSublayer(pillLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lineLayer.frame = CGRect(x: bounds.midX - 0.5, y: 0, width: 1.5, height: bounds.height)
        let pillH: CGFloat = 38
        pillLayer.frame = CGRect(x: bounds.midX - 2, y: (bounds.height - pillH) / 2, width: 4, height: pillH)
        CATransaction.commit()
    }

    private func updateVisualState() {
        if isDragging {
            lineLayer.backgroundColor = NSColor.white.withAlphaComponent(0.42).cgColor
            pillLayer.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
        } else if isHovering {
            lineLayer.backgroundColor = NSColor.white.withAlphaComponent(0.24).cgColor
            pillLayer.backgroundColor = NSColor.white.withAlphaComponent(0.68).cgColor
        } else {
            lineLayer.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            pillLayer.backgroundColor = NSColor.white.withAlphaComponent(0.28).cgColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        NSCursor.resizeLeftRight.set()
        updateVisualState()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateVisualState()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        isDragging = true
        startScreenX = NSEvent.mouseLocation.x
        updateVisualState()
        NSCursor.resizeLeftRight.set()
        onDragStart?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let originX = startScreenX else { return }
        let totalDx = NSEvent.mouseLocation.x - originX
        onDragTotalDelta?(totalDx)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        startScreenX = nil
        updateVisualState()
        onDragEnded?()
    }
}

@MainActor
final class PlayerWindowController: NSObject, NSWindowDelegate, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
    let window: NSWindow
    let webView: WKWebView
    private let store: AppStore
    private let sidebarHost: NSHostingView<SidebarLyricsView>
    private let fullScreenHost: NSHostingView<FullScreenLyricsView>
    private let resizeHandle = SidebarResizeHandleView(frame: .zero)
    private var sidebarWidthConstraint: NSLayoutConstraint!
    private var dragStartSidebarWidth: CGFloat = 380
    private var popupWindows: [ObjectIdentifier: NSWindow] = [:]
    private var fullScreenEventMonitor: Any? = nil
    private var enteredNativeFullScreenFromLyrics: Bool = false
    private var fullScreenHideGeneration: Int = 0

    private static let defaultSidebarWidth: CGFloat = 380
    private static let minSidebarWidth: CGFloat = 260
    private static let minWebWidth: CGFloat = 440

    init(
        store: AppStore,
        onResetHudPosition: @escaping () -> Void,
        onOpenCommandPalette: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenAbout: @escaping () -> Void
    ) {
        self.store = store

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let userContent = WKUserContentController()
        // 1. Inject Apple Music / macOS Liquid Glass reskin immediately at document start
        let themeScript = WKUserScript(
            source: ThemeStyles.installerScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContent.addUserScript(themeScript)

        // 2. Inject real-time playback & metadata bridge
        let bridgeScript = WKUserScript(
            source: WebBridgeScript.source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContent.addUserScript(bridgeScript)
        config.userContentController = userContent

        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.customUserAgent = SAFARI_MAC_USER_AGENT
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.setValue(false, forKey: "drawsBackground")

        self.sidebarHost = NSHostingView(rootView: SidebarLyricsView(store: store))
        self.fullScreenHost = NSHostingView(rootView: FullScreenLyricsView(store: store))

        // Unified native macOS frameless-feel window (traffic lights integrated into our glass header)
        let rect = NSRect(x: 0, y: 0, width: 1280, height: 800)
        self.window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.window.title = "YT Music Glass"
        self.window.titleVisibility = .hidden
        self.window.titlebarAppearsTransparent = true
        self.window.collectionBehavior.insert(.fullScreenPrimary)
        self.window.isMovableByWindowBackground = false
        self.window.appearance = NSAppearance(named: .darkAqua)
        self.window.backgroundColor = NSColor(red: 0.012, green: 0.012, blue: 0.012, alpha: 1.0)
        self.window.minSize = NSSize(width: 780, height: 520)
        self.window.center()
        self.window.setFrameAutosaveName("YTMusicGlassMainWindow")

        super.init()

        self.window.delegate = self
        self.webView.uiDelegate = self
        self.webView.navigationDelegate = self
        userContent.add(self, name: "ytmgBridge")

        let container = NSView()
        container.wantsLayer = true

        let toolbarHost = NSHostingView(
            rootView: PlayerToolbarView(
                store: store,
                onBack: { [weak self] in self?.webView.goBack() },
                onForward: { [weak self] in self?.webView.goForward() },
                onReload: { [weak self] in self?.webView.reload() },
                onResetHudPosition: onResetHudPosition,
                onOpenCommandPalette: onOpenCommandPalette,
                onOpenSettings: onOpenSettings,
                onOpenAbout: onOpenAbout
            )
        )
        toolbarHost.safeAreaRegions = []
        toolbarHost.sizingOptions = []
        toolbarHost.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false

        // Critical on macOS 14+: disable NSHostingView intrinsic/minSize Auto Layout propagation
        // so SwiftUI content (artwork, long lyrics, footer) NEVER overrides sidebarWidthConstraint!
        sidebarHost.safeAreaRegions = []
        sidebarHost.sizingOptions = []
        sidebarHost.translatesAutoresizingMaskIntoConstraints = false
        sidebarHost.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sidebarHost.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        resizeHandle.translatesAutoresizingMaskIntoConstraints = false

        fullScreenHost.safeAreaRegions = []
        fullScreenHost.sizingOptions = []
        fullScreenHost.translatesAutoresizingMaskIntoConstraints = false
        fullScreenHost.wantsLayer = true
        fullScreenHost.layer?.zPosition = 2000
        fullScreenHost.alphaValue = 0.0
        fullScreenHost.isHidden = true

        container.addSubview(toolbarHost)
        container.addSubview(webView)
        container.addSubview(sidebarHost)
        container.addSubview(resizeHandle)
        container.addSubview(fullScreenHost)

        let clampedInitial = clampSidebarWidth(store.sidebarWidth)
        let initialWidth: CGFloat = store.isSidebarVisible ? clampedInitial : 0
        sidebarWidthConstraint = sidebarHost.widthAnchor.constraint(equalToConstant: initialWidth)
        sidebarHost.isHidden = !store.isSidebarVisible
        resizeHandle.isHidden = !store.isSidebarVisible

        NSLayoutConstraint.activate([
            toolbarHost.topAnchor.constraint(equalTo: container.topAnchor),
            toolbarHost.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            toolbarHost.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbarHost.heightAnchor.constraint(equalToConstant: 48),

            webView.topAnchor.constraint(equalTo: toolbarHost.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: sidebarHost.leadingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            sidebarHost.topAnchor.constraint(equalTo: toolbarHost.bottomAnchor),
            sidebarHost.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sidebarHost.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            sidebarWidthConstraint,

            resizeHandle.topAnchor.constraint(equalTo: toolbarHost.bottomAnchor),
            resizeHandle.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            resizeHandle.centerXAnchor.constraint(equalTo: sidebarHost.leadingAnchor),
            resizeHandle.widthAnchor.constraint(equalToConstant: 14),

            fullScreenHost.topAnchor.constraint(equalTo: container.topAnchor),
            fullScreenHost.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            fullScreenHost.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            fullScreenHost.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        resizeHandle.onDragStart = { [weak self] in
            guard let self else { return }
            self.dragStartSidebarWidth = self.sidebarWidthConstraint.constant
        }
        resizeHandle.onDragTotalDelta = { [weak self] totalDx in
            guard let self, self.store.isSidebarVisible else { return }
            // Dragging divider left (negative totalDx) widens the right sidebar 1:1 with cursor
            let next = self.clampSidebarWidth(self.dragStartSidebarWidth - totalDx)
            self.sidebarWidthConstraint.constant = next
            self.window.contentView?.layoutSubtreeIfNeeded()
        }
        resizeHandle.onDragEnded = { [weak self] in
            guard let self, self.store.isSidebarVisible else { return }
            self.store.sidebarWidth = self.sidebarWidthConstraint.constant
        }
        resizeHandle.onDoubleClick = { [weak self] in
            guard let self, self.store.isSidebarVisible else { return }
            let target = self.clampSidebarWidth(Self.defaultSidebarWidth)
            self.store.sidebarWidth = target
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.allowsImplicitAnimation = true
                self.sidebarWidthConstraint.animator().constant = target
                self.window.contentView?.layoutSubtreeIfNeeded()
            }
        }

        self.window.contentView = container

        store.onPlayerCommand = { [weak self] action, value in
            self?.sendPlayerCommand(action: action, value: value)
        }
        store.onSwitchSite = { [weak self] mode in
            self?.load(url: mode.homeURL)
        }
        store.onSidebarVisibilityChanged = { [weak self] visible in
            self?.setSidebarVisible(visible, animated: true)
        }
        store.onFullScreenLyricsVisibilityChanged = { [weak self] visible in
            self?.setFullScreenLyricsVisible(visible, animated: true)
        }
        store.onToggleNativeWindowFullScreen = { [weak self] in
            self?.toggleNativeWindowFullScreenFromLyrics()
        }
        store.onSyncSidebarButtonState = { [weak self] visible in
            self?.syncInPageSidebarButton(visible)
        }
        store.onThemeChanged = { [weak self] enabled in
            self?.pushThemeState(enabled)
        }
        store.onFontStyleChanged = { [weak self] style in
            self?.pushFontStyle(style)
        }
        store.onPaletteChanged = { [weak self] palette in
            self?.pushPaletteToWeb(palette)
        }
        store.onScanOfflinePage = { [weak self] in
            self?.scanOfflinePageInWeb()
        }
        store.onNavigateURL = { [weak self] url in
            self?.load(url: url)
        }

        installFullScreenEventMonitor()
        load(url: store.siteMode.homeURL)
    }

    private func clampSidebarWidth(_ desired: CGFloat) -> CGFloat {
        let winWidth = window.contentLayoutRect.width > 0 ? window.contentLayoutRect.width : window.frame.width
        let maxAllowed = max(Self.minSidebarWidth, min(760, winWidth - Self.minWebWidth))
        return max(Self.minSidebarWidth, min(maxAllowed, desired))
    }

    private func setSidebarVisible(_ visible: Bool, animated: Bool) {
        let targetWidth: CGFloat = visible ? clampSidebarWidth(store.sidebarWidth) : 0
        if visible {
            sidebarHost.isHidden = false
            resizeHandle.isHidden = store.isFullScreenLyricsVisible
        } else {
            resizeHandle.isHidden = true
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.24
                ctx.allowsImplicitAnimation = true
                sidebarWidthConstraint.animator().constant = targetWidth
                window.contentView?.layoutSubtreeIfNeeded()
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    if !visible {
                        self?.sidebarHost.isHidden = true
                    }
                }
            })
        } else {
            sidebarWidthConstraint.constant = targetWidth
            sidebarHost.isHidden = !visible
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard store.isSidebarVisible else { return }
        let clamped = clampSidebarWidth(sidebarWidthConstraint.constant)
        if abs(clamped - sidebarWidthConstraint.constant) > 0.5 {
            sidebarWidthConstraint.constant = clamped
        }
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        store.isNativeWindowFullScreen = true
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        store.isNativeWindowFullScreen = false
        enteredNativeFullScreenFromLyrics = false
    }

    private func toggleNativeWindowFullScreenFromLyrics() {
        let isCurrentlyFull = window.styleMask.contains(.fullScreen)
        if !isCurrentlyFull {
            enteredNativeFullScreenFromLyrics = true
        } else {
            enteredNativeFullScreenFromLyrics = false
        }
        window.toggleFullScreen(nil)
    }

    private func setFullScreenLyricsVisible(_ visible: Bool, animated: Bool) {
        fullScreenHideGeneration &+= 1
        let currentGen = fullScreenHideGeneration

        if visible {
            resizeHandle.isHidden = true
            fullScreenHost.isHidden = false
            if animated {
                store.isFullScreenLyricsStagePresented = false
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.34
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    fullScreenHost.animator().alphaValue = 1.0
                }
                DispatchQueue.main.async { [weak self] in
                    self?.store.isFullScreenLyricsStagePresented = true
                }
            } else {
                fullScreenHost.alphaValue = 1.0
                store.isFullScreenLyricsStagePresented = true
            }
        } else {
            // Smooth exit from Full Screen -> End Full Screen
            store.isFullScreenLyricsStagePresented = false

            if enteredNativeFullScreenFromLyrics && window.styleMask.contains(.fullScreen) {
                enteredNativeFullScreenFromLyrics = false
                window.toggleFullScreen(nil)
            }

            if animated {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.28
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    fullScreenHost.animator().alphaValue = 0.0
                }, completionHandler: { [weak self] in
                    Task { @MainActor in
                        guard let self, self.fullScreenHideGeneration == currentGen, !self.store.isFullScreenLyricsVisible else {
                            return
                        }
                        self.fullScreenHost.isHidden = true
                        self.resizeHandle.isHidden = !self.store.isSidebarVisible
                    }
                })
            } else {
                fullScreenHost.alphaValue = 0.0
                fullScreenHost.isHidden = true
                resizeHandle.isHidden = !store.isSidebarVisible
            }
        }
    }

    private func installFullScreenEventMonitor() {
        fullScreenEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDown, .scrollWheel]) { [weak self] event in
            guard let self else { return event }
            guard self.store.isFullScreenLyricsVisible else { return event }

            switch event.type {
            case .mouseMoved, .leftMouseDown, .scrollWheel:
                if event.window == self.window {
                    self.store.notifyFullScreenUserActivity()
                }
                return event
            case .keyDown:
                // Escape key (keyCode 53) smoothly closes Picker first, then exits Full Screen Lyrics
                if event.keyCode == 53 {
                    if self.store.isPickerOpen {
                        self.store.closePicker()
                    } else {
                        self.store.exitFullScreenLyrics()
                    }
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }

    private func syncInPageSidebarButton(_ visible: Bool) {
        let js = "window.__ytmgSetSidebarActive && window.__ytmgSetSidebarActive(\(visible ? "true" : "false"));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func pushThemeState(_ enabled: Bool) {
        let js = "window.__ytmgSetTheme && window.__ytmgSetTheme(\(enabled ? "true" : "false"));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func pushFontStyle(_ style: AppFontStyle) {
        let js = "window.__ytmgSetFontStyle && window.__ytmgSetFontStyle('\(style.rawValue)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func pushPaletteToWeb(_ palette: AlbumPalette) {
        let safeArt = (palette.artworkUrl ?? "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "'", with: "")
        let artArg = safeArt.isEmpty ? "null" : "'\(safeArt)'"
        let js = "window.__ytmgSetPalette && window.__ytmgSetPalette('\(palette.accentRGBString)', '\(palette.bgTopHex)', '\(palette.bgBottomHex)', \(artArg));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func scanOfflinePageInWeb() {
        let js = "window.__ytmgScanOfflinePage && window.__ytmgScanOfflinePage();"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    func reload() {
        webView.reload()
    }

    private func sendPlayerCommand(action: String, value: Double?) {
        let arg = value.map { String($0) } ?? "null"
        let escapedAction = action.replacingOccurrences(of: "'", with: "")
        let js = "window.__ytmgCmd && window.__ytmgCmd('\(escapedAction)', \(arg));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pushThemeState(store.appleGlassThemeEnabled)
        pushFontStyle(store.fontStyle)
        pushPaletteToWeb(store.palette)
        syncInPageSidebarButton(store.isSidebarVisible)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ytmgBridge", let body = message.body as? [String: Any] else {
            return
        }
        store.handleWebBridgeMessage(body)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let popupWebView = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 660), configuration: configuration)
        popupWebView.customUserAgent = SAFARI_MAC_USER_AGENT
        popupWebView.uiDelegate = self
        popupWebView.navigationDelegate = self

        let popupWin = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 660),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        popupWin.title = "Sign in"
        popupWin.appearance = NSAppearance(named: .darkAqua)
        popupWin.contentView = popupWebView
        popupWin.center()
        popupWin.makeKeyAndOrderFront(nil)

        popupWindows[ObjectIdentifier(popupWebView)] = popupWin
        return popupWebView
    }

    func webViewDidClose(_ webView: WKWebView) {
        let key = ObjectIdentifier(webView)
        if let popupWin = popupWindows.removeValue(forKey: key) {
            popupWin.close()
        }
    }
}
