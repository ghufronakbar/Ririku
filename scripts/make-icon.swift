// Builds AppIcon.icns from square artwork: the art is clipped to a rounded square on the
// macOS icon grid (824 pt body with transparent margins on a 1024 pt canvas).
// Usage: swift scripts/make-icon.swift <artwork.png> <output.icns>
//        swift scripts/make-icon.swift <artwork.png> --png <size> <output.png>   (one size, e.g. extension icons)
import AppKit

let arguments = CommandLine.arguments
let usage = "usage: make-icon.swift <artwork.png> <output.icns> | <artwork.png> --png <size> <output.png>\n"
let singleSize = arguments.count == 5 && arguments[2] == "--png" ? Int(arguments[3]) : nil
guard arguments.count == 3 || (singleSize ?? 0) > 0, let artwork = NSImage(contentsOfFile: arguments[1]),
      let source = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(1)
}

func render(size: Int) throws -> Data {
    let scale = CGFloat(size) / 1024
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    let body = CGRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    context.addPath(CGPath(roundedRect: body, cornerWidth: 185 * scale, cornerHeight: 185 * scale, transform: nil))
    context.clip()
    // Fill the body like "aspect fill", so non-square artwork is cropped rather than stretched.
    let ratio = max(body.width / CGFloat(source.width), body.height / CGFloat(source.height))
    let drawn = CGSize(width: CGFloat(source.width) * ratio, height: CGFloat(source.height) * ratio)
    context.draw(source, in: CGRect(x: body.midX - drawn.width / 2, y: body.midY - drawn.height / 2,
                                    width: drawn.width, height: drawn.height))
    guard let image = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

if let singleSize {
    try render(size: singleSize).write(to: URL(fileURLWithPath: arguments[4]))
    exit(0)
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    try render(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", arguments[2]]
try iconutil.run()
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
