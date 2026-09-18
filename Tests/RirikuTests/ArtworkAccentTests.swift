import AppKit
import SwiftUI
import Testing
@testable import Ririku

@MainActor
struct ArtworkAccentTests {
    private func image(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: 32, height: 32).fill()
        image.unlockFocus()
        return image
    }

    @Test func colorfulArtworkProducesReadableTint() {
        let service = ArtworkAccent()
        let artwork = image(.red)
        let color = service.color(for: artwork)
        #expect(color.redComponent > color.greenComponent)
        #expect(color.greenComponent >= 0.55)
        #expect(color.blueComponent >= 0.55)
        #expect(service.color(for: artwork) == color)
        let blue = service.color(for: image(.blue))
        #expect(blue.blueComponent > blue.redComponent)
    }

    @Test func missingAndNeutralArtworkFallsBackToWhite() {
        let service = ArtworkAccent()
        #expect(service.color(for: nil) == .white)
        for color in [NSColor.black, .white, .gray, .clear] {
            #expect(service.color(for: image(color)) == .white)
        }
    }

    @Test func automaticPreferencePersistsAndManualColorStaysIndependent() {
        let defaults = MemoryDefaults()
        defaults.set(false, forKey: "automaticLyrics")
        let model = AppModel(defaults: defaults)
        model.animations = false
        model.accentName = "Auto"
        model.artwork = image(.red)
        #expect(model.accent == model.automaticAccent)
        #expect(defaults.string(forKey: "accentName") == "Auto")
        model.accentName = "Lavender"
        let manual = model.accent
        model.artwork = image(.blue)
        #expect(model.accent == manual)
        model.accentName = "Auto"
        model.artwork = nil
        #expect(model.accent == .white)
    }
}
