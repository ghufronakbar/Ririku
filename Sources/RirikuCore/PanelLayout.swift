import Foundation

/// One widget on a page of the panel. `kind` names the widget, such as "music"; kinds this version does not know
/// are dropped when a layout is loaded, so a layout saved by a newer version still opens (R-WID-2).
public struct WidgetSlot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: String
    public var wide: Bool

    public init(id: String = UUID().uuidString, kind: String, wide: Bool) {
        self.id = id
        self.kind = kind
        self.wide = wide
    }

    /// A wide widget takes the room of two small ones and the gap between them.
    public var units: Int { wide ? 2 : 1 }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(String.self, forKey: .kind)
        wide = try container.decodeIfPresent(Bool.self, forKey: .wide) ?? false
    }
}

/// A tab of the panel: a page of widgets, or a tool such as the Tray that fills the tab.
public struct PanelTab: Codable, Equatable, Identifiable, Sendable {
    public static let pageKind = "widgets"
    public static let trayKind = "tray"
    public static let clipboardKind = "clipboard"

    public var id: String
    public var kind: String
    /// The name the user gave the page; empty shows the default name.
    public var name: String
    public var icon: String
    public var widgets: [WidgetSlot]
    public var hidden: Bool

    public var isPage: Bool { kind == Self.pageKind }

    public init(id: String = UUID().uuidString, kind: String = PanelTab.pageKind, name: String = "", icon: String, widgets: [WidgetSlot] = [], hidden: Bool = false) {
        self.id = id
        self.kind = kind
        self.name = name
        self.icon = icon
        self.widgets = widgets
        self.hidden = hidden
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(String.self, forKey: .kind)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        widgets = (try container.decodeIfPresent([Lossy<WidgetSlot>].self, forKey: .widgets) ?? []).compactMap(\.value)
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    }
}

/// The tabs of the panel and the widgets on them (D-018). Edited in Setup and stored as versioned JSON.
public struct PanelLayout: Codable, Equatable, Sendable {
    /// Version 2 added tool tabs; layouts saved earlier get the Tray tab once.
    public static let currentVersion = 2
    public static let maximumTabs = 8
    public static let maximumNameLength = 24
    /// Symbols a page can use in the tab bar. Stored icons outside this list are replaced.
    public static let pageIcons = ["house", "square.grid.2x2", "star", "bolt", "heart", "music.note", "speedometer", "sparkles"]

    public var version: Int
    public var tabs: [PanelTab]

    public init(version: Int = PanelLayout.currentVersion, tabs: [PanelTab]) {
        self.version = version
        self.tabs = tabs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        tabs = (try container.decodeIfPresent([Lossy<PanelTab>].self, forKey: .tabs) ?? []).compactMap(\.value)
    }

    public static func toolTab(_ kind: String) -> PanelTab { PanelTab(id: kind, kind: kind, icon: toolIcon(kind)) }

    public static func toolIcon(_ kind: String) -> String { kind == PanelTab.clipboardKind ? "doc.on.clipboard" : "tray" }

    /// Home with the music widget, wide, and the system widget, then the Tray (D-018).
    public static let standard = PanelLayout(tabs: [
        PanelTab(id: "home", icon: "house", widgets: [
            WidgetSlot(id: "music", kind: "music", wide: true),
            WidgetSlot(id: "system", kind: "system", wide: false)
        ]),
        toolTab(PanelTab.trayKind)
    ])

