import SwiftUI
import RirikuCore

struct ScrollingLyricRows: View {
    let lines: [LyricLine]
    let activeIndex: Int
    let lineCount: Int
    let animate: Bool
    let accent: Color
    @State private var displayedIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(lines: [LyricLine], activeIndex: Int, lineCount: Int, animate: Bool, accent: Color) {
        self.lines = lines
        self.activeIndex = activeIndex
        self.lineCount = lineCount
        self.animate = animate
        self.accent = accent
        _displayedIndex = State(initialValue: activeIndex)
    }

    private var visibleIndices: Range<Int> {
        let center = min(max(0, displayedIndex), max(0, lines.count - 1))
        return max(0, center - 4)..<min(lines.count, center + 5)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(visibleIndices, id: \.self) { index in
                Text(lines[index].text.isEmpty ? "♪" : lines[index].text)
                    .font(.system(size: 13, weight: index == displayedIndex ? .medium : .regular))
                    .foregroundStyle(index == displayedIndex ? accent : .white.opacity(0.45))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity).frame(height: 16)
                    .offset(y: Double(index - displayedIndex + (lineCount == 3 ? 1 : 0)) * 20)
                    .accessibilityHidden(index < displayedIndex - (lineCount == 3 ? 1 : 0)
                        || index > displayedIndex + (lineCount > 1 ? 1 : 0))
            }
        }
        .frame(maxWidth: .infinity).frame(height: Double(lineCount * 20 - 4), alignment: .top)
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
