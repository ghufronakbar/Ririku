import AppKit

@MainActor
final class ArtworkAccent {
    private let cache = NSCache<NSImage, NSColor>()

    init() { cache.countLimit = 40 }

    func color(for image: NSImage?) -> NSColor {
        guard let image else { return .white }
        if let cached = cache.object(forKey: image) { return cached }
        let result = extract(image)
        cache.setObject(result, forKey: image)
        return result
    }

    private func extract(_ image: NSImage) -> NSColor {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8,
                                      bytesPerRow: 128, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return .white }
        context.interpolationQuality = .medium
        context.draw(source, in: CGRect(x: 0, y: 0, width: 32, height: 32))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var weights = Array(repeating: 0.0, count: 12)
        var reds = weights
        var greens = weights
        var blues = weights
        for index in 0..<1024 {
            let offset = index * 4
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0.9 else { continue }
            let red = min(1, Double(pixels[offset]) / 255 / alpha)
            let green = min(1, Double(pixels[offset + 1]) / 255 / alpha)
            let blue = min(1, Double(pixels[offset + 2]) / 255 / alpha)
            let color = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
            let saturation = color.saturationComponent
            let brightness = color.brightnessComponent
            guard saturation >= 0.18, brightness >= 0.15 else { continue }
            let bucket = min(11, Int(color.hueComponent * 12))
            let weight = saturation * brightness
            weights[bucket] += weight
            reds[bucket] += red * weight
            greens[bucket] += green * weight
            blues[bucket] += blue * weight
        }
        guard let bucket = weights.indices.max(by: { weights[$0] < weights[$1] }),
              weights[bucket] >= 8 else { return .white }
        let dominant = NSColor(srgbRed: reds[bucket] / weights[bucket], green: greens[bucket] / weights[bucket],
                               blue: blues[bucket] / weights[bucket], alpha: 1)
        return NSColor(srgbRed: 0.55 + 0.45 * dominant.redComponent,
                       green: 0.55 + 0.45 * dominant.greenComponent,
                       blue: 0.55 + 0.45 * dominant.blueComponent, alpha: 1)
    }
}
