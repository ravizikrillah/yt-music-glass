import Foundation

private enum SharedWebAssetLoader {
    static func loadResource(name: String, ext: String) -> String {
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "SharedWeb"),
           let text = try? String(contentsOf: url, encoding: .utf8)
        {
            return text
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext),
           let text = try? String(contentsOf: url, encoding: .utf8)
        {
            return text
        }

        let devWebDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("web", isDirectory: true)
        let devURL = devWebDir.appendingPathComponent("\(name).\(ext)")
        if let text = try? String(contentsOf: devURL, encoding: .utf8) {
            return text
        }
        return ""
    }

    static func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let wrapped = String(data: data, encoding: .utf8),
              wrapped.count >= 2
        else {
            return "\"\""
        }
        return String(wrapped.dropFirst().dropLast())
    }
}

enum ThemeStyles {
    static var appleGlassCSS: String {
        SharedWebAssetLoader.loadResource(name: "theme-glass", ext: "css")
    }

    static var installerScript: String {
        let cssLiteral = SharedWebAssetLoader.jsStringLiteral(appleGlassCSS)
        let installer = SharedWebAssetLoader.loadResource(name: "theme-installer", ext: "js")
        return "window.__YTMG_GLASS_CSS__ = \(cssLiteral);\n\(installer)"
    }
}

enum WebBridgeScript {
    static var source: String {
        SharedWebAssetLoader.loadResource(name: "bridge", ext: "js")
    }
}
