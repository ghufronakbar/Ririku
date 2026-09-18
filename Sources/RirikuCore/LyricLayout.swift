import Foundation

/// Lyric rows sit on a fixed grid, so a line that is too long for one row would be cut off.
/// The island reserves a second row for the active line when any line of the song needs it, which
/// keeps the height steady for the whole song instead of changing with every line.
/// Measuring is injected so this can be tested without a font.
public enum LyricLayout {
    /// A line is checked against the width one row offers, so a song of short lines costs nothing.
    public static func needsTwoRows(_ lines: [String], width: Double, measure: (String) -> Double) -> Bool {
        guard width > 0 else { return false }
        return lines.contains { !$0.isEmpty && measure($0) > width }
    }
}
