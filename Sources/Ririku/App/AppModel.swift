import AppKit
import SwiftUI
import RirikuCore

/// A short message in the compact island, such as a finished timer. It never opens the panel (R-UI-3, R-UI-6).
struct PanelNotice: Equatable {
    static let duration: Double = 3
    let id = UUID()
    let text: UIText
    let icon: String
}

/// App-wide state shared by the notch panel and Setup: the interface language, the island's size and accent,
/// the general settings, the layout, and launch at login. Music and lyrics live in `music`, the local widgets
/// in `widgets`; the panel's size is computed in `PanelGeometry.swift`.
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
    @Published var expanded = false {
        didSet {
            // The panel opens on the first tab again.
            if !expanded { selectedTabID = nil }
            geometryChanged?()
        }
    }
    /// Tabs and widgets of the expanded panel (D-018). Changed through `editLayout`, which keeps it valid.
    @Published private(set) var layout: PanelLayout
    @Published var selectedTabID: String? { didSet { if expanded { geometryChanged?() } } }
    let system: SystemMonitor
    let network = NetworkMonitor()
    let battery = BatteryMonitor()
    let widgets: WidgetStore
    let tray: TrayStore
    let clipboard: ClipboardStore
    let calendar: CalendarStore
    let camera: CameraMirror
    let translate: TranslateStore
    @Published private(set) var notice: PanelNotice?
    /// Width of the screen the panel was last placed on, so views lay out the panel for the same screen.
    var screenWidth: Double = 1512
    /// Setup shows its pages only while its window is open, so widgets in the preview stop sampling when it closes.
    @Published var setupWindowOpen = false
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
    /// A file dragged over the panel; the panel controller opens the Tray for it.
    var fileDragEntered: (() -> Void)?
    var openSetup: (() -> Void)?
    var languageChanged: (() -> Void)?
    var iconsChanged: (() -> Void)?
    var shortcutChanged: (() -> Void)?
    private let defaults: UserDefaults

    /// Tests pass their own clipboard, calendar, and camera, so they never touch the real ones or show a permission prompt.
    init(lyricsService: LyricsService = LyricsService(), defaults: UserDefaults = .standard, clipboard: ClipboardStore? = nil,
         calendar: CalendarStore? = nil, camera: CameraMirror? = nil) {
        self.defaults = defaults
        let storedLanguage = InterfaceLanguage(rawValue: defaults.string(forKey: "interfaceLanguage") ?? "") ?? .system
        interfaceLanguage = storedLanguage
        let localizer = Localizer(code: storedLanguage.resolvedCode)
        self.localizer = localizer
        music = MusicModel(lyricsService: lyricsService, defaults: defaults, localizer: localizer)
        widgets = WidgetStore(defaults: defaults)
        tray = TrayStore(defaults: defaults)
        self.clipboard = clipboard ?? ClipboardStore(defaults: defaults)
        self.calendar = calendar ?? CalendarStore(defaults: defaults)
        self.camera = camera ?? CameraMirror()
        translate = TranslateStore(defaults: defaults, defaultTarget: localizer.code)
        system = SystemMonitor(defaults: defaults)
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
        let storedLayout = defaults.data(forKey: "panelLayout").flatMap { try? JSONDecoder().decode(PanelLayout.self, from: $0) }
        layout = (storedLayout ?? .standard).sanitized(widgetKinds: WidgetKind.identifiers, toolKinds: ToolKind.identifiers)
        music.layoutChanged = { [weak self] in self?.geometryChanged?() }
        music.openSetup = { [weak self] in self?.openSetup?() }
        music.artworkChanged = { [weak self] image in self?.updateAutomaticAccent(for: image) }
        widgets.notice = { [weak self] text, icon in self?.showNotice(text, icon: icon) }
        tray.notice = { [weak self] text, icon in self?.showNotice(text, icon: icon) }
        widgets.changed = { [weak self] in self?.geometryChanged?() }
        battery.changed = { [weak self] old, new in self?.batteryChanged(from: old, to: new) }
        updateBatteryListening()
        // The Clipboard tab exists exactly while clipboard history is on.
        let hasClipboardTab = layout.tabs.contains { $0.kind == PanelTab.clipboardKind }
        if hasClipboardTab != self.clipboard.enabled { setClipboardHistory(self.clipboard.enabled) }
        // The same for the Translate tab, which macOS 14 cannot show.
        let hasTranslateTab = layout.tabs.contains { $0.kind == PanelTab.translateKind }
        if hasTranslateTab != translate.enabled { setTranslateTab(translate.enabled) }
    }

    var locale: Locale { localizer.locale }

    /// The interface language, with the 12- or 24-hour clock chosen in System Settings.
    var timeLocale: Locale {
        var components = Locale.Components(locale: locale)
        components.hourCycle = Locale.autoupdatingCurrent.hourCycle
        return Locale(components: components)
    }
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

    // MARK: Tabs and widgets

    var visibleTabs: [PanelTab] { layout.visibleTabs }

    /// The selected tab, or the first one.
    var currentTab: PanelTab {
        visibleTabs.first { $0.id == selectedTabID } ?? visibleTabs.first ?? PanelLayout.standard.tabs[0]
    }

    /// The visible Tray tab, which a file dragged onto the notch opens.
    var trayTab: PanelTab? { visibleTabs.first { $0.kind == PanelTab.trayKind } }

    /// A tool's name; for a page, its own name, or "Home" for the first page and "Page 2", "Page 3", and so on.
    func tabName(_ tab: PanelTab) -> String {
        if let tool = ToolKind(rawValue: tab.kind) { return tool.title(self) }
        let name = tab.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty else { return name }
        // Pages are numbered among pages only, so a tool tab in between does not skip a number.
        let index = layout.tabs.filter(\.isPage).firstIndex { $0.id == tab.id } ?? 0
        return index == 0 ? t("Home") : t("Page %@", (index + 1).formatted(.number.locale(locale)))
    }

    /// Applies an edit from Setup, keeps the layout valid, and saves it.
    func editLayout(_ change: (inout PanelLayout) -> Void) {
        var edited = layout
        change(&edited)
        setLayout(edited)
    }

    /// Adds a widget from Setup. A widget that needs a permission asks for it now, when the user turns it on
    /// (R-WID-3); the returned task ends when the prompt is answered.
    @discardableResult
    func addWidget(_ kind: WidgetKind, toTab tabID: String) -> Task<Void, Never>? {
        editLayout { $0.addWidget(kind: kind.rawValue, wide: kind == .music, toTab: tabID) }
        switch kind {
        case .calendar: return calendar.requestAccessIfNeeded()
        case .camera: return camera.requestAccessIfNeeded()
        default: return nil
        }
    }

    /// The default layout, keeping the Clipboard and Translate tabs while they are on.
    func resetLayout() {
        var standard = PanelLayout.standard
        if clipboard.enabled { standard.addTool(PanelTab.clipboardKind) }
        if translate.enabled { standard.addTool(PanelTab.translateKind) }
        setLayout(standard)
    }

    private func setLayout(_ newLayout: PanelLayout) {
        layout = newLayout.sanitized(widgetKinds: WidgetKind.identifiers, toolKinds: ToolKind.identifiers)
        defaults.set(try? JSONEncoder().encode(layout), forKey: "panelLayout")
        if !visibleTabs.contains(where: { $0.id == selectedTabID }) { selectedTabID = nil }
        updateBatteryListening()
        geometryChanged?()
    }

    // MARK: Notices and live widgets

    /// Shows a notice in the compact island for about three seconds.
    func showNotice(_ text: UIText, icon: String) {
        let notice = PanelNotice(text: text, icon: icon)
        self.notice = notice
        geometryChanged?()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(PanelNotice.duration))
            guard let self, self.notice?.id == notice.id else { return }
            self.notice = nil
            self.geometryChanged?()
        }
    }

    /// Turning clipboard history on adds its tab; turning it off removes the tab and deletes the history (D-020).
    func setClipboardHistory(_ on: Bool) {
        clipboard.setEnabled(on)
        editLayout { on ? $0.addTool(PanelTab.clipboardKind) : $0.removeTool(PanelTab.clipboardKind) }
    }

    /// Turning Translate on adds its tab and turning it off removes it, clearing the text (D-018).
    func setTranslateTab(_ on: Bool) {
        translate.setEnabled(on)
        editLayout { translate.enabled ? $0.addTool(PanelTab.translateKind) : $0.removeTool(PanelTab.translateKind) }
    }

    /// A running timer takes the compact island only while no music plays (R-WID-1).
    var liveTimer: LiveTimer? { music.isPlayingNow ? nil : widgets.liveTimer }

    /// Power source changes are only listened to while the Battery widget is on a page.
    private func updateBatteryListening() {
        battery.setActive(layout.tabs.contains { $0.widgets.contains { $0.kind == WidgetKind.battery.rawValue } })
    }

    private func batteryChanged(from old: BatteryMonitor.Reading?, to new: BatteryMonitor.Reading?) {
        guard let old, let new, !old.onPower, new.onPower, widgets.data.chargingNotice else { return }
        let level = new.fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
        showNotice(UIText("Charging · %@", level), icon: "battery.100percent.bolt")
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
