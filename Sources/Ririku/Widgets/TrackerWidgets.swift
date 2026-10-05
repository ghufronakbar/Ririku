import SwiftUI
import RirikuCore

struct CounterWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore
    let wide: Bool

    var body: some View {
        let counter = widgets.data.counter
        VStack(alignment: .leading, spacing: 6) {
            Text(counter.title.isEmpty ? model.t("Counter") : counter.title).widgetCaption()
            Text(counter.value.formatted(.number.locale(model.locale)))
                .font(WidgetFormat.bigNumber(wide ? 38 : 32)).lineLimit(1).minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                WidgetButton(icon: "minus", label: model.t("Count down by one")) { widgets.changeCounter(by: -1) }
                WidgetButton(icon: "plus", label: model.t("Count up by one"), prominent: true) { widgets.changeCounter(by: 1) }
                Spacer(minLength: 0)
                WidgetButton(icon: "arrow.counterclockwise", label: model.t("Reset")) { widgets.resetCounter() }
                    .disabled(counter.value == 0)
            }
        }
        .widgetCard()
    }
}

struct WaterWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore
    let wide: Bool

    var body: some View {
        let goal = widgets.data.water.goal
        let count = widgets.waterToday()
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t("Water")).widgetCaption()
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(.white.opacity(0.15), lineWidth: 5)
                    Circle().trim(from: 0, to: min(1, Double(count) / Double(goal)))
                        .stroke(model.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: count >= goal ? "checkmark" : "drop.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(model.accent)
                }
                .frame(width: 40, height: 40)
                Text(model.t("%1$@ of %2$@", count.formatted(.number.locale(model.locale)), goal.formatted(.number.locale(model.locale))))
                    .font(.system(size: wide ? 20 : 17, weight: .semibold).monospacedDigit())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.t("Water"))
            .accessibilityValue(model.t("%1$@ of %2$@ glasses", "\(count)", "\(goal)"))
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                WidgetButton(icon: "minus", label: model.t("One glass less")) { widgets.changeWater(by: -1) }
                    .disabled(count == 0)
                WidgetButton(icon: "plus", label: model.t("One glass more"), prominent: true) { widgets.changeWater(by: 1) }
            }
        }
        .widgetCard()
    }
}

/// A plain note, saved on this Mac as it is typed. Clicking it lets the panel take keyboard focus (R-UI-2).
struct NotesWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $widgets.notes)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .accessibilityLabel(model.t("Notes"))
            if widgets.notes.isEmpty {
                Text(model.t("Write a note…")).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 5).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .widgetCard()
    }
}
