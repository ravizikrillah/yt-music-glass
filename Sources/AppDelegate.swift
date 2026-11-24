import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = AppStore()
    private var hudController: HudWindowController?
    private var miniPlayerController: MiniPlayerWindowController?
    private var settingsController: SettingsWindowController?
    private var aboutController: AboutWindowController?
    private var commandPaletteController: CommandPaletteController?
    private var playerController: PlayerWindowController?
    private var statusItem: NSStatusItem?
    private var menuBarCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppFont.registerBundledFonts()
        NSApp.setActivationPolicy(.regular)
        store.dockIconController.captureBaseIconIfNeeded()
        setupMainMenu()

        let hud = HudWindowController(store: store)
        self.hudController = hud

        let mini = MiniPlayerWindowController(store: store) { [weak self] in
            self?.showPlayer()
        }
        self.miniPlayerController = mini

        let settings = SettingsWindowController(store: store)
        self.settingsController = settings

        let about = AboutWindowController(store: store)
        self.aboutController = about

        let palette = CommandPaletteController(
            store: store,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenAbout: { [weak self] in self?.openAbout() },
            onCheckForUpdates: { [weak self] in self?.checkForUpdates() },
            onShowMainWindow: { [weak self] in self?.showPlayer() },
            onReloadPage: { [weak self] in self?.reloadPlayer() }
        )
        self.commandPaletteController = palette

        let player = PlayerWindowController(
            store: store,
            onResetHudPosition: { [weak hud] in hud?.resetPosition() },
            onOpenCommandPalette: { [weak self] in self?.toggleCommandPalette() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenAbout: { [weak self] in self?.openAbout() }
        )
        self.playerController = player

        store.isMainWindowVisibleAndActive = { [weak player] in
            guard let win = player?.window else { return false }
            return NSApp.isActive && win.isVisible && !win.isMiniaturized
        }
        store.onShowMainWindowFromNotification = { [weak self] in
            self?.showPlayer()
        }
        store.configureDesktopExperience()

        player.show()
        if store.isHudVisible {
            hud.show()
        }
        if store.isMiniPlayerVisible {
            mini.show()
        }
        setupMenuBar()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        playerController?.show()
        return true
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App Menu
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let aboutItem = NSMenuItem(title: "About \(AppIdentity.appName)", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        appMenu.addItem(updateItem)

        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide YT Music Glass", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit YT Music Glass", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        // Edit Menu (essential so Cmd+C / Cmd+V / Cmd+A work in WKWebView & Google Sign-in!)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        // View / Lyrics Menu
        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "Lyrics")

        let cmdPaletteItem = NSMenuItem(title: "Quick Command Palette", action: #selector(toggleCommandPalette), keyEquivalent: "k")
        cmdPaletteItem.target = self
        viewMenu.addItem(cmdPaletteItem)

        let reloadItem = NSMenuItem(title: "Reload Page", action: #selector(reloadPlayer), keyEquivalent: "r")
        reloadItem.target = self
        viewMenu.addItem(reloadItem)

        let toggleSidebarItem = NSMenuItem(title: "Toggle Lyrics Sidebar", action: #selector(toggleSidebar), keyEquivalent: "S")
        toggleSidebarItem.keyEquivalentModifierMask = [.command, .shift]
        toggleSidebarItem.target = self
        viewMenu.addItem(toggleSidebarItem)

        let toggleFullScreenItem = NSMenuItem(title: "Toggle Full Screen Lyrics", action: #selector(toggleFullScreenLyrics), keyEquivalent: "F")
        toggleFullScreenItem.keyEquivalentModifierMask = [.command, .shift]
        toggleFullScreenItem.target = self
        viewMenu.addItem(toggleFullScreenItem)

        let toggleHudItem = NSMenuItem(title: "Toggle Floating Lyrics", action: #selector(toggleHud), keyEquivalent: "L")
        toggleHudItem.keyEquivalentModifierMask = [.command, .shift]
        toggleHudItem.target = self
        viewMenu.addItem(toggleHudItem)

        let toggleMiniItem = NSMenuItem(title: "Toggle Mini Player", action: #selector(toggleMiniPlayer), keyEquivalent: "P")
        toggleMiniItem.keyEquivalentModifierMask = [.command, .shift]
        toggleMiniItem.target = self
        viewMenu.addItem(toggleMiniItem)

        let toggleMenuBarLyricsItem = NSMenuItem(title: "Toggle Menu Bar Live Lyrics", action: #selector(toggleMenuBarLyrics), keyEquivalent: "B")
        toggleMenuBarLyricsItem.keyEquivalentModifierMask = [.command, .shift]
        toggleMenuBarLyricsItem.target = self
        viewMenu.addItem(toggleMenuBarLyricsItem)

        let toggleLockItem = NSMenuItem(title: "Toggle Click-Through Lock", action: #selector(toggleClickThrough), keyEquivalent: "K")
        toggleLockItem.keyEquivalentModifierMask = [.command, .shift]
        toggleLockItem.target = self
        viewMenu.addItem(toggleLockItem)

        let toggleCompactItem = NSMenuItem(title: "Toggle Compact / Full Lyrics", action: #selector(toggleCompact), keyEquivalent: "M")
        toggleCompactItem.keyEquivalentModifierMask = [.command, .shift]
        toggleCompactItem.target = self
        viewMenu.addItem(toggleCompactItem)

        viewMenu.addItem(.separator())

        let toggleTranslateItem = NSMenuItem(title: "Toggle Smart Translate", action: #selector(toggleTranslate), keyEquivalent: "E")
        toggleTranslateItem.keyEquivalentModifierMask = [.command, .shift]
        toggleTranslateItem.target = self
        viewMenu.addItem(toggleTranslateItem)

        let toggleRomajiItem = NSMenuItem(title: "Toggle Auto Romaji / Romanization", action: #selector(toggleAutoRomanize), keyEquivalent: "R")
        toggleRomajiItem.keyEquivalentModifierMask = [.command, .shift]
        toggleRomajiItem.target = self
        viewMenu.addItem(toggleRomajiItem)

        viewMenu.addItem(.separator())

        let saveOfflineItem = NSMenuItem(title: "Save Current Lyrics Offline", action: #selector(saveCurrentOffline), keyEquivalent: "D")
        saveOfflineItem.keyEquivalentModifierMask = [.command, .shift]
        saveOfflineItem.target = self
        viewMenu.addItem(saveOfflineItem)

        let syncPageOfflineItem = NSMenuItem(title: "Download Offline Lyrics for Current Page", action: #selector(syncOfflinePage), keyEquivalent: "O")
        syncPageOfflineItem.keyEquivalentModifierMask = [.command, .shift]
        syncPageOfflineItem.target = self
        viewMenu.addItem(syncPageOfflineItem)

        viewMenu.addItem(.separator())

        let toggleThemeItem = NSMenuItem(title: "Toggle Apple Glass Theme", action: #selector(toggleTheme), keyEquivalent: "T")
        toggleThemeItem.keyEquivalentModifierMask = [.command, .shift]
        toggleThemeItem.target = self
        viewMenu.addItem(toggleThemeItem)

        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let img = NSImage(systemSymbolName: "music.mic", accessibilityDescription: "YT Music Glass") {
                img.isTemplate = true
                button.image = img
                button.imagePosition = .imageLeading
            } else {
                button.title = "♪"
            }
            button.toolTip = "YT Music Glass — Native Player, Mini Player & Live Lyrics"
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        menuBarCancellable = store.$menuBarLyricText
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.updateStatusItemTitle(text)
            }
    }

    private func updateStatusItemTitle(_ text: String) {
        guard let button = statusItem?.button else { return }
        if text.isEmpty {
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]
            button.attributedTitle = NSAttributedString(string: " \(text)", attributes: attrs)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let headerTitle: String
        if let track = store.track, !track.title.isEmpty {
            headerTitle = "\(track.title) — \(track.artist)"
        } else {
            headerTitle = "\(store.siteMode.label) · Ready"
        }
        let header = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let showPlayerItem = NSMenuItem(title: "Show Player Window", action: #selector(showPlayer), keyEquivalent: "")
        showPlayerItem.target = self
        menu.addItem(showPlayerItem)

        let cmdPaletteMenu = NSMenuItem(title: "Quick Command Palette (⌘K)", action: #selector(toggleCommandPalette), keyEquivalent: "")
        cmdPaletteMenu.target = self
        menu.addItem(cmdPaletteMenu)

        let settingsMenu = NSMenuItem(title: "Settings… (⌘,)", action: #selector(openSettings), keyEquivalent: "")
        settingsMenu.target = self
        menu.addItem(settingsMenu)

        let updateTitle = store.availableUpdateVersion.map { "Update Available (v\($0))…" } ?? "Check for Updates…"
        let updateMenu = NSMenuItem(title: updateTitle, action: #selector(checkForUpdates), keyEquivalent: "")
        updateMenu.target = self
        menu.addItem(updateMenu)

        let aboutMenu = NSMenuItem(title: "About \(AppIdentity.appName)", action: #selector(openAbout), keyEquivalent: "")
        aboutMenu.target = self
        menu.addItem(aboutMenu)

        let toggleSidebarItem = NSMenuItem(
            title: store.isSidebarVisible ? "Hide Lyrics Sidebar" : "Show Lyrics Sidebar",
            action: #selector(toggleSidebar),
            keyEquivalent: ""
        )
        toggleSidebarItem.target = self
        menu.addItem(toggleSidebarItem)

        let toggleHudItem = NSMenuItem(
            title: store.isHudVisible ? "Hide Floating Lyrics" : "Show Floating Lyrics",
            action: #selector(toggleHud),
            keyEquivalent: ""
        )
        toggleHudItem.target = self
        menu.addItem(toggleHudItem)

        let toggleMiniItem = NSMenuItem(
            title: store.isMiniPlayerVisible ? "Hide Mini Player" : "Show Mini Player",
            action: #selector(toggleMiniPlayer),
            keyEquivalent: ""
        )
        toggleMiniItem.target = self
        toggleMiniItem.state = store.isMiniPlayerVisible ? .on : .off
        menu.addItem(toggleMiniItem)

        let menuBarLyricsItem = NSMenuItem(
            title: "Menu Bar Live Lyrics",
            action: #selector(toggleMenuBarLyrics),
            keyEquivalent: ""
        )
        menuBarLyricsItem.target = self
        menuBarLyricsItem.state = store.menuBarLyricsEnabled ? .on : .off
        menu.addItem(menuBarLyricsItem)

        let clickThroughItem = NSMenuItem(
            title: "Click-Through Lock (Tembus Klik)",
            action: #selector(toggleClickThrough),
            keyEquivalent: ""
        )
        clickThroughItem.target = self
        clickThroughItem.state = store.isClickThrough ? .on : .off
        menu.addItem(clickThroughItem)

        let compactItem = NSMenuItem(
            title: "Compact 2-Line Mode",
            action: #selector(toggleCompact),
            keyEquivalent: ""
        )
        compactItem.target = self
        compactItem.state = store.displayMode == .compact ? .on : .off
        menu.addItem(compactItem)

        // Transparency presets
        let opacityMenuItem = NSMenuItem(title: "Transparency", action: nil, keyEquivalent: "")
        let opacityMenu = NSMenu()
        let presets: [(String, Double)] = [
            ("0% — Pure Floating Text (Transparan Penuh)", 0.0),
            ("25% — Ultra Sheer Glass", 0.25),
            ("45% — Frosted Glass", 0.45),
            ("75% — Deep Dark Glass", 0.75),
        ]
        for (label, value) in presets {
            let preset = NSMenuItem(title: label, action: #selector(selectOpacityPreset(_:)), keyEquivalent: "")
            preset.target = self
            preset.representedObject = value
            if abs(store.backgroundOpacity - value) < 0.08 {
                preset.state = .on
            }
            opacityMenu.addItem(preset)
        }
        opacityMenuItem.submenu = opacityMenu
        menu.addItem(opacityMenuItem)

        let themeItem = NSMenuItem(
            title: "Apple Music Glass Theme",
            action: #selector(toggleTheme),
            keyEquivalent: ""
        )
        themeItem.target = self
        themeItem.state = store.appleGlassThemeEnabled ? .on : .off
        menu.addItem(themeItem)

        let translateItem = NSMenuItem(
            title: "Smart Translate (\(store.translateSource.shortCode) → \(store.translateTarget.shortCode))",
            action: #selector(toggleTranslate),
            keyEquivalent: ""
        )
        translateItem.target = self
        translateItem.state = store.translateEnabled ? .on : .off
        menu.addItem(translateItem)

        let romajiItem = NSMenuItem(
            title: "Auto Romaji / Romanization",
            action: #selector(toggleAutoRomanize),
            keyEquivalent: ""
        )
        romajiItem.target = self
        romajiItem.state = store.autoRomanizeEnabled ? .on : .off
        menu.addItem(romajiItem)

        menu.addItem(.separator())

        let saveCurrentOfflineItem = NSMenuItem(
            title: store.isCurrentTrackOfflineSaved ? "Current Lyrics Saved Offline ✓" : "Save Current Lyrics Offline",
            action: #selector(saveCurrentOffline),
            keyEquivalent: ""
        )
        saveCurrentOfflineItem.target = self
        saveCurrentOfflineItem.isEnabled = store.track != nil
        saveCurrentOfflineItem.state = store.isCurrentTrackOfflineSaved ? .on : .off
        menu.addItem(saveCurrentOfflineItem)

        let syncPageTitle = store.offlineSyncActive
            ? "Syncing Offline Lyrics (\(min(store.offlineSyncCompleted, store.offlineSyncTotal))/\(store.offlineSyncTotal))..."
            : "Download Offline Lyrics for This Page (\(store.offlineSavedCount) saved)"
        let syncPageItem = NSMenuItem(
            title: syncPageTitle,
            action: #selector(syncOfflinePage),
            keyEquivalent: ""
        )
        syncPageItem.target = self
        menu.addItem(syncPageItem)

        let clearCacheItem = NSMenuItem(
            title: "Clear Temp Cache (\(store.lyricsService.cacheCount()))",
            action: #selector(clearCache),
            keyEquivalent: ""
        )
        clearCacheItem.target = self
        menu.addItem(clearCacheItem)

        let clearOfflineItem = NSMenuItem(
            title: "Clear Offline Lyrics Vault (\(store.offlineSavedCount))",
            action: #selector(clearOfflineVault),
            keyEquivalent: ""
        )
        clearOfflineItem.target = self
        clearOfflineItem.isEnabled = store.offlineSavedCount > 0
        menu.addItem(clearOfflineItem)

        let resetPosItem = NSMenuItem(title: "Reset Floating Lyrics Position", action: #selector(resetPosition), keyEquivalent: "")
        resetPosItem.target = self
        menu.addItem(resetPosItem)

        let resetMiniPosItem = NSMenuItem(title: "Reset Mini Player Position", action: #selector(resetMiniPosition), keyEquivalent: "")
        resetMiniPosItem.target = self
        menu.addItem(resetMiniPosItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit YT Music Glass", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func showPlayer() {
        playerController?.show()
    }

    @objc private func openSettings() {
        settingsController?.show()
    }

    @objc private func openAbout() {
        aboutController?.show(checkIfNeeded: true)
    }

    @objc private func checkForUpdates() {
        aboutController?.show(checkIfNeeded: false)
        store.checkForUpdates(userInitiated: true)
    }

    @objc private func toggleCommandPalette() {
        commandPaletteController?.toggle(relativeTo: playerController?.window)
    }

    @objc private func reloadPlayer() {
        playerController?.reload()
    }

    @objc private func toggleSidebar() {
        store.toggleSidebar()
    }

    @objc private func toggleFullScreenLyrics() {
        if !store.isFullScreenLyricsVisible {
            playerController?.show()
        }
        store.toggleFullScreenLyrics()
    }

    @objc private func toggleHud() {
        store.isHudVisible.toggle()
    }

    @objc private func toggleMiniPlayer() {
        store.isMiniPlayerVisible.toggle()
    }

    @objc private func toggleMenuBarLyrics() {
        store.menuBarLyricsEnabled.toggle()
    }

    @objc private func resetMiniPosition() {
        miniPlayerController?.resetPosition()
    }

    @objc private func toggleClickThrough() {
        store.isClickThrough.toggle()
    }

    @objc private func toggleCompact() {
        store.toggleDisplayMode()
    }

    @objc private func toggleTheme() {
        store.appleGlassThemeEnabled.toggle()
    }

    @objc private func toggleTranslate() {
        store.translateEnabled.toggle()
    }

    @objc private func toggleAutoRomanize() {
        store.autoRomanizeEnabled.toggle()
    }

    @objc private func selectOpacityPreset(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double {
            store.backgroundOpacity = value
        }
    }

    @objc private func clearCache() {
        store.clearCache()
    }

    @objc private func saveCurrentOffline() {
        store.saveCurrentTrackOffline()
    }

    @objc private func syncOfflinePage() {
        store.downloadOfflineLyricsForCurrentPage()
    }

    @objc private func clearOfflineVault() {
        store.clearOfflineVault()
    }

    @objc private func resetPosition() {
        hudController?.resetPosition()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

@main
enum YTMusicGlassAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
