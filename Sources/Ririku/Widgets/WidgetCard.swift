import SwiftUI

/// Every widget except music sits on a card of the same height, so small widgets side by side stay apart.
enum WidgetCardLayout {
    static let padding: Double = 10
    static let height: Double = 118
    /// Height inside the padding.
    static let contentHeight = height - 2 * padding
}

extension View {
    func widgetCard() -> some View {
        padding(WidgetCardLayout.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(height: WidgetCardLayout.height)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.07)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// The small title row at the top of a card.
    func widgetCaption() -> some View {
        font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
    }
}

/// A round icon button for widget controls, with a VoiceOver label.
struct WidgetButton: View {
    let icon: String
    let label: String
    var prominent = false
    var size: Double = 26
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .background(Circle().fill(prominent ? Color.white.opacity(0.24) : Color.white.opacity(0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

enum WidgetFormat {
    /// "4:05" or "1:04:05". Countdowns round up, so they show 0:01 until they end.
    static func duration(_ seconds: TimeInterval, roundingUp: Bool = false) -> String {
        let total = max(0, Int(roundingUp ? seconds.rounded(.up) : seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = total / 60 % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, total % 60) : String(format: "%d:%02d", minutes, total % 60)
    }

    /// Large numeric text for timers and counts.
    static func bigNumber(_ size: Double = 28) -> Font { .system(size: size, weight: .semibold, design: .rounded).monospacedDigit() }
}
