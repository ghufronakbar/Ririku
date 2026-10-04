/// Row sizes of the expanded music panel. `MusicIslandView` lays out with the same values, so the window is
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

/// Lyric row sizes, shared by the models and the views that draw them.
enum LyricRowLayout {
    /// One row of 13 pt text plus the gap below it.
    static let step: Double = 20
    static let textHeight: Double = 16
    /// Side padding of the lyric block inside the compact island.
    static let compactPadding: Double = 18
}