    /// Keeps what this version can show: widget kinds and tools it knows, each once, pages with valid icons and
    /// names, at most `maximumTabs` tabs, and at least one visible tab, otherwise the standard layout.
    /// A layout saved before version 2 gets the Tray tab once.
    public func sanitized(widgetKinds: Set<String>, toolKinds: Set<String>) -> PanelLayout {
        var tabIDs = Set<String>()
        var widgetIDs = Set<String>()
        var kinds = Set<String>()
        var tools = Set<String>()
        var result: [PanelTab] = []
        for var tab in tabs where !tab.id.isEmpty && (tab.isPage || toolKinds.contains(tab.kind)) && tabIDs.insert(tab.id).inserted {
            if tab.isPage {
                tab.name = String(tab.name.prefix(Self.maximumNameLength))
                if !Self.pageIcons.contains(tab.icon) { tab.icon = Self.pageIcons[1] }
                tab.widgets = tab.widgets.filter {
                    widgetKinds.contains($0.kind) && !$0.id.isEmpty && widgetIDs.insert($0.id).inserted && kinds.insert($0.kind).inserted
                }
            } else {
                guard tools.insert(tab.kind).inserted else { continue }
                tab = PanelTab(id: tab.id, kind: tab.kind, icon: Self.toolIcon(tab.kind), hidden: tab.hidden)
            }
            result.append(tab)
            if result.count == Self.maximumTabs { break }
        }
        guard result.contains(where: { !$0.hidden }) else {
            var standard = Self.standard
            standard.tabs[0].widgets.removeAll { !widgetKinds.contains($0.kind) }
            standard.tabs.removeAll { !$0.isPage && !toolKinds.contains($0.kind) }
            return standard
        }
        if version < 2, toolKinds.contains(PanelTab.trayKind), !tools.contains(PanelTab.trayKind), result.count < Self.maximumTabs,
           !tabIDs.contains(PanelTab.trayKind) {
            result.append(Self.toolTab(PanelTab.trayKind))
        }
        return PanelLayout(tabs: result)
    }

    public var visibleTabs: [PanelTab] { tabs.filter { !$0.hidden } }

    /// Widget kinds not on any page yet; each widget appears once.
    public func unusedKinds(of kinds: [String]) -> [String] {
        let used = Set(tabs.flatMap(\.widgets).map(\.kind))
        return kinds.filter { !used.contains($0) }
    }

    // MARK: Editing

    @discardableResult
    public mutating func addPage() -> String? {
        guard tabs.count < Self.maximumTabs else { return nil }
        // A new page takes the first icon no other tab uses, so the tab bar can tell them apart.
        let page = PanelTab(icon: Self.pageIcons.dropFirst().first { icon in !tabs.contains { $0.icon == icon } } ?? Self.pageIcons[1])
        tabs.append(page)
        return page.id
    }

