import AppKit
import SwiftUI

final class FloatingHudPanel: NSPanel {
    override var canBecomeKey: Bool {
        !ignoresMouseEvents
    }

    override var canBecomeMain: Bool {
        false
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        minSize = NSSize(width: 320, height: 100)
        maxSize = NSSize(width: 1100, height: 920)
    }
}

@MainActor
final class HudWindowController: NSObject, NSWindowDelegate {
    let panel: FloatingHudPanel
    private let store: AppStore
    private var currentMode: HudDisplayMode

    private static let compactFrameKey = "hud_frame_compact"
    private static let fullFrameKey = "hud_frame_full"

    init(store: AppStore) {
        self.store = store
        self.currentMode = store.displayMode

        let initialRect = HudWindowController.loadFrame(for: store.displayMode)
            ?? HudWindowController.defaultFrame(for: store.displayMode)
        self.panel = FloatingHudPanel(contentRect: initialRect)
        super.init()

        self.panel.delegate = self

        let hosting = NSHostingView(rootView: HudContentView(store: store))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        self.panel.contentView = hosting
        self.panel.ignoresMouseEvents = store.isClickThrough

        store.onDisplayModeChanged = { [weak self] mode in
            self?.switchMode(to: mode)
        }
        store.onClickThroughChanged = { [weak self] locked in
            self?.panel.ignoresMouseEvents = locked
        }
        store.onHudVisibilityChanged = { [weak self] visible in
            if visible {
                self?.panel.orderFrontRegardless()
            } else {
                self?.panel.orderOut(nil)
            }
        }
    }

    func show() {
        store.isHudVisible = true
        panel.orderFrontRegardless()
    }

    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.compactFrameKey)
        UserDefaults.standard.removeObject(forKey: Self.fullFrameKey)
        let target = Self.defaultFrame(for: store.displayMode)
        panel.setFrame(target, display: true, animate: true)
    }

    private func switchMode(to nextMode: HudDisplayMode) {
        guard nextMode != currentMode else { return }
        saveFrame(panel.frame, for: currentMode)
        currentMode = nextMode

        let target = Self.loadFrame(for: nextMode) ?? Self.defaultFrame(for: nextMode)
        panel.setFrame(target, display: true, animate: true)
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame(panel.frame, for: currentMode)
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame(panel.frame, for: currentMode)
    }

    private func saveFrame(_ frame: NSRect, for mode: HudDisplayMode) {
        let key = mode == .compact ? Self.compactFrameKey : Self.fullFrameKey
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: key)
    }

    private static func loadFrame(for mode: HudDisplayMode) -> NSRect? {
        let key = mode == .compact ? compactFrameKey : fullFrameKey
        guard let str = UserDefaults.standard.string(forKey: key) else { return nil }
        let rect = NSRectFromString(str)
        return rect.width >= 300 && rect.height >= 96 ? rect : nil
    }

    private static func defaultFrame(for mode: HudDisplayMode) -> NSRect {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        switch mode {
        case .compact:
            let w: CGFloat = 640
            let h: CGFloat = 142
            let x = visible.midX - w / 2
            let y = visible.minY + 34
            return NSRect(x: x, y: y, width: w, height: h)
        case .full:
            let w: CGFloat = 430
            let h: CGFloat = 530
            let x = visible.maxX - w - 28
            let y = visible.minY + 56
            return NSRect(x: x, y: y, width: w, height: h)
        }
    }
}
