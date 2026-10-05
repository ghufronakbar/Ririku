import Foundation
import Testing
@testable import RirikuCore

private let known: Set<String> = ["music", "system"]
private let tools: Set<String> = ["tray", "clipboard"]

private func decode(_ json: String) -> PanelLayout {
    (try? JSONDecoder().decode(PanelLayout.self, from: Data(json.utf8)))?.sanitized(widgetKinds: known, toolKinds: tools) ?? .standard
}

private extension PanelLayout {
    func tab(_ id: String) -> PanelTab { tabs.first { $0.id == id }! }
}

@Suite("Panel layout")
struct PanelLayoutTests {
    @Test("The standard layout is Home with wide music and small system, then the Tray")
    func standardLayout() {
        let tabs = PanelLayout.standard.tabs
        #expect(tabs.map(\.id) == ["home", "tray"])
        #expect(tabs[1].kind == PanelTab.trayKind)
        #expect(tabs[0].widgets.map(\.kind) == ["music", "system"])
        #expect(tabs[0].widgets.map(\.wide) == [true, false])
    }

    @Test("Skips unknown widgets, unknown tab kinds, and unreadable entries without losing the rest")
    func skipsWhatItCannotShow() {
        let layout = decode("""
        {"version": 2, "tabs": [
          {"id": "a", "kind": "widgets", "icon": "star", "widgets": [
            {"id": "w1", "kind": "weather"}, {"kind": "music"}, {"id": "w2", "kind": "system", "wide": true}]},
          {"id": "web", "kind": "web", "icon": "globe"},
          {"kind": "widgets"},
          {"id": "b", "kind": "widgets"}
        ]}
        """)
        #expect(layout.tabs.map(\.id) == ["a", "b"])
        #expect(layout.tabs[0].widgets.map(\.id) == ["w2"])
        #expect(layout.tabs[0].widgets[0].wide)
        #expect(layout.tabs[1].icon == "square.grid.2x2", "a missing icon becomes the default page icon")
        #expect(layout.version == PanelLayout.currentVersion)
    }

    @Test("Falls back to the standard layout when nothing visible is left")
    func fallsBackToStandard() {
        #expect(decode("{}") == .standard)
        #expect(decode(#"{"tabs": [{"id": "a", "kind": "widgets", "hidden": true}]}"#) == .standard)
        #expect(decode("not json") == .standard)
        #expect(PanelLayout.standard.sanitized(widgetKinds: ["music"], toolKinds: tools).tabs[0].widgets.map(\.kind) == ["music"])
    }

    @Test("Keeps each widget kind and each identifier once, valid icons, short names, and at most eight tabs")
    func enforcesLimits() {
        var tabs = (0..<10).map { PanelTab(id: "t\($0)", name: String(repeating: "x", count: 40), icon: "not.a.symbol") }
        tabs[0].widgets = [WidgetSlot(id: "m", kind: "music", wide: true), WidgetSlot(id: "m2", kind: "music", wide: false)]
        tabs[1].widgets = [WidgetSlot(id: "m", kind: "system", wide: false)]
        tabs.append(PanelTab(id: "t0", icon: "house"))
        let layout = PanelLayout(tabs: tabs).sanitized(widgetKinds: known, toolKinds: tools)
        #expect(layout.tabs.count == PanelLayout.maximumTabs)
        #expect(layout.tabs[0].widgets.map(\.id) == ["m"])
        #expect(layout.tabs[1].widgets.isEmpty, "a repeated identifier is dropped")
        #expect(layout.tabs.allSatisfy { (tab: PanelTab) in tab.name.count == PanelLayout.maximumNameLength && tab.icon == "square.grid.2x2" })
    }

    @Test("Survives a round trip through JSON")
    func roundTrip() throws {
        var layout = PanelLayout.standard
        layout.addPage()
        let data = try JSONEncoder().encode(layout)
        #expect(try JSONDecoder().decode(PanelLayout.self, from: data) == layout)
    }

    @Test("Adds, moves, hides, and removes tabs, keeping at least one visible")
    func editsPages() throws {
        var layout = PanelLayout.standard
        let added = layout.addPage()
        let page = try #require(added)
        #expect(layout.tabs.map(\.id) == ["home", "tray", page])
        layout.moveTab(id: page, by: -2)
        #expect(layout.tabs.map(\.id) == [page, "home", "tray"])
        layout.removeTab(id: page)
        layout.setHidden(true, forTab: "tray")
        layout.removeTab(id: "home")
        layout.setHidden(true, forTab: "home")
        #expect(layout.visibleTabs.map(\.id) == ["home"], "the last visible tab stays")
        layout.setHidden(false, forTab: "tray")
        while layout.addPage() != nil {}
        #expect(layout.tabs.count == PanelLayout.maximumTabs)
    }

