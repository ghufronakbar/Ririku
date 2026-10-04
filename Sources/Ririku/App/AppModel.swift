import AppKit
import SwiftUI
import RirikuCore

/// App-wide state shared by the notch panel and Setup: the interface language, the island's size and accent,
/// and launch at login. Music and lyrics live in `music`; the panel's size is computed in `PanelGeometry.swift`.
@MainActor
final class AppModel: ObservableObject {
    let music: MusicModel
    @Published var interfaceLanguage: InterfaceLanguage {
        didSet {
            localizer = Localizer(code: interfaceLanguage.resolvedCode)
            music.localizer = localizer
            defaults.set(interfaceLanguage.rawValue, forKey: "interfaceLanguage")
            languageChanged?()
        }
    }
    private(set) var localizer: Localizer
    @Published var expanded = false { didSet { geometryChanged?() } }
    @Published var panelWidth: Double { didSet { defaults.set(panelWidth, forKey: "panelWidth"); geometryChanged?() } }
    /// Compact island size is stored as the amount added to the physical notch, so 0 fits the notch on any Mac.
    @Published var compactExtraWidth: Double { didSet { defaults.set(compactExtraWidth, forKey: "compactExtraWidth"); geometryChanged?() } }
    @Published var compactExtraHeight: Double { didSet { defaults.set(compactExtraHeight, forKey: "compactExtraHeight"); geometryChanged?() } }
    @Published var accentName: String { didSet { defaults.set(accentName, forKey: "accentName") } }
    @Published var animations: Bool { didSet { defaults.set(animations, forKey: "animations"); geometryChanged?() } }
    @Published private(set) var automaticAccent: Color = .white
    private let artworkAccent = ArtworkAccent()
    @Published var loginItemMessage: UIText?
    /// Incremented after a launch-at-login change or a Setup visit, because macOS owns that state.
    @Published private(set) var loginItemRevision = 0
    @Published var notchWidth: CGFloat = 180
    @Published var topHeight: CGFloat = 34
    var geometryChanged: (() -> Void)?
    var openSetup: (() -> Void)?
    var languageChanged: (() -> Void)?
    private let defaults: UserDefaults

    init(lyricsService: LyricsService = LyricsService(), defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedLanguage = InterfaceLanguage(rawValue: defaults.string(forKey: "interfaceLanguage") ?? "") ?? .system
        interfaceLanguage = storedLanguage
        let localizer = Localizer(code: storedLanguage.resolvedCode)
        self.localizer = localizer
        music = MusicModel(lyricsService: lyricsService, defaults: defaults, localizer: localizer)
        let storedWidth = defaults.double(forKey: "panelWidth")
        panelWidth = storedWidth.isFinite && (360...720).contains(storedWidth) ? storedWidth : 442
        let storedExtraWidth = defaults.double(forKey: "compactExtraWidth")
        compactExtraWidth = storedExtraWidth.isFinite && (0...Self.compactWidthRange).contains(storedExtraWidth) ? storedExtraWidth : 0
        let storedExtraHeight = defaults.double(forKey: "compactExtraHeight")
        compactExtraHeight = storedExtraHeight.isFinite && (0...Self.compactHeightRange).contains(storedExtraHeight) ? storedExtraHeight : 0
        // The old absolute width was always wider than the notch, which is what this replaces.
        defaults.removeObject(forKey: "compactWidth")
        accentName = defaults.string(forKey: "accentName") ?? "Peach"
        animations = defaults.object(forKey: "animations") as? Bool ?? true
        music.layoutChanged = { [weak self] in self?.geometryChanged?() }
        music.openSetup = { [weak self] in self?.openSetup?() }
        music.artworkChanged = { [weak self] image in self?.updateAutomaticAccent(for: image) }
    }

    var locale: Locale { localizer.locale }
    func t(_ key: String, _ arguments: String...) -> String { localizer.string(key, arguments) }
    func t(_ text: UIText) -> String { localizer.string(text.key, text.arguments) }

    var accent: Color {
        switch accentName {
        case "Auto": return automaticAccent
        case "Lavender": return Color(red: 0.78, green: 0.75, blue: 1)
        case "Netral": return .white
        default: return Color(red: 0.96, green: 0.78, blue: 0.7)
        }
    }

    var canAnimate: Bool { animations && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func updateAutomaticAccent(for image: NSImage?) {
        let extracted = artworkAccent.color(for: image)
        let color: Color = extracted == .white ? .white : Color(nsColor: extracted)
        withAnimation(canAnimate ? .easeInOut(duration: 0.45) : nil) { automaticAccent = color }
    }

    // MARK: Launch at login

    var launchAtLogin: Bool { LoginItem.state() == .on }

    /// The toggle writes straight to macOS; the interface follows the state it reports back.
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginItemMessage = nil
        } catch { loginItemMessage = UIText(error: error) }
        loginItemRevision += 1
    }

    /// Login items can also be changed in System Settings, so the state is read again when Setup opens.
    func refreshLoginItem() { loginItemRevision += 1 }

    func openLoginItemsSettings() { NSWorkspace.shared.open(LoginItem.settingsURL) }
}
