import AppKit
import ColorSync
import RirikuCore

/// A connected screen with the identifier Setup stores for the chosen display.
struct ConnectedDisplay: Identifiable {
    let screen: NSScreen
    let id: String
    let name: String

    var candidate: DisplayCandidate {
        DisplayCandidate(id: id, hasNotch: screen.safeAreaInsets.top > 0, isMain: screen == NSScreen.main)
    }

    @MainActor
    static func all() -> [ConnectedDisplay] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            // The UUID stays the same across restarts and reconnections, unlike the display number.
            let id = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)
                .map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? number.stringValue
            return ConnectedDisplay(screen: screen, id: id, name: screen.localizedName)
        }
    }
}
