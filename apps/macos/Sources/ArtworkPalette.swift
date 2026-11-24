import AppKit
import CoreText
import SwiftUI

enum AppFontStyle: String, CaseIterable, Identifiable {
    case roboto = "roboto"
    case sfPro = "sfpro"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .roboto: return "Roboto"
        case .sfPro: return "SF Pro"
        }
    }

    var displayLabel: String {
        switch self {
        case .roboto: return "Roboto (YouTube Music)"
        case .sfPro: return "SF Pro (macOS Native)"
        }
    }
}

enum AppFont {
    static func registerBundledFonts() {
        guard let fontsDir = Bundle.main.resourceURL?.appendingPathComponent("Fonts") else { return }
        for file in ["Roboto-Regular.ttf", "Roboto-Medium.ttf", "Roboto-Bold.ttf"] {
            let url = fontsDir.appendingPathComponent(file) as CFURL
            CTFontManagerRegisterFontsForURL(url, .process, nil)
        }
    }

    static func roboto(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:
            name = "Roboto-Bold"
        case .semibold, .medium:
            name = "Roboto-Medium"
        default:
            name = "Roboto-Regular"
        }
        return .custom(name, size: size)
    }

    static func styled(_ size: CGFloat, weight: Font.Weight = .regular, style: AppFontStyle) -> Font {
        switch style {
        case .roboto:
            return roboto(size, weight: weight)
        case .sfPro:
            return .system(size: size, weight: weight)
        }
    }
}

struct AlbumPalette: Equatable {
    let accentR: Double
    let accentG: Double
    let accentB: Double
    let bgTopHex: String
    let bgBottomHex: String
    let artworkUrl: String?

    var accentRGBString: String {
        "\(Int(accentR.rounded())), \(Int(accentG.rounded())), \(Int(accentB.rounded()))"
    }

    var accentColor: Color {
        Color(red: accentR / 255.0, green: accentG / 255.0, blue: accentB / 255.0)
    }

    var bgTopColor: Color {
        Self.color(fromHex: bgTopHex)
    }

    var bgBottomColor: Color {
        Self.color(fromHex: bgBottomHex)
    }

    static let defaultGlass = AlbumPalette(
        accentR: 244,
        accentG: 63,
        accentB: 108,
        bgTopHex: "#24111c",
        bgBottomHex: "#0b0b11",
        artworkUrl: nil
    )

    private static let fallbacks: [AlbumPalette] = [
        AlbumPalette(accentR: 244, accentG: 63, accentB: 108, bgTopHex: "#2a1220", bgBottomHex: "#0b0b11", artworkUrl: nil),
        AlbumPalette(accentR: 112, accentG: 124, accentB: 255, bgTopHex: "#151833", bgBottomHex: "#0a0c14", artworkUrl: nil),
        AlbumPalette(accentR: 46, accentG: 184, accentB: 245, bgTopHex: "#0d2233", bgBottomHex: "#080d14", artworkUrl: nil),
        AlbumPalette(accentR: 245, accentG: 158, accentB: 66, bgTopHex: "#2b1d10", bgBottomHex: "#0e0c0a", artworkUrl: nil),
        AlbumPalette(accentR: 45, accentG: 204, accentB: 156, bgTopHex: "#0e2620", bgBottomHex: "#090f0d", artworkUrl: nil),
        AlbumPalette(accentR: 186, accentG: 112, accentB: 252, bgTopHex: "#221433", bgBottomHex: "#0c0a14", artworkUrl: nil),
    ]

    static func fallback(seed: String, artworkUrl: String?) -> AlbumPalette {
        var hash = 0
        for scalar in seed.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        let chosen = fallbacks[abs(hash) % fallbacks.count]
        return AlbumPalette(
            accentR: chosen.accentR,
            accentG: chosen.accentG,
            accentB: chosen.accentB,
            bgTopHex: chosen.bgTopHex,
            bgBottomHex: chosen.bgBottomHex,
            artworkUrl: artworkUrl
        )
    }

