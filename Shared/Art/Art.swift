import ImageIO
import UIKit

extension Bundle {
    /// The app's own bundle, also when asked from inside its widget extension.
    static let app: Bundle = {
        let main = Bundle.main
        guard main.bundleURL.pathExtension == "appex" else { return main }
        return Bundle(url: main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()) ?? main
    }()
}

/// Bundled artwork, decoded off the main thread at the size it is drawn at, and kept.
enum Art {
    /// The longest side, in pixels, an artwork is decoded to.
    enum Size: Int, Sendable {
        case tile = 220
        case widget = 640
        case card = 1000
    }

    // NSCache is safe to use from any thread.
    nonisolated(unsafe) private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 160
        return cache
    }()
    nonisolated(unsafe) private static let palettes = NSCache<NSString, PaletteBox>()

    private final class PaletteBox {
        let palette: Palette
        init(_ palette: Palette) { self.palette = palette }
    }

    static func url(_ name: String) -> URL? {
        Bundle.app.url(forResource: name, withExtension: "heic", subdirectory: "Art")
    }

    /// The artwork if it has already been decoded at `size`.
    static func cached(_ name: String, _ size: Size = .card) -> UIImage? {
        images.object(forKey: "\(name)@\(size.rawValue)" as NSString)
    }

    /// One artwork decodes at a time, on its own thread. Several HEIC decodes at once on Swift's shared
    /// threads deadlock the software decoder and take every other task in the app down with them.
    private static let queue = DispatchQueue(label: "com.jackwallner.writing.art", qos: .userInitiated)
    private static let decoding = NSLock()

    static func image(_ name: String, _ size: Size = .card) async -> UIImage? {
        if let hit = cached(name, size) { return hit }
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: decode(name, size)) }
        }
    }

    /// Decodes on the calling thread. Use `image` from views.
    static func decode(_ name: String, _ size: Size = .card) -> UIImage? {
        if let hit = cached(name, size) { return hit }
        decoding.lock()
        defer { decoding.unlock() }
        if let hit = cached(name, size) { return hit }
        guard let url = url(name), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: size.rawValue,
        ]
        let image: UIImage
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            image = UIImage(cgImage: cgImage)
        } else if let whole = UIImage(contentsOfFile: url.path) {
            image = whole.preparingForDisplay() ?? whole
        } else {
            return nil
        }
        images.setObject(image, forKey: "\(name)@\(size.rawValue)" as NSString)
        return image
    }

    /// The colors of an artwork, for lighting the room it hangs in.
    static func palette(_ name: String) async -> Palette? {
        if let hit = palettes.object(forKey: name as NSString) { return hit.palette }
        return await withCheckedContinuation { continuation in
            queue.async {
                guard let cgImage = decode(name, .tile)?.cgImage, let palette = Palette(image: cgImage) else {
                    continuation.resume(returning: nil)
                    return
                }
                palettes.setObject(PaletteBox(palette), forKey: name as NSString)
                continuation.resume(returning: palette)
            }
        }
    }
}

/// Nine colors sampled from a three by three grid over an artwork.
struct Palette: Equatable, Sendable {
    /// Row by row from the top left; red, green and blue in 0...1.
    var cells: [SIMD3<Double>]

    static let neutral = Palette(cells: Array(repeating: SIMD3(0.52, 0.48, 0.43), count: 9))

    init(cells: [SIMD3<Double>]) { self.cells = cells }

    init?(image: CGImage) {
        let side = 30
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return nil }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let block = side / 3
        var cells: [SIMD3<Double>] = []
        for row in 0..<3 {
            for column in 0..<3 {
                var sum = SIMD3<Double>(0, 0, 0)
                for y in row * block..<(row + 1) * block {
                    for x in column * block..<(column + 1) * block {
                        let offset = (y * side + x) * 4
                        sum += SIMD3(Double(pixels[offset]), Double(pixels[offset + 1]), Double(pixels[offset + 2]))
                    }
                }
                cells.append(sum / Double(block * block) / 255)
            }
        }
        self.cells = cells
    }

    /// The colors of the room: deep at night, a pale wash by day, always quiet enough to read on.
    func room(dark: Bool) -> [SIMD3<Double>] {
        cells.map { color in
            var (hue, saturation, brightness) = Palette.hsb(color)
            if dark {
                saturation = min(0.82, saturation * 1.15 + 0.04)
                brightness = 0.07 + 0.25 * brightness
            } else {
                saturation = min(0.30, saturation * 0.40)
                brightness = 0.84 + 0.12 * brightness
            }
            return Palette.rgb(hue, saturation, brightness)
        }
    }

    /// The artwork's most vivid color, set to read on the room. Nil for a work with no real color.
    func accent(dark: Bool) -> SIMD3<Double>? {
        let scored = cells.map { color -> (Double, Double, Double) in
            let (hue, saturation, brightness) = Palette.hsb(color)
            return (hue, saturation, saturation * (0.35 + brightness))
        }
        guard let best = scored.max(by: { $0.2 < $1.2 }), best.1 > 0.16 else { return nil }
        return dark
            ? Palette.rgb(best.0, min(0.55, max(0.32, best.1)), 0.90)
            : Palette.rgb(best.0, min(0.80, max(0.50, best.1)), 0.42)
    }

    func mixed(with other: Palette, _ amount: Double) -> Palette {
        Palette(cells: zip(cells, other.cells).map { $0 + ($1 - $0) * amount })
    }

    static func hsb(_ color: SIMD3<Double>) -> (Double, Double, Double) {
        let high = color.max(), low = color.min(), delta = high - low
        var hue = 0.0
        if delta > 0.0001 {
            if high == color.x { hue = ((color.y - color.z) / delta).truncatingRemainder(dividingBy: 6) }
            else if high == color.y { hue = (color.z - color.x) / delta + 2 }
            else { hue = (color.x - color.y) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, high > 0 ? delta / high : 0, high)
    }

    static func rgb(_ hue: Double, _ saturation: Double, _ brightness: Double) -> SIMD3<Double> {
        let sector = hue * 6
        let chroma = brightness * saturation
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let base: SIMD3<Double>
        switch Int(sector) % 6 {
        case 0: base = SIMD3(chroma, x, 0)
        case 1: base = SIMD3(x, chroma, 0)
        case 2: base = SIMD3(0, chroma, x)
        case 3: base = SIMD3(0, x, chroma)
        case 4: base = SIMD3(x, 0, chroma)
        default: base = SIMD3(chroma, 0, x)
        }
        return base + SIMD3(repeating: brightness - chroma)
    }
}
