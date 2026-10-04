import SwiftUI
import RirikuCore

struct ScrollingLyricRows: View {
    let lines: [LyricLine]
    let activeIndex: Int
    let lineCount: Int
    let animate: Bool
    let accent: Color
    /// The active line may use two rows when the song has lines too long for one.
    let twoRows: Bool
    @State private var displayedIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(lines: [LyricLine], activeIndex: Int, lineCount: Int, animate: Bool, accent: Color, twoRows: Bool) {
        self.lines = lines
        self.activeIndex = activeIndex
        self.lineCount = lineCount
        self.animate = animate
        self.accent = accent
        self.twoRows = twoRows
        _displayedIndex = State(initialValue: activeIndex)
    }

    private var visibleIndices: Range<Int> {
        let center = min(max(0, displayedIndex), max(0, lines.count - 1))
        return max(0, center - 4)..<min(lines.count, center + 5)
    }

    /// Height the active row takes beyond a single row.
    private var extra: Double { twoRows ? LyricRowLayout.step : 0 }

    /// Rows keep the fixed grid; only the rows below the active line move down by its extra height.
    private func offset(for index: Int) -> Double {
        let distance = index - displayedIndex
        let lead = lineCount == 3 ? LyricRowLayout.step : 0
        return lead + Double(distance) * LyricRowLayout.step + (distance > 0 ? extra : 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(visibleIndices, id: \.self) { index in
                let active = index == displayedIndex
                Text(lines[index].text.isEmpty ? "♪" : lines[index].text)
                    .font(.system(size: 13, weight: active ? .medium : .regular))
                    .foregroundStyle(active ? accent : .white.opacity(0.45))
                    .lineLimit(active && twoRows ? 2 : 1)
                    // A line that overflows by a little shrinks instead of wrapping.
                    .minimumScaleFactor(active ? 0.85 : 1)
                    .frame(maxWidth: .infinity).frame(height: LyricRowLayout.textHeight + (active ? extra : 0))
                    .offset(y: offset(for: index))
                    .accessibilityHidden(index < displayedIndex - (lineCount == 3 ? 1 : 0)
                        || index > displayedIndex + (lineCount > 1 ? 1 : 0))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Double(lineCount) * LyricRowLayout.step - 4 + extra, alignment: .top)
        .clipped()
        .onChange(of: activeIndex) { old, new in
            withAnimation(animate && !reduceMotion && new == old + 1 ? .easeInOut(duration: 0.28) : nil) {
                displayedIndex = new
            }
        }
        .onChange(of: lines) { _, _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { displayedIndex = activeIndex }
        }
    }
}