    @Test("Adds each widget once and moves widgets within and between pages")
    func editsWidgets() throws {
        var layout = PanelLayout.standard
        let added = layout.addPage()
        let page = try #require(added)
        layout.addWidget(kind: "music", wide: false, toTab: page)
        #expect(layout.tab(page).widgets.isEmpty, "music is already on Home")
        #expect(layout.unusedKinds(of: ["music", "system"]).isEmpty)
        layout.moveWidgets(inTab: "home", from: IndexSet(integer: 1), to: 0)
        #expect(layout.tabs[0].widgets.map(\.kind) == ["system", "music"])
        layout.moveWidget(id: "system", by: 1)
        #expect(layout.tabs[0].widgets.map(\.kind) == ["music", "system"])
        layout.moveWidget(id: "system", toTab: "tray")
        #expect(layout.tab("tray").widgets.isEmpty, "a tool takes no widgets")
        layout.moveWidget(id: "system", toTab: page)
        #expect(layout.tabs[0].widgets.map(\.kind) == ["music"])
        #expect(layout.tab(page).widgets.map(\.kind) == ["system"])
        layout.setWide(true, forWidget: "system")
        #expect(layout.tab(page).widgets[0].wide)
        layout.removeWidget(id: "music")
        #expect(layout.unusedKinds(of: ["music", "system"]) == ["music"])
        layout.addWidget(kind: "music", wide: true, toTab: "tray")
        #expect(layout.unusedKinds(of: ["music", "system"]) == ["music"], "a tool takes no widgets")
        layout.addWidget(kind: "music", wide: true, toTab: page)
        #expect(layout.tab(page).widgets.map(\.kind) == ["system", "music"])
    }
}

@Suite("Page geometry")
struct PageGeometryTests {
    @Test("A wide slot is two small slots and the gap between them")
    func sharesWidth() {
        #expect(PageGeometry.minimumWidth(units: [2, 1], unit: 150, spacing: 12) == 474)
        #expect(PageGeometry.widths(units: [2, 1], contentWidth: 474, spacing: 12) == [312, 150])
        #expect(PageGeometry.widths(units: [1, 1], contentWidth: 312, spacing: 12) == [150, 150])
        #expect(PageGeometry.widths(units: [2], contentWidth: 398, spacing: 12) == [398])
        #expect(PageGeometry.minimumWidth(units: [], unit: 150, spacing: 12) == 0)
    }
}

@Suite("System statistics")
struct SystemStatsTests {
    @Test("Processor use is the busy share of the ticks since the last sample")
    func cpuUsage() {
        let old = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        #expect(SystemStats.cpuUsage(from: old, to: CPUTicks(user: 130, system: 60, idle: 860, nice: 50)) == 0.4)
        #expect(SystemStats.cpuUsage(from: old, to: old) == nil, "no time passed")
        let fewTicks = CPUTicks(user: 105, system: 50, idle: 805, nice: 50)
        #expect(SystemStats.cpuUsage(from: old, to: fewTicks, minimumTicks: 400) == nil, "a few ticks between bursts would give a wrong value")
        #expect(SystemStats.cpuUsage(from: old, to: fewTicks) == 0.5)
        let wrapped = CPUTicks(user: UInt32.max - 9, system: 0, idle: UInt32.max - 9, nice: 0)
        #expect(SystemStats.cpuUsage(from: wrapped, to: CPUTicks(user: 10, system: 0, idle: 10, nice: 0)) == 0.5, "32-bit counters wrap")
    }

    @Test("Memory in use counts app, wired, and compressed pages")
    func memoryUsed() {
        #expect(SystemStats.memoryUsed(internalPages: 100, purgeablePages: 20, wiredPages: 30, compressedPages: 10, pageSize: 16384) == 120 * 16384)
        #expect(SystemStats.memoryUsed(internalPages: 5, purgeablePages: 20, wiredPages: 0, compressedPages: 0, pageSize: 4096) == 0)
        #expect(SystemStats.fraction(3, of: 4) == 0.75)
        #expect(SystemStats.fraction(5, of: 4) == 1)
        #expect(SystemStats.fraction(1, of: 0) == 0)
    }
}

