import Foundation

enum AppIdentity {
    static let appName = "YT Music Glass"
    static let bundleIdentifier = "com.ytmusicglass.app"
    static let legacyBundleIdentifier = "com.ytmkaraokefloat.app"
    static let appSupportFolderName = "YTMusicGlass"
    static let legacyAppSupportFolderName = "YTMKaraoke"
    static let developerName = "Ravi Bangkit Nur Zikrillah"
    static let githubOwner = "ravizikrillah"
    static let githubRepo = "yt-music-glass"

    static var githubProfileURL: URL {
        URL(string: "https://github.com/\(githubOwner)")!
    }

    static var githubRepoURL: URL {
        URL(string: "https://github.com/\(githubOwner)/\(githubRepo)")!
    }

    static var githubReleasesURL: URL {
        URL(string: "https://github.com/\(githubOwner)/\(githubRepo)/releases")!
    }

    static var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")!
    }

    static let websiteURL = URL(string: "https://yt-music-glass.vercel.app")!

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    static var currentBuild: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }

    /// Resolves the Application Support directory and migrates data from the legacy `YTMKaraoke` folder once if present.
    static func appSupportDirectory(
        in baseURL: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let base = baseURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let newDir = base.appendingPathComponent(appSupportFolderName, isDirectory: true)
        let legacyDir = base.appendingPathComponent(legacyAppSupportFolderName, isDirectory: true)

        if fileManager.fileExists(atPath: legacyDir.path) {
            if !fileManager.fileExists(atPath: newDir.path) {
                if (try? fileManager.moveItem(at: legacyDir, to: newDir)) == nil {
                    try? fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
                }
            }
            if fileManager.fileExists(atPath: legacyDir.path),
               let items = try? fileManager.contentsOfDirectory(at: legacyDir, includingPropertiesForKeys: nil)
            {
                try? fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
                for src in items {
                    let dst = newDir.appendingPathComponent(src.lastPathComponent)
                    if !fileManager.fileExists(atPath: dst.path) {
                        try? fileManager.copyItem(at: src, to: dst)
                    }
                }
            }
        }

        try? fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
        return newDir
    }

    /// Preserves saved preferences and window frames when moving from the legacy bundle identifier.
    static func migrateLegacyUserDefaultsIfNeeded(
        target defaults: UserDefaults = .standard,
        legacySuiteName: String = legacyBundleIdentifier
    ) {
        let migrationKey = "app_migrated_from_legacy_bundle_v1"
        guard !defaults.bool(forKey: migrationKey) else { return }
        guard Bundle.main.bundleIdentifier != legacySuiteName else { return }

        if let legacyDomain = defaults.persistentDomain(forName: legacySuiteName), !legacyDomain.isEmpty {
            let legacyWindowKey = "NSWindow Frame YTMKaraokeMainWindow"
            let newWindowKey = "NSWindow Frame YTMusicGlassMainWindow"
            for (key, value) in legacyDomain {
                let isAppKey = key.hasPrefix("app_") || key.hasPrefix("hud_") || key == "mini_player_frame"
                guard key == legacyWindowKey || isAppKey else { continue }
                let targetKey = (key == legacyWindowKey) ? newWindowKey : key
                if defaults.object(forKey: targetKey) == nil {
                    defaults.set(value, forKey: targetKey)
                }
            }
        }
        defaults.set(true, forKey: migrationKey)
    }
}

struct GitHubReleaseInfo: Equatable {
    let version: String
    let tagName: String
    let title: String
    let releaseNotes: String
    let htmlURL: URL
    let publishedAt: String?
    let dmgDownloadURL: URL?
    let dmgFilename: String?
    let dmgSizeBytes: Int64?
}

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate(message: String)
    case available(GitHubReleaseInfo)
    case downloading(progress: Double, version: String)
    case installing(version: String)
    case readyToInstall(fileURL: URL, version: String)
    case error(String)
}

enum SemVerComparator {
    static func normalize(_ raw: String) -> [Int] {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasPrefix("v") {
            cleaned.removeFirst()
        }
        if let dash = cleaned.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            cleaned = String(cleaned[..<dash])
        }
        return cleaned.split(separator: ".").map { Int($0) ?? 0 }
    }

    static func isNewer(_ remote: String, than current: String) -> Bool {
        let r = normalize(remote)
        let c = normalize(current)
        let count = max(r.count, c.count)
        guard count > 0 else { return false }
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv {
                return rv > cv
            }
        }
        return false
    }
}
