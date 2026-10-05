import Foundation
import RirikuCore

/// Sizes of the expanded panel's strip and pages.
enum PanelMetrics {
    /// The narrowest a small widget gets before the panel widens; a wide widget gets twice this and a gap.
    static let minimumUnitWidth: Double = 150
    static let widgetSpacing: Double = 12
    static let stripPadding: Double = 14
    static let tabButtonWidth: Double = 28
    static let tabSpacing: Double = 4
    static let gearWidth: Double = 32
    static let emptyPageHeight: Double = 40
}

/// Where everything goes on one page of the expanded panel.
struct ExpandedPanelLayout {
    var width: Double
    var height: Double
    var slotWidths: [String: Double]
    /// Width of the wide music widget on this page, which its lyric rows fit into.
    var lyricWidth: Double?
    var lyricHeight: Double
    var twoLyricRows: Bool
    var showsTabs: Bool
}

/// The panel's size, from the measured notch, the size preferences, the layout, and the content it shows.
extension AppModel {
    /// How far the compact island may grow past the notch, on each axis.
    static let compactWidthRange: Double = 440
    static let compactHeightRange: Double = 40

    /// Total compact size, which the sliders in Setup show and set.
    var compactWidth: Double { notchWidth + compactExtraWidth }
    var islandHeight: Double { topHeight + (music.current == nil ? 0 : compactExtraHeight) }
    /// Artwork and spectrum shrink with a short island so they never spill out of it.
    var compactIconSize: Double { max(14, min(24, islandHeight - 8)) }

    func resetIslandSize() {
        compactExtraWidth = 0
        compactExtraHeight = 0
        panelWidth = 442
    }

    var popupDuration: Double { 0.32 }

    /// Width one lyric row has for text, which decides whether a second row is reserved.
    var lyricTextWidth: Double {
        expanded ? currentExpandedLayout.lyricWidth ?? 0 : compactWidth - 2 * LyricRowLayout.compactPadding
    }

    var reservesTwoLyricRows: Bool { expanded ? currentExpandedLayout.twoLyricRows : music.reservesTwoLyricRows(width: lyricTextWidth) }
    var lyricBlockHeight: Double { music.lyricBlockHeight(width: lyricTextWidth) }
    var islandLyricHeight: Double {
        expanded ? currentExpandedLayout.lyricHeight : music.islandLyricHeight(expanded: false, width: lyricTextWidth)
    }

    var currentExpandedLayout: ExpandedPanelLayout { expandedLayout(for: currentTab, screenWidth: screenWidth) }

    func expandedLayout(for tab: PanelTab, screenWidth: Double) -> ExpandedPanelLayout {
        let slots = tab.widgets
        let units = slots.map(\.units)
        let tabCount = Double(visibleTabs.count)
        let showsTabs = tabCount > 1
        let tabsWidth = showsTabs ? tabCount * PanelMetrics.tabButtonWidth + (tabCount - 1) * PanelMetrics.tabSpacing : 0
        // Tabs sit left of the notch and the gear right of it, so each side needs room for the wider of the two (R-UI-5).
        let chromeWidth = notchWidth + 2 * (PanelMetrics.stripPadding + max(tabsWidth, PanelMetrics.gearWidth))
        let pageWidth = PageGeometry.minimumWidth(units: units, unit: PanelMetrics.minimumUnitWidth, spacing: PanelMetrics.widgetSpacing)
            + 2 * ExpandedLayout.horizontalPadding
        let width = min(max(0, screenWidth - 24), max(panelWidth, notchWidth + 120, pageWidth, chromeWidth))
        let widths = PageGeometry.widths(units: units, contentWidth: width - 2 * ExpandedLayout.horizontalPadding,
                                         spacing: PanelMetrics.widgetSpacing)
        var slotWidths: [String: Double] = [:]
        var lyricWidth: Double?
        for (slot, slotWidth) in zip(slots, widths) {
            slotWidths[slot.id] = slotWidth
            if slot.kind == WidgetKind.music.rawValue && slot.wide { lyricWidth = slotWidth }
        }
        let lyricHeight = lyricWidth.map { music.islandLyricHeight(expanded: true, width: $0) } ?? 0
        let pageHeight = slots.map { slot -> Double in
            switch WidgetKind(rawValue: slot.kind) {
            case .music: return slot.wide ? MusicWidgetLayout.wideHeight(lyricHeight: lyricHeight, error: music.commandError != nil)
                : MusicWidgetLayout.smallHeight(error: music.commandError != nil)
            case .system: return SystemWidgetLayout.height
            case nil: return 0
            }
        }.max() ?? PanelMetrics.emptyPageHeight
        return ExpandedPanelLayout(width: width,
                                   height: islandHeight + ExpandedLayout.topPadding + pageHeight + ExpandedLayout.bottomPadding,
                                   slotWidths: slotWidths, lyricWidth: lyricWidth, lyricHeight: lyricHeight,
                                   twoLyricRows: lyricWidth.map { music.reservesTwoLyricRows(width: $0) } ?? false,
                                   showsTabs: showsTabs)
    }

    func panelSize(screenWidth: Double) -> CGSize {
        // Remembered so the views lay out the panel for the same screen.
        self.screenWidth = screenWidth
        if expanded {
            let layout = currentExpandedLayout
            return CGSize(width: layout.width, height: layout.height)
        }
        let active = music.current != nil
        let width = active ? compactWidth : notchWidth
        return CGSize(width: min(max(0, screenWidth - 24), width), height: islandHeight + (active ? islandLyricHeight : 0))
    }
}
