import AppKit
import Foundation
import UserNotifications

/// Renders a macOS squircle Dock icon from the active album artwork while preserving the original app icon.
@MainActor
final class DockIconController {
    private(set) var baseIcon: NSImage
    private var lastRenderKey: String = ""

    init() {
        self.baseIcon = Self.resolveOriginalAppIcon()
    }

    func captureBaseIconIfNeeded() {
        if baseIcon.size.width <= 0 {
            baseIcon = Self.resolveOriginalAppIcon()
        }
    }

    func update(enabled: Bool, track: TrackInfo?, artwork: NSImage?, isAdPlaying: Bool) {
        let shouldShowArt = enabled && !isAdPlaying && track != nil && artwork != nil
        guard shouldShowArt, let track, let artwork else {
            if lastRenderKey != "base" {
                lastRenderKey = "base"
                NSApp.applicationIconImage = baseIcon
            }
            return
        }

        let artToken = track.artworkUrl ?? "\(track.title)::\(track.artist)"
        let nextKey = "art::\(track.id)::\(artToken)"
        guard nextKey != lastRenderKey else { return }
        lastRenderKey = nextKey

        NSApp.applicationIconImage = renderSquircleArtwork(artwork, badge: baseIcon)
    }

    private static func resolveOriginalAppIcon() -> NSImage {
        if let named = NSImage(named: "AppIcon") {
            return named
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let loaded = NSImage(contentsOf: url)
        {
            return loaded
        }
        return NSApp.applicationIconImage
    }

    private func renderSquircleArtwork(_ artwork: NSImage, badge: NSImage) -> NSImage {
        let canvasSize: CGFloat = 512
        let inset: CGFloat = 50
        let tileRect = NSRect(x: inset, y: inset, width: canvasSize - inset * 2, height: canvasSize - inset * 2)
        let cornerRadius: CGFloat = 92

        let output = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        output.lockFocus()
        defer { output.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high

        // Soft macOS Dock drop shadow beneath the rounded artwork tile
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.shadowBlurRadius = 18
        shadow.set()

        let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor(calibratedWhite: 0.06, alpha: 1.0).setFill()
        tilePath.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Aspect-fill crop inside the macOS squircle clip
        NSGraphicsContext.saveGraphicsState()
        tilePath.addClip()
        let srcSize = artwork.size
        if srcSize.width > 0 && srcSize.height > 0 {
            let scale = max(tileRect.width / srcSize.width, tileRect.height / srcSize.height)
            let drawW = srcSize.width * scale
            let drawH = srcSize.height * scale
            let drawRect = NSRect(
                x: tileRect.midX - drawW * 0.5,
                y: tileRect.midY - drawH * 0.5,
                width: drawW,
                height: drawH
            )
            artwork.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        NSGraphicsContext.restoreGraphicsState()

        // Crisp 1.5pt highlight border so dark covers stay legible against any Dock backdrop
        NSColor.white.withAlphaComponent(0.24).setStroke()
        tilePath.lineWidth = 2.0
        tilePath.stroke()

        // Small YT Music Glass corner badge on bottom-right so the Dock tile remains recognizable
        let badgeSize: CGFloat = 132
        let badgeRect = NSRect(
            x: tileRect.maxX - badgeSize + 14,
            y: tileRect.minY - 14,
            width: badgeSize,
            height: badgeSize
        )
        NSGraphicsContext.saveGraphicsState()
        let badgeShadow = NSShadow()
        badgeShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        badgeShadow.shadowOffset = NSSize(width: 0, height: -4)
        badgeShadow.shadowBlurRadius = 10
        badgeShadow.set()
        badge.draw(in: badgeRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        return output
    }
}

/// Optional silent macOS UserNotifications banner when a new track starts playing in background.
@MainActor
final class NowPlayingBannerService: NSObject, UNUserNotificationCenterDelegate {
    private static let categoryId = "YTMG_NOW_PLAYING"
    private static let nextActionId = "YTMG_NEXT_TRACK"
    private static let togglePlayActionId = "YTMG_TOGGLE_PLAY"
    private static let notificationId = "ytmg.nowplaying.banner"

    private let tempAttachmentURL: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ytmg_now_playing_art.png")

    private var isConfigured = false
    private var lastNotifiedTrackKey: String? = nil
    private var pendingTrackKey: String? = nil
    private var pendingTrack: TrackInfo? = nil
    private var pendingTask: Task<Void, Never>? = nil

    var shouldSuppressBannerInForeground: (() -> Bool)?
    var onOpenApp: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onTogglePlay: (() -> Void)?
    var onAuthorizationStatusChanged: ((String) -> Void)?

    private var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
            && !(Bundle.main.bundleIdentifier?.isEmpty ?? true)
    }

    func configureIfSupported() {
        guard canUseUserNotifications, !isConfigured else { return }
        isConfigured = true

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let toggleAction = UNNotificationAction(
            identifier: Self.togglePlayActionId,
            title: "Play / Pause",
            options: []
        )
        let nextAction = UNNotificationAction(
            identifier: Self.nextActionId,
            title: "Next Track",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryId,
            actions: [toggleAction, nextAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestPermissionAndRefreshStatus() {
        guard canUseUserNotifications else {
            onAuthorizationStatusChanged?("Run inside YT Music Glass.app bundle to enable macOS banners")
            return
        }
        configureIfSupported()
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshAuthorizationStatus()
            }
        }
    }

    func refreshAuthorizationStatus() {
        guard canUseUserNotifications else {
            onAuthorizationStatusChanged?("Available when launched as YT Music Glass.app")
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let message: String
            switch settings.authorizationStatus {
            case .denied:
                message = "Notifications disabled — allow YT Music Glass in macOS System Settings"
            case .notDetermined:
                message = "Silent macOS banner with artwork when track changes in background"
            case .authorized, .provisional, .ephemeral:
                message = "Silent macOS banner with artwork when track changes in background"
            @unknown default:
                message = "Silent macOS banner with artwork when track changes in background"
            }
            Task { @MainActor in
                self?.onAuthorizationStatusChanged?(message)
            }
        }
    }

    func cancelPending(clearLastTrack: Bool = false) {
        pendingTask?.cancel()
        pendingTask = nil
        pendingTrackKey = nil
        pendingTrack = nil
        if clearLastTrack {
            lastNotifiedTrackKey = nil
        }
    }

    func scheduleTrackBanner(
        enabled: Bool,
        trackKey: String?,
        track: TrackInfo?,
        artwork: NSImage?,
        isPaused: Bool,
        isAdPlaying: Bool
    ) {
        guard enabled, canUseUserNotifications, !isPaused, !isAdPlaying, let trackKey, let track, !track.title.isEmpty else {
            if !enabled || isAdPlaying || track == nil {
                cancelPending(clearLastTrack: !enabled || track == nil)
            }
            return
        }

        configureIfSupported()
        guard trackKey != lastNotifiedTrackKey else { return }

        if pendingTrackKey == trackKey {
            pendingTrack = track
            if artwork != nil {
                deliverBannerNow(trackKey: trackKey, track: track, artwork: artwork)
            }
            return
        }

        pendingTask?.cancel()
        pendingTrackKey = trackKey
        pendingTrack = track

        // Wait briefly for artwork extraction so the notification carries album cover art
        let delayNs: UInt64 = artwork != nil ? 350_000_000 : 900_000_000
        pendingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.pendingTrackKey == trackKey, let latestTrack = self.pendingTrack else { return }
                self.deliverBannerNow(trackKey: trackKey, track: latestTrack, artwork: artwork)
            }
        }
    }

    func notifyArtworkArrived(trackKey: String?, track: TrackInfo?, artwork: NSImage?) {
        guard let trackKey, let track, let artwork, pendingTrackKey == trackKey else { return }
        deliverBannerNow(trackKey: trackKey, track: track, artwork: artwork)
    }

    private func deliverBannerNow(trackKey: String, track: TrackInfo, artwork: NSImage?) {
        pendingTask?.cancel()
        pendingTask = nil
        pendingTrackKey = nil
        pendingTrack = nil

        guard trackKey != lastNotifiedTrackKey else { return }
        lastNotifiedTrackKey = trackKey

        if shouldSuppressBannerInForeground?() == true {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            guard authorized else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                let content = UNMutableNotificationContent()
                content.title = track.title
                content.subtitle = track.artist
                if let album = track.album, !album.isEmpty, album.lowercased() != track.title.lowercased() {
                    content.body = album
                } else {
                    content.body = AppIdentity.appName
                }
                content.sound = nil
                content.categoryIdentifier = Self.categoryId

                if let artwork, let attachment = self.createAttachment(from: artwork) {
                    content.attachments = [attachment]
                }

                let request = UNNotificationRequest(
                    identifier: Self.notificationId,
                    content: content,
                    trigger: nil
                )
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    private func createAttachment(from image: NSImage) -> UNNotificationAttachment? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return nil }

        try? FileManager.default.removeItem(at: tempAttachmentURL)
        do {
            try png.write(to: tempAttachmentURL, options: .atomic)
            return try UNNotificationAttachment(identifier: "artwork", url: tempAttachmentURL, options: nil)
        } catch {
            return nil
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            let suppress = self.shouldSuppressBannerInForeground?() ?? false
            completionHandler(suppress ? [] : [.banner])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        Task { @MainActor in
            switch actionId {
            case Self.nextActionId:
                self.onNextTrack?()
            case Self.togglePlayActionId:
                self.onTogglePlay?()
            case UNNotificationDefaultActionIdentifier:
                self.onOpenApp?()
            default:
                break
            }
            completionHandler()
        }
    }
}
