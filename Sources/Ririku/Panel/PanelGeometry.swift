import Foundation

/// The panel's size, from the measured notch, the size preferences, and the music content it shows.
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
        expanded ? panelWidth - 2 * ExpandedLayout.horizontalPadding : compactWidth - 2 * LyricRowLayout.compactPadding
    }

    var reservesTwoLyricRows: Bool { music.reservesTwoLyricRows(width: lyricTextWidth) }
    var lyricBlockHeight: Double { music.lyricBlockHeight(width: lyricTextWidth) }
    var islandLyricHeight: Double { music.islandLyricHeight(expanded: expanded, width: lyricTextWidth) }

    var expandedContentHeight: Double {
        var height = ExpandedLayout.topPadding + ExpandedLayout.artworkSize
            + ExpandedLayout.spacing + ExpandedLayout.seekBarHeight + ExpandedLayout.seekLabelSpacing + ExpandedLayout.timeRowHeight
            + ExpandedLayout.spacing + ExpandedLayout.transportHeight
            + ExpandedLayout.bottomPadding
        if islandLyricHeight > 0 { height += islandLyricHeight + ExpandedLayout.spacing }
        if music.commandError != nil { height += ExpandedLayout.errorHeight + ExpandedLayout.spacing }
        return height
    }

    func panelSize(screenWidth: Double) -> CGSize {
        let active = music.current != nil
        let width = expanded ? max(panelWidth, notchWidth + 120) : active ? compactWidth : notchWidth
        let extraHeight = expanded ? expandedContentHeight : active ? islandLyricHeight : 0
        return CGSize(width: min(max(0, screenWidth - 24), width), height: islandHeight + extraHeight)
    }
}
