import Foundation
import Testing
@testable import RirikuCore

private let known: Set<String> = ["music", "system"]

private func decode(_ json: String) -> PanelLayout {
    (try? JSONDecoder().decode(PanelLayout.self, from: Data(json.utf8)))?.sanitized(widgetKinds: known) ?? .standard
}

@Suite("Panel layout")
struct PanelLayoutTests {
    @Test("The standard layout is Home with wide music and small system")
    func standardLayout() {
        let tabs = PanelLayout.standard.tabs
        #expect(tabs.map(\.id) == ["home"])
        #expect(tabs[0].widgets.map(\.kind) == ["music", "system"])
        #expect(tabs[0].widgets.map(\.wide) == [true, false])
    }

    @Test("Skips unknown widgets, unknown tab kinds, and unreadable entries without losing the rest")
    func skipsWhatItCannotShow() {
        let layout = decode("""
        {"version": 2, "tabs": [
          {"id": "a", "kind": "widgets", "icon": "star", "widgets": [
            {"id": "w1", "kind": "weather"}, {"kind": "music"}, {"id": "w2", "kind": "system", "wide": true}]},
          {"id": "tray", "kind": "tray", "icon": "tray"},
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
        #expect(PanelLayout.standard.sanitized(widgetKinds: ["music"]).tabs[0].widgets.map(\.kind) == ["music"])
    }

    @Test("Keeps each widget kind and each identifier once, valid icons, short names, and at most eight tabs")
    func enforcesLimits() {
        var tabs = (0..<10).map { PanelTab(id: "t\($0)", name: String(repeating: "x", count: 40), icon: "not.a.symbol") }
        tabs[0].widgets = [WidgetSlot(id: "m", kind: "music", wide: true), WidgetSlot(id: "m2", kind: "music", wide: false)]
        tabs[1].widgets = [WidgetSlot(id: "m", kind: "system", wide: false)]
        tabs.append(PanelTab(id: "t0", icon: "house"))
        let layout = PanelLayout(tabs: tabs).sanitized(widgetKinds: known)
        #expect(layout.tabs.count == PanelLayout.maximumTabs)
        #expect(layout.tabs[0].widgets.map(\.id) == ["m"])
        #expect(layout.tabs[1].widgets.isEmpty, "a repeated identifier is dropped")
        #expect(layout.tabs.allSatisfy { $0.name.count == PanelLayout.maximumNameLength && $0.icon == "square.grid.2x2" })
    }

    @Test("Survives a round trip through JSON")
    func roundTrip() throws {
        var layout = PanelLayout.standard
        layout.addPage()
        let data = try JSONEncoder().encode(layout)
        #expect(try JSONDecoder().decode(PanelLayout.self, from: data) == layout)
    }

    @Test("Adds and removes pages, keeping at least one visible")
    func editsPages() throws {
        var layout = PanelLayout.standard
        let added = layout.addPage()
        let page = try #require(added)
        #expect(layout.tabs.map(\.id) == ["home", page])
        layout.moveTab(id: page, by: -1)
        #expect(layout.tabs.map(\.id) == [page, "home"])
        layout.removeTab(id: page)
        layout.removeTab(id: "home")
        #expect(layout.tabs.map(\.id) == ["home"], "the last page stays")
        while layout.addPage() != nil {}
        #expect(layout.tabs.count == PanelLayout.maximumTabs)
    }

    @Test("Adds each widget once and moves widgets within and between pages")
    func editsWidgets() throws {
        var layout = PanelLayout.standard
        let added = layout.addPage()
        let page = try #require(added)
        layout.addWidget(kind: "music", wide: false, toTab: page)
        #expect(layout.tabs[1].widgets.isEmpty, "music is already on Home")
        #expect(layout.unusedKinds(of: ["music", "system"]).isEmpty)
        layout.moveWidgets(inTab: "home", from: IndexSet(integer: 1), to: 0)
        #expect(layout.tabs[0].widgets.map(\.kind) == ["system", "music"])
        layout.moveWidget(id: "system", by: 1)
        #expect(layout.tabs[0].widgets.map(\.kind) == ["music", "system"])
        layout.moveWidget(id: "system", toTab: page)
        #expect(layout.tabs[0].widgets.map(\.kind) == ["music"])
        #expect(layout.tabs[1].widgets.map(\.kind) == ["system"])
        layout.setWide(true, forWidget: "system")
        #expect(layout.tabs[1].widgets[0].wide)
        layout.removeWidget(id: "music")
        #expect(layout.unusedKinds(of: ["music", "system"]) == ["music"])
        layout.addWidget(kind: "music", wide: true, toTab: page)
        #expect(layout.tabs[1].widgets.map(\.kind) == ["system", "music"])
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
