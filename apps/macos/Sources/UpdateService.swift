import Foundation

final class UpdateService {
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 12
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.urlCache = nil
        self.session = URLSession(configuration: cfg)
    }

    func checkForUpdates(currentVersion: String = AppIdentity.currentVersion) async -> UpdateState {
        var req = URLRequest(
            url: AppIdentity.latestReleaseAPIURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 12
        )
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
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

    static func resolveInstallDestinationURL(
        currentBundleURL: URL = Bundle.main.bundleURL,
        fileManager: FileManager = .default
    ) -> URL {
        let fallbackURL = URL(fileURLWithPath: "/Applications/\(AppIdentity.appName).app")
        let path = currentBundleURL.path
        guard currentBundleURL.pathExtension.lowercased() == "app" else {
            return fallbackURL
        }
        if path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/") {
            return fallbackURL
        }
        let parentDir = currentBundleURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parentDir.path) else {
            return fallbackURL
        }
        return currentBundleURL
    }

    /// Mounts the downloaded DMG silently, stages the new .app bundle, detaches the DMG,
    /// and spawns a detached helper script that performs an atomic swap and relaunches the app.
    func installDmgAndScheduleRelaunch(
        from dmgURL: URL,
        destinationAppURL: URL = UpdateService.resolveInstallDestinationURL()
    ) async throws {
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ytmg_update_\(UUID().uuidString)", isDirectory: true)
        let mountPoint = stagingDir.appendingPathComponent("mount", isDirectory: true)
        let stagedAppURL = stagingDir.appendingPathComponent("\(AppIdentity.appName).app", isDirectory: true)
        let scriptURL = stagingDir.appendingPathComponent("apply_update.sh")

        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        let destParent = destinationAppURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: destParent.path) else {
            try? FileManager.default.removeItem(at: stagingDir)
            throw NSError(domain: "UpdateService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Destination folder \(destParent.path) is not writable.",
            ])
        }

        // 1. Mount DMG silently and copy .app bundle to local staging on a background queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var mounted = false
                defer {
                    if mounted {
                        _ = try? Self.runCommandSync(
                            executable: "/usr/bin/hdiutil",
                            arguments: ["detach", mountPoint.path, "-quiet", "-force"]
                        )
                    }
                }

                do {
                    try Self.runCommandSync(
                        executable: "/usr/bin/hdiutil",
                        arguments: [
                            "attach", dmgURL.path,
                            "-nobrowse", "-readonly", "-noverify",
                            "-mountpoint", mountPoint.path,
                        ]
                    )
                    mounted = true

                    let sourceAppURL = Self.locateAppBundle(in: mountPoint)
                    guard let sourceAppURL else {
                        throw NSError(domain: "UpdateService", code: 3, userInfo: [
                            NSLocalizedDescriptionKey: "Could not locate \(AppIdentity.appName).app inside DMG.",
                        ])
                    }

                    try Self.runCommandSync(
                        executable: "/usr/bin/ditto",
                        arguments: [sourceAppURL.path, stagedAppURL.path]
                    )
                    _ = try? Self.runCommandSync(
                        executable: "/usr/bin/xattr",
                        arguments: ["-cr", stagedAppURL.path]
                    )

                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // 2. Write atomic swap & relaunch helper script and launch it detached before app quits
        let helperScript = """
        #!/usr/bin/env bash
        set -u
        OLD_PID="$1"
        STAGED_APP="$2"
        DEST_APP="$3"
        STAGING_DIR="$4"
        DMG_PATH="$5"

        for _ in $(seq 1 40); do
          if ! kill -0 "$OLD_PID" 2>/dev/null; then
            break
          fi
          sleep 0.2
        done

        DEST_PARENT="$(dirname "$DEST_APP")"
        mkdir -p "$DEST_PARENT"
        BACKUP_APP="${DEST_APP}.prev_backup_$$"

        if [ -e "$DEST_APP" ]; then
          if ! mv "$DEST_APP" "$BACKUP_APP"; then
            rm -rf "$STAGING_DIR"
            exit 1
          fi
        fi

        if /usr/bin/ditto "$STAGED_APP" "$DEST_APP"; then
          /usr/bin/xattr -cr "$DEST_APP" >/dev/null 2>&1 || true
          rm -rf "$BACKUP_APP"
          rm -f "$DMG_PATH" >/dev/null 2>&1 || true
          /usr/bin/open -n "$DEST_APP"
          rm -rf "$STAGING_DIR"
        else
          if [ -e "$BACKUP_APP" ]; then
            rm -rf "$DEST_APP"
            mv "$BACKUP_APP" "$DEST_APP" || true
          fi
          rm -rf "$STAGING_DIR"
          exit 1
        fi
        """

        try helperScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let pid = String(ProcessInfo.processInfo.processIdentifier)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        proc.arguments = [
            "/bin/bash",
            scriptURL.path,
            pid,
            stagedAppURL.path,
            destinationAppURL.path,
            stagingDir.path,
            dmgURL.path,
        ]
        proc.standardInput = FileHandle.nullDevice
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
    }

    private static func locateAppBundle(in mountPoint: URL) -> URL? {
        let exact = mountPoint.appendingPathComponent("\(AppIdentity.appName).app", isDirectory: true)
        if FileManager.default.fileExists(atPath: exact.appendingPathComponent("Contents/Info.plist").path) {
            return exact
        }
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: mountPoint,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        return items.first { url in
            url.pathExtension.lowercased() == "app" &&
                FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path)
        }
    }

    @discardableResult
    private static func runCommandSync(executable: String, arguments: [String]) throws -> Int32 {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        let errPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = errPipe
        try proc.run()
        proc.waitUntilExit()

        if proc.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw NSError(domain: "UpdateService", code: Int(proc.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: errText.isEmpty ? "Command \(executable) failed (\(proc.terminationStatus))." : errText,
            ])
        }
        return proc.terminationStatus
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
