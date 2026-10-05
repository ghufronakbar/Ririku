/// Row sizes of the expanded panel and the wide music widget. The views lay out with the same values, so the window is
/// exactly as tall as the rows it draws instead of a guessed constant.
enum ExpandedLayout {
    static let spacing: Double = 12
    static let topPadding: Double = 12
    static let bottomPadding: Double = 14
    static let horizontalPadding: Double = 22
    static let artworkSize: Double = 48
    static let seekBarHeight: Double = 20
    static let seekLabelSpacing: Double = 2
    static let timeRowHeight: Double = 13
    static let transportHeight: Double = 32
    static let transportSpacing: Double = 24
    /// Two lines of `caption2`, the limit on the command error.
    static let errorHeight: Double = 26
}

/// Heights of the music widget, which `PanelGeometry` adds up for the panel.
enum MusicWidgetLayout {
    static let smallArtworkSize: Double = 40
    static let smallHeaderSpacing: Double = 10

    static func wideHeight(lyricHeight: Double, error: Bool) -> Double {
        var height = ExpandedLayout.artworkSize
            + ExpandedLayout.spacing + ExpandedLayout.seekBarHeight + ExpandedLayout.seekLabelSpacing + ExpandedLayout.timeRowHeight
            + ExpandedLayout.spacing + ExpandedLayout.transportHeight
        if lyricHeight > 0 { height += lyricHeight + ExpandedLayout.spacing }
        if error { height += ExpandedLayout.errorHeight + ExpandedLayout.spacing }
        return height
    }

    static func smallHeight(error: Bool) -> Double {
        smallArtworkSize + smallHeaderSpacing + ExpandedLayout.transportHeight
            + (error ? ExpandedLayout.errorHeight + ExpandedLayout.spacing : 0)
    }
}

/// Lyric row sizes, shared by the models and the views that draw them.
enum LyricRowLayout {
    /// One row of 13 pt text plus the gap below it.
    static let step: Double = 20
    static let textHeight: Double = 16
    /// Side padding of the lyric block inside the compact island.
    static let compactPadding: Double = 18
}
