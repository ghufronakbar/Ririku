import AppKit
import SwiftUI
import RirikuCore

/// App-wide state shared by the notch panel and Setup: the interface language, the island's size and accent,
/// the general settings, and launch at login. Music and lyrics live in `music`; the panel's size is computed
/// in `PanelGeometry.swift`.
@MainActor
final class AppModel: ObservableObject {
    static let hoverOpenDelayRange = 0.0...1.0
    static let hoverCloseDelayRange = 0.1...2.0

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

    // General settings (D-022).
    @Published var showInDock: Bool { didSet { defaults.set(showInDock, forKey: "showInDock"); iconsChanged?() } }
    @Published var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon"); iconsChanged?() } }
    /// The display chosen in Setup, by its CoreGraphics UUID; nil places the panel automatically.
    @Published private(set) var panelDisplayID: String?
    /// Kept so Setup can still name the chosen display while it is disconnected.
    @Published private(set) var panelDisplayName: String?
    @Published var hoverOpenDelay: Double { didSet { defaults.set(hoverOpenDelay, forKey: "hoverOpenDelay") } }
    @Published var hoverCloseDelay: Double { didSet { defaults.set(hoverCloseDelay, forKey: "hoverCloseDelay") } }
    @Published var hapticFeedback: Bool { didSet { defaults.set(hapticFeedback, forKey: "hapticFeedback") } }
    /// Off until the user records one (R-UI-17).
    @Published var panelShortcut: HotKey? {
        didSet {
            defaults.set(panelShortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: "panelShortcut")
            shortcutChanged?()
        }
    }
    /// While Setup records a shortcut, the current one is released so pressing it again can be recorded.
    @Published var recordingShortcut = false { didSet { shortcutChanged?() } }
    @Published var shortcutMessage: UIText?
    @Published var setupPage: SetupPage?
    /// Incremented when displays are connected, removed, or rearranged, so Setup lists them again.
    @Published private(set) var screenRevision = 0

    var geometryChanged: (() -> Void)?
    var openSetup: (() -> Void)?
    var languageChanged: (() -> Void)?
    var iconsChanged: (() -> Void)?
    var shortcutChanged: (() -> Void)?
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
        showInDock = defaults.bool(forKey: "showInDock")
        showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        panelDisplayID = defaults.string(forKey: "panelDisplayID")
        panelDisplayName = defaults.string(forKey: "panelDisplayName")
        hoverOpenDelay = Self.storedDelay(defaults, "hoverOpenDelay", in: Self.hoverOpenDelayRange) ?? 0.15
        hoverCloseDelay = Self.storedDelay(defaults, "hoverCloseDelay", in: Self.hoverCloseDelayRange) ?? 0.35
        hapticFeedback = defaults.bool(forKey: "hapticFeedback")
        let storedShortcut = defaults.data(forKey: "panelShortcut").flatMap { try? JSONDecoder().decode(HotKey.self, from: $0) }
        panelShortcut = storedShortcut?.isValid == true ? storedShortcut : nil
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

    // MARK: General settings

    private static func storedDelay(_ defaults: UserDefaults, _ key: String, in range: ClosedRange<Double>) -> Double? {
        guard let value = defaults.object(forKey: key) as? Double, value.isFinite, range.contains(value) else { return nil }
        return value
    }

    /// `nil` returns the panel to automatic placement.
    func choosePanelDisplay(id: String?, name: String?) {
        panelDisplayID = id
        panelDisplayName = id == nil ? nil : name
        defaults.set(panelDisplayID, forKey: "panelDisplayID")
        defaults.set(panelDisplayName, forKey: "panelDisplayName")
        geometryChanged?()
    }

    func screensChanged() { screenRevision += 1 }

    /// macOS plays haptic feedback only while Force Click and haptic feedback is on in the Trackpad settings.
    func openTrackpadSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
    }

    /// Setup opens where the music is connected until a browser or desktop player is set up.
    var defaultSetupPage: SetupPage {
        music.connectedExtensionVersion == nil && !music.spotifyEnabled && !music.appleMusicEnabled ? .browserConnection : .general
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