    static func calibrated(r: Double, g: Double, b: Double, artworkUrl: String?) -> AlbumPalette {
        // Boost dim colors slightly so accent pills & progress bar always pop cleanly
        let maxC = max(r, g, b, 1.0)
        let boost = maxC < 155.0 ? (175.0 / maxC) : 1.0
        let ar = min(255.0, max(40.0, r * boost))
        let ag = min(255.0, max(40.0, g * boost))
        let ab = min(255.0, max(40.0, b * boost))

        // Strictly clamp backdrop luminance for Apple Music dark-mode readability
        let topR = ar * 0.21 + 11.0
        let topG = ag * 0.21 + 10.0
        let topB = ab * 0.23 + 15.0

        let botR = ar * 0.06 + 8.0
        let botG = ag * 0.06 + 8.0
        let botB = ab * 0.08 + 12.0

        return AlbumPalette(
            accentR: ar,
            accentG: ag,
            accentB: ab,
            bgTopHex: hex(topR, topG, topB),
            bgBottomHex: hex(botR, botG, botB),
            artworkUrl: artworkUrl
        )
    }

    private static func hex(_ r: Double, _ g: Double, _ b: Double) -> String {
        let ri = max(0, min(255, Int(r.rounded())))
        let gi = max(0, min(255, Int(g.rounded())))
        let bi = max(0, min(255, Int(b.rounded())))
        return String(format: "#%02x%02x%02x", ri, gi, bi)
    }

    private static func color(fromHex hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let val = UInt64(cleaned, radix: 16) else {
            return Color(red: 0.06, green: 0.06, blue: 0.09)
        }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

final class ArtworkPaletteExtractor {
    private var cache: [String: (palette: AlbumPalette, image: NSImage?)] = [:]
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 6
        self.session = URLSession(configuration: cfg)
    }

    func extract(artworkUrl: String?, seed: String) async -> (palette: AlbumPalette, image: NSImage?) {
        guard let urlStr = artworkUrl, !urlStr.isEmpty, let url = URL(string: urlStr) else {
            return (AlbumPalette.fallback(seed: seed, artworkUrl: nil), nil)
        }

        if let cached = cache[urlStr] {
            return cached
        }

        do {
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let image = NSImage(data: data)
            else {
                return (AlbumPalette.fallback(seed: seed, artworkUrl: urlStr), nil)
            }

            let palette = Self.samplePalette(from: image, artworkUrl: urlStr)
                ?? AlbumPalette.fallback(seed: seed, artworkUrl: urlStr)

            if cache.count > 60 {
                cache.removeAll()
            }
            cache[urlStr] = (palette, image)
            return (palette, image)
        } catch {
            return (AlbumPalette.fallback(seed: seed, artworkUrl: urlStr), nil)
        }
    }

    private static func samplePalette(from image: NSImage, artworkUrl: String) -> AlbumPalette? {
        let sampleSize = 16
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: sampleSize,
            pixelsHigh: sampleSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: sampleSize * 4,
            bitsPerPixel: 32
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            ctx.imageInterpolation = .low
            image.draw(
                in: NSRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
                from: .zero,
                operation: .copy,
                fraction: 1.0
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        var sumR = 0.0
        var sumG = 0.0
        var sumB = 0.0
        var weightSum = 0.0

        for y in 0..<sampleSize {
            for x in 0..<sampleSize {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let r = Double(color.redComponent) * 255.0
                let g = Double(color.greenComponent) * 255.0
                let b = Double(color.blueComponent) * 255.0

                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let sat = maxC == 0 ? 0 : (maxC - minC) / maxC
                let lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

                // Favor vibrant mid-tones over near-black or near-white margins
                let weight = 0.18 + sat * 2.8 * (1.0 - abs(lum - 0.48))
                sumR += r * weight
                sumG += g * weight
                sumB += b * weight
                weightSum += weight
            }
        }

        guard weightSum > 0 else { return nil }
        return AlbumPalette.calibrated(
            r: sumR / weightSum,
            g: sumG / weightSum,
            b: sumB / weightSum,
            artworkUrl: artworkUrl
        )
    }
}