    /// Shows or hides a tab in the panel; the last visible tab stays.
    public mutating func setHidden(_ hidden: Bool, forTab id: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }), !hidden || visibleTabs.count > 1 || tabs[index].hidden else { return }
        tabs[index].hidden = hidden
    }

    /// Adds a tool's tab at the end, unless it is already there.
    public mutating func addTool(_ kind: String) {
        guard !tabs.contains(where: { $0.kind == kind }), tabs.count < Self.maximumTabs else { return }
        tabs.append(Self.toolTab(kind))
    }

    public mutating func removeTool(_ kind: String) {
        guard kind != PanelTab.pageKind else { return }
        tabs.removeAll { $0.kind == kind }
    }

    /// The last visible tab cannot be removed.
    public mutating func removeTab(id: String) {
        guard visibleTabs.contains(where: { $0.id == id }) ? visibleTabs.count > 1 : true else { return }
        tabs.removeAll { $0.id == id }
    }

    /// Moves a tab left (negative) or right (positive) in the tab bar.
    public mutating func moveTab(id: String, by offset: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(0, index + offset), tabs.count - 1)
        guard target != index else { return }
        tabs.insert(tabs.remove(at: index), at: target)
    }

    public mutating func renameTab(id: String, to name: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].name = String(name.prefix(Self.maximumNameLength))
    }

    public mutating func setIcon(_ icon: String, forTab id: String) {
        guard Self.pageIcons.contains(icon), let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].icon = icon
    }

    /// Adds a widget kind at the end of a page, unless it is already somewhere in the layout.
    public mutating func addWidget(kind: String, wide: Bool, toTab id: String) {
        guard !tabs.contains(where: { $0.widgets.contains { $0.kind == kind } }),
              let index = tabs.firstIndex(where: { $0.id == id }), tabs[index].isPage else { return }
        tabs[index].widgets.append(WidgetSlot(kind: kind, wide: wide))
    }

    public mutating func removeWidget(id: String) {
        for index in tabs.indices { tabs[index].widgets.removeAll { $0.id == id } }
    }

    public mutating func setWide(_ wide: Bool, forWidget id: String) {
        for index in tabs.indices {
            if let slot = tabs[index].widgets.firstIndex(where: { $0.id == id }) { tabs[index].widgets[slot].wide = wide }
        }
    }

    /// Moves a widget left (negative) or right (positive) on its page.
    public mutating func moveWidget(id: String, by offset: Int) {
        for index in tabs.indices {
            guard let slot = tabs[index].widgets.firstIndex(where: { $0.id == id }) else { continue }
            let target = min(max(0, slot + offset), tabs[index].widgets.count - 1)
            tabs[index].widgets.insert(tabs[index].widgets.remove(at: slot), at: target)
            return
        }
    }

    /// Moves widgets the way a list's drag and drop reports it: the offsets before the move and the destination offset.
    public mutating func moveWidgets(inTab id: String, from offsets: IndexSet, to destination: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        var widgets = tabs[index].widgets
        let moving = offsets.filter { widgets.indices.contains($0) }.map { widgets[$0] }
        let before = offsets.filter { $0 < destination }.count
        for offset in offsets.sorted(by: >) where widgets.indices.contains(offset) { widgets.remove(at: offset) }
        widgets.insert(contentsOf: moving, at: min(max(0, destination - before), widgets.count))
        tabs[index].widgets = widgets
    }

    /// Moves a widget to the end of another page.
    public mutating func moveWidget(id: String, toTab tabID: String) {
        guard let target = tabs.firstIndex(where: { $0.id == tabID }), tabs[target].isPage,
              let source = tabs.firstIndex(where: { $0.widgets.contains { $0.id == id } }), source != target,
              let slot = tabs[source].widgets.firstIndex(where: { $0.id == id }) else { return }
        tabs[target].widgets.append(tabs[source].widgets.remove(at: slot))
    }
}

/// How a page shares its width between widgets.
public enum PageGeometry {
    /// The narrowest content that gives every slot at least `unit` per unit.
    public static func minimumWidth(units: [Int], unit: Double, spacing: Double) -> Double {
        guard !units.isEmpty else { return 0 }
        let inner = units.reduce(0.0) { $0 + Double($1) * unit + Double($1 - 1) * spacing }
        return inner + Double(units.count - 1) * spacing
    }

    /// Shares `contentWidth` so a wide slot is exactly two small slots and the gap between them.
    public static func widths(units: [Int], contentWidth: Double, spacing: Double) -> [Double] {
        guard !units.isEmpty else { return [] }
        let gaps = Double(units.count - 1) * spacing + Double(units.reduce(0) { $0 + $1 - 1 }) * spacing
        let unit = max(0, (contentWidth - gaps) / Double(units.reduce(0, +)))
        return units.map { Double($0) * unit + Double($0 - 1) * spacing }
    }
}

/// Decodes an element or skips it, so one unreadable entry does not lose the rest of the stored data.
struct Lossy<Element: Decodable>: Decodable {
    let value: Element?
    init(from decoder: Decoder) throws { value = try? Element(from: decoder) }
}

extension KeyedDecodingContainer {
    /// The stored value, or `fallback` when it is missing or unreadable.
    func value<T: Decodable>(_ key: Key, or fallback: T) -> T { (try? decodeIfPresent(T.self, forKey: key)) ?? fallback }

    /// The readable elements of a stored array, skipping the others.
    func elements<T: Decodable>(_ key: Key) -> [T] { ((try? decodeIfPresent([Lossy<T>].self, forKey: key)) ?? []).compactMap(\.value) }
}