@Suite("Tool tabs")
struct ToolTabTests {
    @Test("A layout saved before version 2 gets the Tray once")
    func addsTrayOnce() {
        let old = decode(#"{"version": 1, "tabs": [{"id": "home", "kind": "widgets", "icon": "house"}]}"#)
        #expect(old.tabs.map(\.id) == ["home", "tray"])
        #expect(old.version == 2)
        let removed = decode(#"{"version": 2, "tabs": [{"id": "home", "kind": "widgets", "icon": "house"}]}"#)
        #expect(removed.tabs.map(\.id) == ["home"], "a layout from version 2 keeps the Tray off when it has none")
    }

    @Test("Keeps each tool once, without widgets, with its own icon")
    func sanitizesTools() {
        let layout = decode("""
        {"tabs": [{"id": "home", "kind": "widgets", "icon": "house"},
          {"id": "t1", "kind": "tray", "icon": "star", "name": "Mine", "widgets": [{"id": "s", "kind": "system"}], "hidden": true},
          {"id": "t2", "kind": "tray", "icon": "tray"}, {"id": "c", "kind": "clipboard", "icon": "x"}]}
        """)
        #expect(layout.tabs.map(\.id) == ["home", "t1", "c"])
        #expect(layout.tabs[1].widgets.isEmpty && layout.tabs[1].icon == "tray" && layout.tabs[1].name.isEmpty && layout.tabs[1].hidden)
        #expect(layout.tabs[2].icon == "doc.on.clipboard")
    }

    @Test("Adds and removes a tool's tab")
    func addsAndRemovesTools() {
        var layout = PanelLayout.standard
        layout.addTool(PanelTab.clipboardKind)
        layout.addTool(PanelTab.clipboardKind)
        #expect(layout.tabs.map(\.kind) == ["widgets", "tray", "clipboard"])
        layout.removeTool(PanelTab.clipboardKind)
        layout.removeTool(PanelTab.pageKind)
        #expect(layout.tabs.map(\.kind) == ["widgets", "tray"], "pages are never removed as a tool")
    }
}

@Suite("Tray and clipboard lists")
struct TrayClipboardListTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Tray items: newest first, each file once, at most fifty")
    func addsTrayItems() {
        let a = TrayItem(path: "/a", name: "a", bookmark: Data())
        let b = TrayItem(path: "/b", name: "b", bookmark: Data())
        let again = TrayItem(path: "/a", name: "a", bookmark: Data([1]))
        #expect(TrayItems.adding([b], to: [a]).map(\.path) == ["/b", "/a"])
        #expect(TrayItems.adding([again], to: [b, a]).map(\.path) == ["/a", "/b"], "the same file moves to the front")
        let many = (0..<60).map { TrayItem(path: "/\($0)", name: "\($0)", bookmark: Data()) }
        #expect(TrayItems.adding(many, to: []).count == TrayItems.maximum)
        #expect(TrayItems.decode(Data(#"[{"id":"1","path":"/x","name":"x","bookmark":""},{"broken":true}]"#.utf8)).map(\.path) == ["/x"])
    }

    @Test("Skips secrets, transient and generated content, and copied files")
    func skipsSecrets() {
        #expect(ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
        #expect(ClipboardHistory.shouldSkip(types: ["org.nspasteboard.TransientType"]))
        #expect(ClipboardHistory.shouldSkip(types: ["org.nspasteboard.AutoGeneratedType"]))
        #expect(ClipboardHistory.shouldSkip(types: ["public.file-url", "public.utf8-plain-text"]))
        #expect(!ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text"]))
    }

    @Test("Clipboard entries: the same content moves up, and old entries leave")
    func addsClipboardEntries() {
        let first = ClipboardEntry(kind: .text, text: "one", digest: "1", date: date)
        let second = ClipboardEntry(kind: .text, text: "two", digest: "2", date: date)
        let repeated = ClipboardEntry(kind: .text, text: "one", digest: "1", date: date)
        let result = ClipboardHistory.adding(repeated, to: [second, first])
        #expect(result.entries.map(\.id) == [repeated.id, second.id])
        #expect(result.removed.map(\.id) == [first.id])
        let full = (0..<50).map { ClipboardEntry(kind: .text, text: "\($0)", digest: "\($0)", date: date) }
        let overflow = ClipboardHistory.adding(ClipboardEntry(kind: .text, text: "new", digest: "new", date: date), to: full)
        #expect(overflow.entries.count == ClipboardHistory.maximum)
        #expect(overflow.removed.map(\.digest) == ["49"])
    }

    @Test("Stored entries must be readable and valid")
    func decodesEntries() {
        let json = """
        [{"id":"1","kind":"text","text":"hi","digest":"a","date":0},
         {"id":"2","kind":"image","imageFile":"../escape.png","digest":"b","date":0},
         {"id":"3","kind":"text","text":"","digest":"c","date":0}, {"oops":1}]
        """
        #expect(ClipboardHistory.decode(Data(json.utf8)).map(\.id) == ["1"])
    }
}
