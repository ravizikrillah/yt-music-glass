import AppKit
import SwiftUI

@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let store: AppStore

    init(store: AppStore) {
        self.store = store
        let rect = NSRect(x: 0, y: 0, width: 432, height: 520)
        self.window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.window.title = "About \(AppIdentity.appName)"
        self.window.titleVisibility = .hidden
        self.window.titlebarAppearsTransparent = true
        self.window.isMovableByWindowBackground = true
        self.window.appearance = NSAppearance(named: .darkAqua)
        self.window.backgroundColor = NSColor(red: 0.032, green: 0.032, blue: 0.044, alpha: 1.0)
        self.window.isReleasedWhenClosed = false
        self.window.center()

        super.init()
        self.window.delegate = self

        let hosting = NSHostingView(rootView: AboutContentView(store: store))
        hosting.safeAreaRegions = []
        hosting.sizingOptions = []
        self.window.contentView = hosting
    }

    func show(checkIfNeeded: Bool = true) {
        if checkIfNeeded {
            switch store.updateState {
            case .idle, .upToDate, .error:
                store.checkForUpdates(userInitiated: true)
            case .checking, .available, .downloading, .readyToInstall:
                break
            }
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AboutContentView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            Color(red: 0.032, green: 0.032, blue: 0.044)
                .ignoresSafeArea()

            // Subtle top crimson-accent halo behind App Icon
            RadialGradient(
                colors: [
                    Color(red: 0.88, green: 0.12, blue: 0.28).opacity(0.18),
                    Color.clear,
                ],
                center: .top,
                startRadius: 12,
                endRadius: 230
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // App Icon + Identity Hero
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .shadow(color: Color(red: 0.88, green: 0.12, blue: 0.28).opacity(0.35), radius: 18, x: 0, y: 8)

                    VStack(spacing: 4) {
                        Text(AppIdentity.appName)
                            .font(AppFont.styled(20, weight: .bold, style: store.fontStyle))
                            .foregroundStyle(.white.opacity(0.96))

                        HStack(spacing: 6) {
                            Text("Version \(AppIdentity.currentVersion) (\(AppIdentity.currentBuild))")
                                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.56))

                            Text("Native Swift")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(store.palette.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(store.palette.accentColor.opacity(0.16))
                                .clipShape(Capsule())
                        }
                    }

                    Text("Lightweight native macOS client for YouTube Music with synced karaoke lyrics, Auto-Romaji, Smart Translate & Offline Vault.")
                        .font(AppFont.styled(11.5, weight: .regular, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
                .padding(.top, 30)

                // GitHub Releases Auto-Update Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(store.palette.accentColor)
                            Text("SOFTWARE UPDATE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(.white.opacity(0.54))
                        }
                        Spacer()
                        Text("GitHub Releases")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))
                    }

                    updateStatusView
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.072, green: 0.072, blue: 0.102).opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

                // Developer & Open Source Links Card
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(store.palette.accentColor)
                        Text("DEVELOPER")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(.white.opacity(0.54))
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppIdentity.developerName)
                                .font(AppFont.styled(13.5, weight: .bold, style: store.fontStyle))
                                .foregroundStyle(.white.opacity(0.95))
                            Text("@\(AppIdentity.githubOwner) · Open Source on GitHub")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.52))
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        linkPill("GitHub Repo", icon: "chevron.left.forwardslash.chevron.right", accent: true) {
                            NSWorkspace.shared.open(AppIdentity.githubRepoURL)
                        }
                        linkPill("Profile", icon: "person") {
                            NSWorkspace.shared.open(AppIdentity.githubProfileURL)
                        }
                        linkPill("Website", icon: "globe") {
                            NSWorkspace.shared.open(AppIdentity.websiteURL)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.072, green: 0.072, blue: 0.102).opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

                Spacer(minLength: 2)

                Text("Built with pure Swift, SwiftUI, AppKit & WKWebView · Zero Electron")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.36))
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 20)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch store.updateState {
        case .idle:
            HStack {
                Text("Check GitHub Releases for the latest macOS DMG.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
                linkPill("Check Now", icon: "arrow.clockwise", accent: true) {
                    store.checkForUpdates(userInitiated: true)
                }
            }

        case .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(store.palette.accentColor)
                Text("Checking GitHub Releases...")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.76))
                Spacer()
            }

        case .upToDate(let message):
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(store.palette.accentColor)
                    Text(message)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
                Spacer(minLength: 6)
                linkPill("Re-check", icon: "arrow.clockwise") {
                    store.checkForUpdates(userInitiated: true)
                }
            }

        case .available(let release):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Update available: v\(release.version)")
                        .font(AppFont.styled(12.5, weight: .bold, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.96))
                    Spacer()
                    if let bytes = release.dmgSizeBytes, bytes > 0 {
                        Text(String(format: "%.1f MB", Double(bytes) / 1_048_576.0))
                            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.54))
                    }
                }

                if !release.releaseNotes.isEmpty {
                    Text(release.releaseNotes)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    if release.dmgDownloadURL != nil {
                        linkPill("Download & Open DMG", icon: "arrow.down.circle.fill", accent: true) {
                            store.downloadAndOpenUpdate()
                        }
                    }
                    linkPill("Release Notes", icon: "arrow.up.right") {
                        NSWorkspace.shared.open(release.htmlURL)
                    }
                }
            }

        case .downloading(let progress, let version):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading v\(version)...")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(store.palette.accentColor)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.16))
                        Capsule()
                            .fill(store.palette.accentColor)
                            .frame(width: max(4, geo.size.width * progress))
                    }
                }
                .frame(height: 5)
            }

        case .readyToInstall(let fileURL, let version):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("v\(version) downloaded!")
                        .font(AppFont.styled(12, weight: .bold, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.95))
                    Text("Drag YT Music Glass into Applications.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
                linkPill("Open DMG", icon: "externaldrive.badge.checkmark", accent: true) {
                    NSWorkspace.shared.open(fileURL)
                }
            }

        case .error(let msg):
            HStack {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange.opacity(0.9))
                    .lineLimit(2)
                Spacer(minLength: 6)
                linkPill("Retry", icon: "arrow.clockwise") {
                    store.checkForUpdates(userInitiated: true)
                }
            }
        }
    }

    private func linkPill(
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
            .frame(height: 27)
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
