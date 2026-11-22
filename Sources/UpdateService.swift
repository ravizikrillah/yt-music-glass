import Foundation

enum AppIdentity {
    static let appName = "YT Music Glass"
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
    case readyToInstall(fileURL: URL, version: String)
    case error(String)
}

enum SemVerComparator {
    static func normalize(_ raw: String) -> [Int] {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasPrefix("v") {
            cleaned.removeFirst()
        }
        // Strip pre-release / build metadata (e.g. "-beta.1", "+build")
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

final class UpdateService {
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
    }

    func checkForUpdates(currentVersion: String = AppIdentity.currentVersion) async -> UpdateState {
        var req = URLRequest(url: AppIdentity.latestReleaseAPIURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("YTMusicGlass-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return .error("Could not reach GitHub Releases.")
            }

            if http.statusCode == 404 {
                return .upToDate(message: "You're on v\(currentVersion) (no GitHub releases published yet)")
            }
            guard (200..<300).contains(http.statusCode) else {
                return .error("GitHub Releases returned HTTP \(http.statusCode).")
            }

            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = obj["tag_name"] as? String
            else {
                return .error("Invalid release payload from GitHub.")
            }

            let htmlUrlStr = (obj["html_url"] as? String) ?? AppIdentity.githubReleasesURL.absoluteString
            let htmlURL = URL(string: htmlUrlStr) ?? AppIdentity.githubReleasesURL
            let title = (obj["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = (obj["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let publishedAt = obj["published_at"] as? String

            let cleanVersion = tagName.lowercased().hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            guard SemVerComparator.isNewer(cleanVersion, than: currentVersion) else {
                return .upToDate(message: "You're up to date (v\(currentVersion))")
            }

            let assets = (obj["assets"] as? [[String: Any]]) ?? []
            let chosenAsset = pickBestDmgAsset(from: assets)

            let info = GitHubReleaseInfo(
                version: cleanVersion,
                tagName: tagName,
                title: (title?.isEmpty == false ? title! : "\(AppIdentity.appName) \(tagName)"),
                releaseNotes: notes,
                htmlURL: htmlURL,
                publishedAt: publishedAt,
                dmgDownloadURL: chosenAsset?.url,
                dmgFilename: chosenAsset?.name,
                dmgSizeBytes: chosenAsset?.size
            )
            return .available(info)
        } catch let err as URLError where err.code == .notConnectedToInternet {
            return .error("Offline — connect to the internet to check for updates.")
        } catch {
            return .error("Update check failed: \(error.localizedDescription)")
        }
    }

    func downloadDmg(
        from url: URL,
        filename: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        var req = URLRequest(url: url)
        req.setValue("YTMusicGlass-macOS/\(AppIdentity.currentVersion)", forHTTPHeaderField: "User-Agent")

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "UpdateService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to download update installer.",
            ])
        }

        let expected = http.expectedContentLength
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let safeName = filename.isEmpty ? "YT-Music-Glass-Update.dmg" : filename
        let destURL = downloadsDir.appendingPathComponent(safeName)

        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }
        FileManager.default.createFile(atPath: destURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destURL)
        defer { try? handle.close() }

        var buffer = Data()
        buffer.reserveCapacity(65_536)
        var totalWritten: Int64 = 0
        var lastReported: Double = -1

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 65_536 {
                handle.write(buffer)
                totalWritten += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if expected > 0 {
                    let progress = min(1.0, Double(totalWritten) / Double(expected))
                    if progress - lastReported >= 0.02 {
                        lastReported = progress
                        onProgress(progress)
                    }
                }
            }
        }
        if !buffer.isEmpty {
            handle.write(buffer)
            totalWritten += Int64(buffer.count)
        }
        onProgress(1.0)
        return destURL
    }

    private func pickBestDmgAsset(from assets: [[String: Any]]) -> (name: String, url: URL, size: Int64)? {
        #if arch(arm64)
        let preferredTokens = ["arm64", "apple-silicon", "universal"]
        #else
        let preferredTokens = ["x86_64", "intel", "universal"]
        #endif

        var dmgAssets: [(name: String, url: URL, size: Int64, priority: Int)] = []
        for asset in assets {
            guard let name = asset["name"] as? String,
                  name.lowercased().hasSuffix(".dmg"),
                  let urlStr = asset["browser_download_url"] as? String,
                  let url = URL(string: urlStr)
            else { continue }

            let size = (asset["size"] as? NSNumber)?.int64Value ?? 0
            let lower = name.lowercased()
            var priority = 1
            for (idx, token) in preferredTokens.enumerated() where lower.contains(token) {
                priority = 10 - idx
                break
            }
            dmgAssets.append((name, url, size, priority))
        }

        guard let best = dmgAssets.max(by: { $0.priority < $1.priority }) else { return nil }
        return (best.name, best.url, best.size)
    }
}
