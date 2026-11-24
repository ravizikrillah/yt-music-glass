import AppKit
import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppStore: ObservableObject {
    @Published var siteMode: WebSiteMode {
        didSet {
            UserDefaults.standard.set(siteMode.rawValue, forKey: "app_site_mode")
        }
    }

    @Published var appleGlassThemeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(appleGlassThemeEnabled, forKey: "app_apple_glass_theme")
            onThemeChanged?(appleGlassThemeEnabled)
        }
    }

    @Published var palette: AlbumPalette = .defaultGlass
    @Published var artworkImage: NSImage? = nil

    // Auto-Romanization & Smart Translate state
    @Published var autoRomanizeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoRomanizeEnabled, forKey: "app_auto_romanize")
        }
    }

    @Published var translateEnabled: Bool {
        didSet {
            UserDefaults.standard.set(translateEnabled, forKey: "app_translate_enabled")
            refreshTranslationForCurrentLyrics()
        }
    }

    @Published var translateSource: TranslateSourceLanguage {
        didSet {
            UserDefaults.standard.set(translateSource.rawValue, forKey: "app_translate_source")
            if translateEnabled {
                refreshTranslationForCurrentLyrics()
            }
        }
    }

    @Published var translateTarget: TranslateTargetLanguage {
        didSet {
            UserDefaults.standard.set(translateTarget.rawValue, forKey: "app_translate_target")
            if translateEnabled {
                refreshTranslationForCurrentLyrics()
            }
        }
    }

    @Published var detectedSongLanguage: String = ""
    @Published var romanizedLines: [String?] = []
    @Published var translatedLines: [String?] = []
    @Published var isTranslating: Bool = false

    // Offline Karaoke Vault state
    @Published var offlineSavedCount: Int = 0
    @Published var isCurrentTrackOfflineSaved: Bool = false
    @Published var offlineSyncActive: Bool = false
    @Published var offlineSyncCompleted: Int = 0
    @Published var offlineSyncTotal: Int = 0

    // Native macOS Pro features: Menu Bar Live Lyrics & Apple Music-style Mini Player
    @Published var menuBarLyricsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(menuBarLyricsEnabled, forKey: "app_menubar_lyrics")
            updateMenuBarLyricDisplay()
            updateTimerState()
        }
    }

    @Published var menuBarLyricText: String = ""

    @Published var isMiniPlayerVisible: Bool = false {
        didSet {
            onMiniPlayerVisibilityChanged?(isMiniPlayerVisible)
            updateTimerState()
        }
    }

    // Appearance, Visualizer, Launch at Login & Command Palette (⌘K)
    @Published var fontStyle: AppFontStyle {
        didSet {
            UserDefaults.standard.set(fontStyle.rawValue, forKey: "app_font_style")
            onFontStyleChanged?(fontStyle)
        }
    }

    @Published var audioVisualizerEnabled: Bool {
        didSet {
            UserDefaults.standard.set(audioVisualizerEnabled, forKey: "app_audio_visualizer")
            updateTimerState()
        }
    }

    @Published var visualizerPhase: Double = 0
    @Published var launchAtLoginEnabled: Bool = false
    @Published var launchAtLoginHint: String = "Start YT Music Glass automatically when you log in"

    @Published var isCommandPaletteOpen: Bool = false
    @Published var commandQuery: String = ""
    @Published var commandSelectedIndex: Int = 0
    @Published var commandFocusToken: Int = 0

    // GitHub Releases Auto-Update state
    @Published var autoCheckUpdatesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckUpdatesEnabled, forKey: "app_auto_check_updates")
        }
    }

    @Published var updateState: UpdateState = .idle

    @Published var status: SessionStatus = .idle
    @Published var track: TrackInfo? = nil
    @Published var playback: PlaybackSnapshot = .idle
    @Published var lyricsSource: LyricsSource? = nil
    @Published var resolvedLyrics: ResolvedLyrics? = nil
    @Published var frame: SyncFrame = .empty
    @Published var playbackProgress: Double = 0
    @Published var offsetMs: Double = 0
    @Published var errorMessage: String? = nil

    @Published var displayMode: HudDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "hud_display_mode")
            onDisplayModeChanged?(displayMode)
        }
    }

    @Published var backgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(backgroundOpacity, forKey: "hud_bg_opacity")
        }
    }

    @Published var fontScale: Double {
        didSet {
            UserDefaults.standard.set(fontScale, forKey: "hud_font_scale")
        }
    }

    @Published var isClickThrough: Bool {
        didSet {
            UserDefaults.standard.set(isClickThrough, forKey: "hud_click_through")
            onClickThroughChanged?(isClickThrough)
        }
    }

    @Published var isSidebarVisible: Bool {
        didSet {
            UserDefaults.standard.set(isSidebarVisible, forKey: "app_sidebar_visible")
            onSidebarVisibilityChanged?(isSidebarVisible)
            onSyncSidebarButtonState?(isSidebarVisible)
            updateTimerState()
        }
    }

    @Published var sidebarWidth: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(sidebarWidth), forKey: "app_sidebar_width")
        }
    }

    @Published var isHudVisible: Bool = false {
        didSet {
            onHudVisibilityChanged?(isHudVisible)
            updateTimerState()
        }
    }

    @Published var isFullScreenLyricsVisible: Bool = false {
        didSet {
            onFullScreenLyricsVisibilityChanged?(isFullScreenLyricsVisible)
            updateTimerState()
        }
    }

    @Published var isFullScreenLyricsStagePresented: Bool = false
    @Published var isNativeWindowFullScreen: Bool = false
    @Published var fullScreenControlsVisible: Bool = true
    @Published var isHoveringFullScreenControls: Bool = false
    private var fullScreenIdleTask: Task<Void, Never>? = nil

    @Published var isHovering: Bool = false

    // Lyrics Picker UI state (kept on ObservableObject to avoid Swift macro plugin requirements)
    @Published var isPickerOpen: Bool = false
    @Published var pickerQuery: String = ""
    @Published var pickerCandidates: [LrclibCandidate] = []
    @Published var isPickerSearching: Bool = false

    var onDisplayModeChanged: ((HudDisplayMode) -> Void)?
    var onClickThroughChanged: ((Bool) -> Void)?
    var onHudVisibilityChanged: ((Bool) -> Void)?
    var onMiniPlayerVisibilityChanged: ((Bool) -> Void)?
    var onSidebarVisibilityChanged: ((Bool) -> Void)?
    var onFullScreenLyricsVisibilityChanged: ((Bool) -> Void)?
    var onToggleNativeWindowFullScreen: (() -> Void)?
    var onPlayerCommand: ((String, Double?) -> Void)?
    var onSwitchSite: ((WebSiteMode) -> Void)?
    var onSyncSidebarButtonState: ((Bool) -> Void)?
    var onThemeChanged: ((Bool) -> Void)?
    var onFontStyleChanged: ((AppFontStyle) -> Void)?
    var onPaletteChanged: ((AlbumPalette) -> Void)?
    var onScanOfflinePage: (() -> Void)?
    var onNavigateURL: ((URL) -> Void)?

    let lyricsService = LyricsService()
    let translationService = TranslationService()
    let updateService = UpdateService()
    let nowPlayingBridge = NowPlayingBridge()
    private let paletteExtractor = ArtworkPaletteExtractor()
    private var updateTask: Task<Void, Never>? = nil

    private var currentCleaned: CleanedTrack? = nil
    private var lastNativeFallback: String? = nil
    private var isCurrentTrackInOfflineContext: Bool = false
    private var fetchTask: Task<Void, Never>? = nil
    private var paletteTask: Task<Void, Never>? = nil
    private var translateTask: Task<Void, Never>? = nil
    private var pickerTask: Task<Void, Never>? = nil
    private var offlineQueue: [CleanedTrack] = []
    private var offlineQueuedKeys: Set<String> = []
    private var offlineWorkerTask: Task<Void, Never>? = nil
    private var loadGeneration: Int = 0
    private var timer: Timer? = nil

    init() {
        AppIdentity.migrateLegacyUserDefaultsIfNeeded()
        let defaults = UserDefaults.standard
        let savedSite = defaults.string(forKey: "app_site_mode") ?? "ytm"
        self.siteMode = WebSiteMode(rawValue: savedSite) ?? .youtubeMusic

        if defaults.object(forKey: "app_apple_glass_theme") != nil {
            self.appleGlassThemeEnabled = defaults.bool(forKey: "app_apple_glass_theme")
        } else {
            self.appleGlassThemeEnabled = true
        }

        if defaults.object(forKey: "app_auto_romanize") != nil {
            self.autoRomanizeEnabled = defaults.bool(forKey: "app_auto_romanize")
        } else {
            self.autoRomanizeEnabled = true
        }

        self.translateEnabled = defaults.bool(forKey: "app_translate_enabled")
        let savedSrc = defaults.string(forKey: "app_translate_source") ?? "auto"
        self.translateSource = TranslateSourceLanguage(rawValue: savedSrc) ?? .auto
        let savedDst = defaults.string(forKey: "app_translate_target") ?? "id"
        self.translateTarget = TranslateTargetLanguage(rawValue: savedDst) ?? .indonesian

        let savedMode = defaults.string(forKey: "hud_display_mode") ?? "compact"
        self.displayMode = HudDisplayMode(rawValue: savedMode) ?? .compact

        if defaults.object(forKey: "hud_bg_opacity") != nil {
            self.backgroundOpacity = SyncCalculator.clamp(defaults.double(forKey: "hud_bg_opacity"), min: 0.0, max: 0.90)
        } else {
            self.backgroundOpacity = 0.28
        }

        if defaults.object(forKey: "hud_font_scale") != nil {
            self.fontScale = SyncCalculator.clamp(defaults.double(forKey: "hud_font_scale"), min: 0.75, max: 1.6)
        } else {
            self.fontScale = 1.0
        }

        self.isClickThrough = defaults.bool(forKey: "hud_click_through")
        if defaults.object(forKey: "app_sidebar_visible") != nil {
            self.isSidebarVisible = defaults.bool(forKey: "app_sidebar_visible")
        } else {
            self.isSidebarVisible = false
        }

        if defaults.object(forKey: "app_sidebar_width") != nil {
            let savedW = defaults.double(forKey: "app_sidebar_width")
            self.sidebarWidth = CGFloat(SyncCalculator.clamp(savedW, min: 260, max: 760))
        } else {
            self.sidebarWidth = 380
        }

        if defaults.object(forKey: "app_menubar_lyrics") != nil {
            self.menuBarLyricsEnabled = defaults.bool(forKey: "app_menubar_lyrics")
        } else {
            self.menuBarLyricsEnabled = true
        }

        let savedFont = defaults.string(forKey: "app_font_style") ?? "roboto"
        self.fontStyle = AppFontStyle(rawValue: savedFont) ?? .roboto

        if defaults.object(forKey: "app_audio_visualizer") != nil {
            self.audioVisualizerEnabled = defaults.bool(forKey: "app_audio_visualizer")
        } else {
            self.audioVisualizerEnabled = true
        }

        if defaults.object(forKey: "app_auto_check_updates") != nil {
            self.autoCheckUpdatesEnabled = defaults.bool(forKey: "app_auto_check_updates")
        } else {
            self.autoCheckUpdatesEnabled = true
        }

        self.offlineSavedCount = self.lyricsService.offlineCount()
        refreshLaunchAtLoginStatus()

        if self.autoCheckUpdatesEnabled {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self?.checkForUpdates(userInitiated: false)
            }
        }

        nowPlayingBridge.configure(
            onPlay: { [weak self] in self?.playOnly() },
            onPause: { [weak self] in self?.pauseOnly() },
            onTogglePlay: { [weak self] in self?.togglePlay() },
            onNext: { [weak self] in self?.nextTrack() },
            onPrev: { [weak self] in self?.prevTrack() },
            onSeek: { [weak self] sec in self?.seekToRawTime(sec) }
        )
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func toggleFullScreenLyrics() {
        if isFullScreenLyricsVisible {
            exitFullScreenLyrics()
        } else {
            enterFullScreenLyrics()
        }
    }

    func enterFullScreenLyrics() {
        guard !isFullScreenLyricsVisible else { return }
        fullScreenControlsVisible = true
        isFullScreenLyricsVisible = true
        scheduleFullScreenControlsAutoHide()
    }

    func exitFullScreenLyrics() {
        fullScreenIdleTask?.cancel()
        fullScreenIdleTask = nil
        if isPickerOpen {
            closePicker()
        }
        guard isFullScreenLyricsVisible else { return }
        isFullScreenLyricsVisible = false
    }

    func toggleNativeWindowFullScreen() {
        onToggleNativeWindowFullScreen?()
    }

    func notifyFullScreenUserActivity() {
        if !fullScreenControlsVisible {
            fullScreenControlsVisible = true
        }
        scheduleFullScreenControlsAutoHide()
    }

    func setFullScreenControlsHovering(_ hovering: Bool) {
        isHoveringFullScreenControls = hovering
        if hovering {
            fullScreenControlsVisible = true
            fullScreenIdleTask?.cancel()
        } else {
            scheduleFullScreenControlsAutoHide()
        }
    }

    func scheduleFullScreenControlsAutoHide() {
        fullScreenIdleTask?.cancel()
        guard isFullScreenLyricsVisible, !playback.paused, !isPickerOpen, !isHoveringFullScreenControls else {
            fullScreenControlsVisible = true
            return
        }
        fullScreenIdleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.isFullScreenLyricsVisible && !self.isHoveringFullScreenControls && !self.isPickerOpen && !self.playback.paused {
                    self.fullScreenControlsVisible = false
                }
            }
        }
    }

    func popOutToFloating() {
        isSidebarVisible = false
        isHudVisible = true
    }

    func dockToSidebar() {
        isHudVisible = false
        isSidebarVisible = true
    }

    func switchSite(to mode: WebSiteMode) {
        siteMode = mode
        onSwitchSite?(mode)
    }

    func navigateToYtmPath(_ path: String) {
        siteMode = .youtubeMusic
        let cleaned = path.hasPrefix("/") ? path : "/\(path)"
        if let url = URL(string: "https://music.youtube.com\(cleaned)") {
            onNavigateURL?(url)
        }
    }

    func searchInWeb(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var comps: URLComponents
        if siteMode == .youtubeMusic {
            comps = URLComponents(string: "https://music.youtube.com/search")!
            comps.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        } else {
            comps = URLComponents(string: "https://www.youtube.com/results")!
            comps.queryItems = [URLQueryItem(name: "search_query", value: trimmed)]
        }
        if let url = comps.url {
            onNavigateURL?(url)
        }
    }

    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            launchAtLoginEnabled = true
            launchAtLoginHint = "Enabled — launches automatically on login"
        case .requiresApproval:
            launchAtLoginEnabled = false
            launchAtLoginHint = "Needs approval in System Settings → Login Items"
        default:
            launchAtLoginEnabled = false
            launchAtLoginHint = "Start YT Music Glass automatically when you log in"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginHint = "Move app to /Applications (`make install`) to enable Launch at Login"
        }
    }

    // GitHub Releases Auto-Updater
    var availableUpdateVersion: String? {
        if case .available(let info) = updateState {
            return info.version
        }
        return nil
    }

    func checkForUpdates(userInitiated: Bool) {
        if case .downloading = updateState { return }
        updateTask?.cancel()
        if userInitiated {
            updateState = .checking
        }

        let service = updateService
        updateTask = Task { [weak self] in
            let result = await service.checkForUpdates()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if !userInitiated {
                    // Silent startup check: only surface if an actual newer release is available
                    if case .available = result {
                        self.updateState = result
                    }
                } else {
                    self.updateState = result
                }
            }
        }
    }

    func downloadAndOpenUpdate() {
        guard case .available(let release) = updateState else { return }
        guard let dmgURL = release.dmgDownloadURL else {
            NSWorkspace.shared.open(release.htmlURL)
            return
        }

        updateTask?.cancel()
        updateState = .downloading(progress: 0.02, version: release.version)
        let service = updateService
        let filename = release.dmgFilename ?? "YT-Music-Glass-\(release.tagName).dmg"

        updateTask = Task { [weak self] in
            let weakStore = self
            do {
                let fileURL = try await service.downloadDmg(from: dmgURL, filename: filename) { progress in
                    Task { @MainActor in
                        weakStore?.updateState = .downloading(progress: progress, version: release.version)
                    }
                }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.updateState = .readyToInstall(fileURL: fileURL, version: release.version)
                    NSWorkspace.shared.open(fileURL)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.updateState = .error("Download failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func handleWebBridgeMessage(_ body: [String: Any]) {
        if let action = body["action"] as? String {
            if action == "toggleSidebar" {
                isSidebarVisible.toggle()
                return
            }
            if action == "toggleHud" {
                isHudVisible.toggle()
                return
            }
            if action == "offlineTracksDiscovered" {
                if let rawTracks = body["tracks"] as? [[String: Any]] {
                    let parsed: [TrackInfo] = rawTracks.compactMap { t in
                        let title = (t["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        guard !title.isEmpty else { return nil }
                        return TrackInfo(
                            id: (t["id"] as? String) ?? "",
                            title: title,
                            artist: (t["artist"] as? String) ?? "",
                            album: t["album"] as? String,
                            duration: (t["duration"] as? NSNumber)?.doubleValue ?? 0,
                            artworkUrl: t["artworkUrl"] as? String
                        )
                    }
                    enqueueOfflineLyricsSync(parsed)
                }
                return
            }
        }

        let offlineContext = (body["isOfflineContext"] as? Bool) ?? false
        self.isCurrentTrackInOfflineContext = offlineContext

        if let platformStr = body["platform"] as? String,
           let parsedSite = WebSiteMode(rawValue: platformStr),
           parsedSite != siteMode
        {
            siteMode = parsedSite
        }

        let pbDict = body["playback"] as? [String: Any] ?? [:]
        let newPlayback = PlaybackSnapshot(
            currentTime: (pbDict["currentTime"] as? NSNumber)?.doubleValue ?? 0,
            duration: (pbDict["duration"] as? NSNumber)?.doubleValue ?? 0,
            paused: (pbDict["paused"] as? Bool) ?? true,
            playbackRate: (pbDict["playbackRate"] as? NSNumber)?.doubleValue ?? 1.0,
            isAdPlaying: (pbDict["isAdPlaying"] as? Bool) ?? false,
            capturedAtMs: (pbDict["capturedAtMs"] as? NSNumber)?.doubleValue ?? (Date().timeIntervalSince1970 * 1000.0)
        )
        self.playback = newPlayback

        let nativeLyrics = body["nativeLyrics"] as? String
        self.lastNativeFallback = nativeLyrics

        var incomingTrack: TrackInfo? = nil
        if let t = body["track"] as? [String: Any] {
            let title = (t["title"] as? String) ?? ""
            let artist = (t["artist"] as? String) ?? ""
            if !title.isEmpty || !artist.isEmpty {
                incomingTrack = TrackInfo(
                    id: (t["id"] as? String) ?? "",
                    title: title,
                    artist: artist,
                    album: t["album"] as? String,
                    duration: (t["duration"] as? NSNumber)?.doubleValue ?? newPlayback.duration,
                    artworkUrl: t["artworkUrl"] as? String
                )
            }
        }

        if newPlayback.isAdPlaying {
            if status != .adPlaying {
                cancelPendingFetch()
                status = .adPlaying
                resolvedLyrics = nil
                frame = .empty
            }
            recomputeFrame()
            updateTimerState()
            return
        }

        if status == .adPlaying {
            loadTrack(incomingTrack, nativeFallback: nativeLyrics, force: true)
            return
        }

        let nextCleaned = incomingTrack.map { MetadataNormalizer.normalize($0) }
        if nextCleaned?.trackKey != currentCleaned?.trackKey {
            loadTrack(incomingTrack, nativeFallback: nativeLyrics, force: true)
        } else if let incoming = incomingTrack, let cleaned = nextCleaned {
            let display = TrackInfo(
                id: incoming.id,
                title: cleaned.title.isEmpty ? incoming.title : cleaned.title,
                artist: cleaned.artist.isEmpty ? incoming.artist : cleaned.artist,
                album: cleaned.album,
                duration: incoming.duration,
                artworkUrl: incoming.artworkUrl
            )
            self.track = display
            if let newArt = incoming.artworkUrl, !newArt.isEmpty,
               (self.artworkImage == nil || self.palette.artworkUrl != newArt)
            {
                refreshPalette(artworkUrl: newArt, seed: cleaned.trackKey, generation: loadGeneration)
            }
            if offlineContext && !isCurrentTrackOfflineSaved && resolvedLyrics != nil {
                saveCurrentTrackOffline()
            }
            recomputeFrame()
            updateTimerState()
        } else {
            recomputeFrame()
            updateTimerState()
        }
    }

    func retryCurrentTrack() {
        guard let raw = currentCleaned?.raw else { return }
        loadTrack(raw, nativeFallback: lastNativeFallback, force: true, bypassCache: true)
    }

    private func cancelPendingFetch() {
        loadGeneration += 1
        fetchTask?.cancel()
        fetchTask = nil
        paletteTask?.cancel()
        paletteTask = nil
        translateTask?.cancel()
        translateTask = nil
        isTranslating = false
    }

    func romanizedText(at index: Int) -> String? {
        guard autoRomanizeEnabled, index >= 0, index < romanizedLines.count else { return nil }
        return romanizedLines[index]
    }

    func translatedText(at index: Int) -> String? {
        guard translateEnabled, index >= 0, index < translatedLines.count else { return nil }
        return translatedLines[index]
    }

    var isTranslationSkippedSameLanguage: Bool {
        guard translateEnabled, !detectedSongLanguage.isEmpty else { return false }
        return !TranslationService.shouldTranslateSong(
            detectedLang: detectedSongLanguage,
            source: translateSource,
            target: translateTarget
        )
    }

    private func rawLinesForCurrentLyrics() -> [String] {
        guard let parsed = resolvedLyrics?.parsed else { return [] }
        if parsed.mode == "synced" {
            return parsed.lines.map { $0.isInstrumental ? "" : $0.text }
        }
        return parsed.plainLines
    }

    private func computeRomanizationAndTranslation() {
        let lines = rawLinesForCurrentLyrics()
        guard !lines.isEmpty else {
            detectedSongLanguage = ""
            romanizedLines = []
            translatedLines = []
            isTranslating = false
            return
        }

        let (lang, scriptHint) = TranslationService.detectSongLanguage(lines: lines)
        detectedSongLanguage = lang

        // Offline romanization computes in < 1ms for all non-Latin lines
        romanizedLines = lines.map { line in
            guard !line.isEmpty else { return nil }
            return Romanizer.romanizeLine(line, songHint: scriptHint)
        }

        refreshTranslationForCurrentLyrics()
    }

    private func refreshTranslationForCurrentLyrics() {
        translateTask?.cancel()
        translateTask = nil

        let lines = rawLinesForCurrentLyrics()
        guard translateEnabled, !lines.isEmpty, let cleaned = currentCleaned else {
            translatedLines = []
            isTranslating = false
            return
        }

        let source = translateSource
        let target = translateTarget
        if !TranslationService.shouldTranslateSong(detectedLang: detectedSongLanguage, source: source, target: target) {
            translatedLines = Array(repeating: nil, count: lines.count)
            isTranslating = false
            return
        }

        let myGen = loadGeneration
        let pinOffline = isCurrentTrackOfflineSaved || isCurrentTrackInOfflineContext
        let metaKey = TranslationService.makeMetaKey(
            artist: cleaned.artist,
            title: cleaned.title,
            source: source,
            target: target
        )
        isTranslating = true
        let service = translationService

        translateTask = Task { [weak self] in
            let result = await service.translateLyrics(
                trackKey: cleaned.trackKey,
                metaKey: metaKey,
                lines: lines,
                source: source,
                target: target,
                pinOffline: pinOffline
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.loadGeneration == myGen else { return }
                if !result.detectedLang.isEmpty {
                    self.detectedSongLanguage = result.detectedLang
                }
                self.translatedLines = result.translations
                self.isTranslating = false
            }
        }
    }

    private func refreshPalette(artworkUrl: String?, seed: String, generation: Int) {
        paletteTask?.cancel()
        let extractor = paletteExtractor
        paletteTask = Task { [weak self] in
            let result = await extractor.extract(artworkUrl: artworkUrl, seed: seed)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.loadGeneration == generation else { return }
                self.palette = result.palette
                self.artworkImage = result.image
                self.onPaletteChanged?(result.palette)
                self.syncNowPlaying()
            }
        }
    }

    private func loadTrack(
        _ incoming: TrackInfo?,
        nativeFallback: String?,
        force: Bool,
        bypassCache: Bool = false
    ) {
        guard let incoming, !incoming.title.trimmingCharacters(in: .whitespaces).isEmpty || !incoming.artist.trimmingCharacters(in: .whitespaces).isEmpty else {
            cancelPendingFetch()
            currentCleaned = nil
            track = nil
            artworkImage = nil
            palette = .defaultGlass
            onPaletteChanged?(.defaultGlass)
            resolvedLyrics = nil
            lyricsSource = nil
            detectedSongLanguage = ""
            romanizedLines = []
            translatedLines = []
            isTranslating = false
            offsetMs = 0
            errorMessage = nil
            status = .idle
            frame = .empty
            updateTimerState()
            return
        }

        let cleaned = MetadataNormalizer.normalize(incoming)
        if !force, currentCleaned?.trackKey == cleaned.trackKey, status != .idle, status != .adPlaying {
            return
        }

        cancelPendingFetch()
        let myGen = loadGeneration

        currentCleaned = cleaned
        track = TrackInfo(
            id: incoming.id,
            title: cleaned.title.isEmpty ? incoming.title : cleaned.title,
            artist: cleaned.artist.isEmpty ? incoming.artist : cleaned.artist,
            album: cleaned.album,
            duration: incoming.duration,
            artworkUrl: incoming.artworkUrl
        )
        resolvedLyrics = nil
        lyricsSource = nil
        detectedSongLanguage = ""
        romanizedLines = []
        translatedLines = []
        isTranslating = false
        errorMessage = nil
        offsetMs = lyricsService.getOffsetMs(for: cleaned.trackKey)
        isCurrentTrackOfflineSaved = lyricsService.hasOfflineLyrics(for: cleaned)
        status = .loading
        frame = .empty
        pickerCandidates = []

        refreshPalette(artworkUrl: incoming.artworkUrl, seed: cleaned.trackKey, generation: myGen)

        let service = lyricsService
        let shouldPinOffline = isCurrentTrackInOfflineContext || isCurrentTrackOfflineSaved
        fetchTask = Task { [weak self] in
            do {
                let result = try await service.resolve(
                    track: cleaned,
                    nativeFallback: nativeFallback,
                    bypassCache: bypassCache,
                    pinOffline: shouldPinOffline
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.loadGeneration == myGen else { return }
                    guard let result else {
                        self.status = .notFound
                        self.resolvedLyrics = nil
                        self.lyricsSource = nil
                        self.isCurrentTrackOfflineSaved = false
                        self.updateTimerState()
                        return
                    }
                    self.resolvedLyrics = result
                    self.lyricsSource = result.source
                    self.pickerCandidates = result.candidates
                    self.status = result.parsed.mode == "synced" ? .synced : .plainFallback
                    self.isCurrentTrackOfflineSaved = self.lyricsService.hasOfflineLyrics(for: cleaned)
                    self.offlineSavedCount = self.lyricsService.offlineCount()
                    self.computeRomanizationAndTranslation()
                    self.recomputeFrame()
                    self.updateTimerState()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.loadGeneration == myGen else { return }
                    self.status = .error
                    self.errorMessage = error.localizedDescription
                    self.updateTimerState()
                }
            }
        }
    }

    // Interactive Controls
    func seekToLyricLine(_ lineStartTime: Double) {
        let target = SyncCalculator.computeSeekTarget(
            lineStartTime: lineStartTime,
            offsetMs: offsetMs,
            duration: playback.duration
        )
        onPlayerCommand?("seek", target)
    }

    func seekToRawTime(_ seconds: Double) {
        let maxTime = playback.duration > 0 ? playback.duration : Double.greatestFiniteMagnitude
        let clamped = SyncCalculator.clamp(seconds, min: 0, max: maxTime)
        onPlayerCommand?("seek", clamped)
    }

    func playOnly() {
        onPlayerCommand?("play", nil)
    }

    func pauseOnly() {
        onPlayerCommand?("pause", nil)
    }

    func togglePlay() {
        onPlayerCommand?("togglePlay", nil)
    }

    func prevTrack() {
        onPlayerCommand?("prev", nil)
    }

    func nextTrack() {
        onPlayerCommand?("next", nil)
    }

    func adjustOffset(deltaMs: Double) {
        offsetMs += deltaMs
        if let key = currentCleaned?.trackKey {
            lyricsService.saveOffsetMs(offsetMs, for: key)
        }
        recomputeFrame()
    }

    func resetOffset() {
        offsetMs = 0
        if let key = currentCleaned?.trackKey {
            lyricsService.saveOffsetMs(0, for: key)
        }
        recomputeFrame()
    }

    func adjustFont(delta: Double) {
        fontScale = SyncCalculator.clamp(fontScale + delta, min: 0.75, max: 1.6)
    }

    func toggleDisplayMode() {
        displayMode = displayMode == .compact ? .full : .compact
    }

    // Lyrics Picker
    func openPicker() {
        guard let cleaned = currentCleaned else { return }
        isPickerOpen = true
        let defaultQ = [cleaned.artist, cleaned.title].filter { !$0.isEmpty }.joined(separator: " ")
        pickerQuery = defaultQ
        if pickerCandidates.count <= 1 && !defaultQ.isEmpty {
            runManualPickerSearch()
        }
    }

    func closePicker() {
        pickerTask?.cancel()
        pickerTask = nil
        isPickerSearching = false
        isPickerOpen = false
    }

    func runManualPickerSearch() {
        guard let cleaned = currentCleaned else { return }
        let query = pickerQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        pickerTask?.cancel()
        isPickerSearching = true
        let service = lyricsService

        pickerTask = Task { [weak self] in
            do {
                let results = try await service.searchCandidates(query: query, for: cleaned)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.pickerCandidates = results
                    self.isPickerSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.pickerCandidates = []
                    self.isPickerSearching = false
                }
            }
        }
    }

    func selectPickerCandidate(_ candidate: LrclibCandidate) {
        guard let cleaned = currentCleaned else { return }
        guard let resolved = lyricsService.buildResolved(
            from: candidate,
            duration: cleaned.duration,
            candidates: pickerCandidates
        ) else { return }

        lyricsService.saveSelectedCandidate(candidate, for: cleaned, pinOffline: isCurrentTrackOfflineSaved)
        resolvedLyrics = resolved
        lyricsSource = resolved.source
        status = resolved.parsed.mode == "synced" ? .synced : .plainFallback
        isCurrentTrackOfflineSaved = lyricsService.hasOfflineLyrics(for: cleaned)
        offlineSavedCount = lyricsService.offlineCount()
        computeRomanizationAndTranslation()
        closePicker()
        recomputeFrame()
        updateTimerState()
    }

    // Offline Karaoke Vault Management
    func saveCurrentTrackOffline() {
        guard let cleaned = currentCleaned else { return }
        if lyricsService.pinExistingForOffline(track: cleaned) {
            isCurrentTrackOfflineSaved = true
            offlineSavedCount = lyricsService.offlineCount()

            let lines = rawLinesForCurrentLyrics()
            if translateEnabled && !lines.isEmpty {
                let metaKey = TranslationService.makeMetaKey(
                    artist: cleaned.artist,
                    title: cleaned.title,
                    source: translateSource,
                    target: translateTarget
                )
                translationService.pinExistingOffline(
                    trackKey: cleaned.trackKey,
                    metaKey: metaKey,
                    lineCount: lines.count,
                    source: translateSource,
                    target: translateTarget
                )
            }
        } else if let raw = currentCleaned?.raw {
            enqueueOfflineLyricsSync([raw])
        }
    }

    func downloadOfflineLyricsForCurrentPage() {
        if currentCleaned != nil {
            saveCurrentTrackOffline()
        }
        onScanOfflinePage?()
    }

    func enqueueOfflineLyricsSync(_ tracks: [TrackInfo]) {
        guard !tracks.isEmpty else { return }
        var added = 0
        for raw in tracks {
            let cleaned = MetadataNormalizer.normalize(raw)
            guard !cleaned.title.isEmpty else { continue }
            guard !offlineQueuedKeys.contains(cleaned.trackKey) else { continue }

            let alreadyHasLyrics = lyricsService.hasOfflineLyrics(for: cleaned)
            if alreadyHasLyrics && !translateEnabled {
                continue
            }

            offlineQueuedKeys.insert(cleaned.trackKey)
            offlineQueue.append(cleaned)
            added += 1
        }

        guard added > 0 else { return }
        if !offlineSyncActive {
            offlineSyncCompleted = 0
            offlineSyncTotal = offlineQueue.count
            offlineSyncActive = true
        } else {
            offlineSyncTotal += added
        }

        if offlineWorkerTask == nil {
            offlineWorkerTask = Task { [weak self] in
                await self?.runOfflineSyncWorker()
            }
        }
    }

    private func runOfflineSyncWorker() async {
        while !offlineQueue.isEmpty {
            if Task.isCancelled { break }
            let next = offlineQueue.removeFirst()

            let resolved = await lyricsService.prefetchForOffline(track: next)

            // Also pre-download & pin translation offline when Smart Translate is enabled
            if let resolved, translateEnabled {
                let lines: [String] = resolved.parsed.mode == "synced"
                    ? resolved.parsed.lines.map { $0.isInstrumental ? "" : $0.text }
                    : resolved.parsed.plainLines
                if !lines.isEmpty {
                    let metaKey = TranslationService.makeMetaKey(
                        artist: next.artist,
                        title: next.title,
                        source: translateSource,
                        target: translateTarget
                    )
                    _ = await translationService.translateLyrics(
                        trackKey: next.trackKey,
                        metaKey: metaKey,
                        lines: lines,
                        source: translateSource,
                        target: translateTarget,
                        pinOffline: true
                    )
                }
            }

            offlineSyncCompleted += 1
            offlineSavedCount = lyricsService.offlineCount()
            if let current = currentCleaned, current.trackKey == next.trackKey {
                isCurrentTrackOfflineSaved = lyricsService.hasOfflineLyrics(for: current)
            }

            // Gentle pacing to respect LRCLIB & translation rate limits
            try? await Task.sleep(nanoseconds: 160_000_000)
        }

        offlineQueuedKeys.removeAll()
        offlineWorkerTask = nil

        // Keep completed indicator visible briefly before dismissing cleanly
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        if offlineQueue.isEmpty {
            offlineSyncActive = false
            offlineSyncCompleted = 0
            offlineSyncTotal = 0
        }
    }

    func clearCache() {
        lyricsService.clearCache()
        translationService.clearCache()
        if translateEnabled {
            refreshTranslationForCurrentLyrics()
        }
    }

    func clearOfflineVault() {
        offlineWorkerTask?.cancel()
        offlineWorkerTask = nil
        offlineQueue.removeAll()
        offlineQueuedKeys.removeAll()
        offlineSyncActive = false
        offlineSyncCompleted = 0
        offlineSyncTotal = 0

        lyricsService.clearOfflineVault()
        translationService.clearOfflineCache()
        offlineSavedCount = lyricsService.offlineCount()
        if let current = currentCleaned {
            isCurrentTrackOfflineSaved = lyricsService.hasOfflineLyrics(for: current)
        } else {
            isCurrentTrackOfflineSaved = false
        }
    }

    func recomputeFrame() {
        let nowMs = Date().timeIntervalSince1970 * 1000.0
        let t = SyncCalculator.extrapolateTime(playback: playback, nowMs: nowMs)
        if playback.duration > 0 {
            playbackProgress = SyncCalculator.clamp(t / playback.duration, min: 0, max: 1)
        } else {
            playbackProgress = 0
        }

        if status == .synced, let parsed = resolvedLyrics?.parsed {
            frame = SyncCalculator.computeFrame(parsed: parsed, currentTime: t, offsetMs: offsetMs)
        } else {
            frame = .empty
        }

        if audioVisualizerEnabled && !playback.paused && !playback.isAdPlaying {
            visualizerPhase = t
        }

        updateMenuBarLyricDisplay()
    }

    func syncNowPlaying() {
        nowPlayingBridge.update(track: track, playback: playback, artwork: artworkImage)
    }

    private func updateMenuBarLyricDisplay() {
        guard menuBarLyricsEnabled, !playback.paused, !playback.isAdPlaying else {
            if !menuBarLyricText.isEmpty { menuBarLyricText = "" }
            return
        }

        let candidate: String
        if status == .synced,
           let lines = resolvedLyrics?.parsed.lines,
           frame.activeLineIndex >= 0,
           frame.activeLineIndex < lines.count,
           !lines[frame.activeLineIndex].isInstrumental
        {
            let raw = romanizedText(at: frame.activeLineIndex) ?? lines[frame.activeLineIndex].text
            candidate = truncateForMenuBar(raw, maxChars: 42)
        } else if status == .synced && frame.instrumentalActive {
            candidate = "•••"
        } else {
            candidate = ""
        }

        if candidate != menuBarLyricText {
            menuBarLyricText = candidate
        }
    }

    private func truncateForMenuBar(_ text: String, maxChars: Int) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > maxChars else { return cleaned }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: maxChars - 1)
        return String(cleaned[..<idx]).trimmingCharacters(in: .whitespaces) + "…"
    }

    private func updateTimerState() {
        let needsLiveTick =
            isHudVisible ||
            isSidebarVisible ||
            isFullScreenLyricsVisible ||
            isMiniPlayerVisible ||
            menuBarLyricsEnabled

        let shouldTick =
            needsLiveTick &&
            !playback.paused &&
            (status == .synced || isMiniPlayerVisible || isFullScreenLyricsVisible || (audioVisualizerEnabled && (isSidebarVisible || isHudVisible)))

        syncNowPlaying()

        if shouldTick {
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recomputeFrame()
                }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
}
