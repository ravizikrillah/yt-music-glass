import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let store: AppStore

    init(store: AppStore) {
        self.store = store
        let rect = NSRect(x: 0, y: 0, width: 496, height: 590)
        self.window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.window.title = "YT Music Glass Settings"
        self.window.titleVisibility = .hidden
        self.window.titlebarAppearsTransparent = true
        self.window.isMovableByWindowBackground = true
        self.window.appearance = NSAppearance(named: .darkAqua)
        self.window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.055, alpha: 1.0)
        self.window.isReleasedWhenClosed = false
        self.window.center()

        super.init()
        self.window.delegate = self

        let hosting = NSHostingView(rootView: SettingsContentView(store: store))
        hosting.safeAreaRegions = []
        hosting.sizingOptions = []
        self.window.contentView = hosting
    }

    func show() {
        store.refreshLaunchAtLoginStatus()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsContentView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            Color(red: 0.032, green: 0.032, blue: 0.044)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(store.palette.accentColor.opacity(0.20))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(store.palette.accentColor.opacity(0.45), lineWidth: 1))
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(store.palette.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Settings")
                            .font(AppFont.styled(16, weight: .bold, style: store.fontStyle))
                            .foregroundStyle(.white.opacity(0.96))
                        Text("YT Music Glass · Native macOS")
                            .font(AppFont.styled(11.5, weight: .regular, style: store.fontStyle))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    Spacer()
                }
                .padding(.top, 34)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Section 1: Appearance & Typography
                        settingsCard(title: "Appearance & Typography", icon: "textformat") {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("App & Lyrics Font")
                                            .font(AppFont.styled(12.5, weight: .medium, style: store.fontStyle))
                                            .foregroundStyle(.white.opacity(0.92))
                                        Text("Switch live between YouTube Music Roboto and macOS SF Pro")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.white.opacity(0.48))
                                    }
                                    Spacer()
                                    HStack(spacing: 2) {
                                        ForEach(AppFontStyle.allCases) { style in
                                            let active = store.fontStyle == style
                                            Button {
                                                store.fontStyle = style
                                            } label: {
                                                Text(style.shortLabel)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(active ? .white : .white.opacity(0.56))
                                                    .padding(.horizontal, 10)
                                                    .frame(height: 24)
                                                    .background(active ? store.palette.accentColor.opacity(0.24) : Color.clear)
                                                    .clipShape(Capsule())
                                                    .overlay(
                                                        Capsule().strokeBorder(
                                                            active ? store.palette.accentColor.opacity(0.48) : Color.clear,
                                                            lineWidth: 1
                                                        )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(2)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                                }

                                dividerLine

                                settingsToggleRow(
                                    title: "Seamless Dark Glass Theme",
                                    subtitle: "Spotify-style floating player bar, dynamic logo & clean Watch tabs",
                                    isOn: $store.appleGlassThemeEnabled
                                )

                                dividerLine

                                settingsToggleRow(
                                    title: "Live Mini Audio Visualizer",
                                    subtitle: "Animated theme-colored equalizer bars while music plays",
                                    isOn: $store.audioVisualizerEnabled
                                )

                                dividerLine

                                HStack {
                                    Text("Lyrics Text Size")
                                        .font(AppFont.styled(12.5, weight: .medium, style: store.fontStyle))
                                        .foregroundStyle(.white.opacity(0.92))
                                    Spacer()
                                    Slider(value: $store.fontScale, in: 0.75...1.6)
                                        .controlSize(.small)
                                        .frame(width: 145)
                                        .tint(store.palette.accentColor)
                                    Text("\(Int((store.fontScale * 100).rounded()))%")
                                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.72))
                                        .frame(width: 38, alignment: .trailing)
                                }
                            }
                        }

                        // Section 2: Romaji & Smart Translate
                        settingsCard(title: "Lyrics, Romaji & Translate", icon: "character.bubble") {
                            VStack(spacing: 12) {
                                settingsToggleRow(
                                    title: "Auto Romaji / Romanization",
                                    subtitle: "100% offline pronunciation for Korean, Japanese, Mandarin & more",
                                    isOn: $store.autoRomanizeEnabled
                                )

                                dividerLine

                                settingsToggleRow(
                                    title: "Smart Lyrics Translation",
                                    subtitle: "Auto-hides when song already matches your target language",
                                    isOn: $store.translateEnabled
                                )

                                dividerLine

                                HStack(spacing: 12) {
                                    HStack(spacing: 6) {
                                        Text("From")
                                            .font(.system(size: 11.5, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.56))
                                        Picker("", selection: $store.translateSource) {
                                            ForEach(TranslateSourceLanguage.allCases) { src in
                                                Text(src.displayName).tag(src)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity)
                                    }

                                    HStack(spacing: 6) {
                                        Text("To")
                                            .font(.system(size: 11.5, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.56))
                                        Picker("", selection: $store.translateTarget) {
                                            ForEach(TranslateTargetLanguage.allCases) { dst in
                                                Text(dst.displayName).tag(dst)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }

                        // Section 3: Native macOS Integration
                        settingsCard(title: "macOS Integration", icon: "macwindow") {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Launch at Login")
                                            .font(AppFont.styled(12.5, weight: .medium, style: store.fontStyle))
                                            .foregroundStyle(.white.opacity(0.92))
                                        Text(store.launchAtLoginHint)
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.white.opacity(0.48))
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { store.launchAtLoginEnabled },
                                        set: { store.setLaunchAtLogin($0) }
                                    ))
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .tint(store.palette.accentColor)
                                }

                                dividerLine

                                settingsToggleRow(
                                    title: "Menu Bar Live Lyrics (⇧⌘B)",
                                    subtitle: "Show active lyric line right next to the top Menu Bar icon",
                                    isOn: $store.menuBarLyricsEnabled
                                )

                                dividerLine

                                settingsToggleRow(
                                    title: "Floating Mini Player (⇧⌘P)",
                                    subtitle: "Compact floating widget with artwork, controls & 1-line lyrics",
                                    isOn: $store.isMiniPlayerVisible
                                )

                                dividerLine

                                settingsToggleRow(
                                    title: "Auto-Check Updates (GitHub Releases)",
                                    subtitle: "Silently check github.com/\(AppIdentity.githubOwner)/\(AppIdentity.githubRepo) on launch",
                                    isOn: $store.autoCheckUpdatesEnabled
                                )
                            }
                        }

                        // Section 4: Offline Vault & Cache
                        settingsCard(title: "Offline Vault & Storage", icon: "arrow.down.circle") {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Saved Offline Lyrics")
                                            .font(AppFont.styled(12.5, weight: .medium, style: store.fontStyle))
                                            .foregroundStyle(.white.opacity(0.92))
                                        Text("Permanently pinned from Downloads & manual saves")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.white.opacity(0.48))
                                    }
                                    Spacer()
                                    Text("\(store.offlineSavedCount) tracks")
                                        .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(store.palette.accentColor)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(store.palette.accentColor.opacity(0.16))
                                        .clipShape(Capsule())
                                }

                                HStack(spacing: 8) {
                                    settingsActionButton("Sync Current Page", icon: "arrow.down.circle", accent: true) {
                                        store.downloadOfflineLyricsForCurrentPage()
                                    }
                                    settingsActionButton("Clear Temp Cache (\(store.lyricsService.cacheCount()))", icon: "trash") {
                                        store.clearCache()
                                    }
                                    if store.offlineSavedCount > 0 {
                                        settingsActionButton("Clear Vault", icon: "xmark.bin") {
                                            store.clearOfflineVault()
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    .padding(18)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.palette.accentColor)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.56))
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.072, green: 0.072, blue: 0.102).opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func settingsToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.styled(12.5, weight: .medium, style: store.fontStyle))
                    .foregroundStyle(.white.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer(minLength: 10)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(store.palette.accentColor)
        }
    }

    private func settingsActionButton(
        _ title: String,
        icon: String,
        accent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(accent ? store.palette.accentColor : .white.opacity(0.76))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(accent ? store.palette.accentColor.opacity(0.18) : Color.white.opacity(0.07))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    accent ? store.palette.accentColor.opacity(0.42) : Color.white.opacity(0.11),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}
