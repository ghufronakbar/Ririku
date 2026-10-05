import SwiftUI
import RirikuCore

struct ClockWidgetView: View {
    @ObservedObject var model: AppModel
    let wide: Bool

    var body: some View {
        let locale = timeLocale
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.date.formatted(.dateTime.weekday(.wide).locale(locale))).widgetCaption()
                Text(context.date.formatted(.dateTime.hour().minute().locale(locale)))
                    .font(WidgetFormat.bigNumber(wide ? 40 : 32)).lineLimit(1).minimumScaleFactor(0.5)
                Spacer(minLength: 0)
                Text(context.date.formatted(wide ? .dateTime.day().month(.wide).year().locale(locale) : .dateTime.day().month(.abbreviated).locale(locale)))
                    .font(.callout).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
            }
        }
        .widgetCard()
    }

    /// The interface language, with the 12- or 24-hour clock chosen in System Settings.
    private var timeLocale: Locale {
        var components = Locale.Components(locale: model.locale)
        components.hourCycle = Locale.autoupdatingCurrent.hourCycle
        return Locale(components: components)
    }
}

struct NetworkWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var monitor: NetworkMonitor
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t("Network")).widgetCaption()
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    rate("arrow.down", label: model.t("Download"), value: monitor.received)
                    rate("arrow.up", label: model.t("Upload"), value: monitor.sent)
                }
                if wide {
                    Sparkline(series: [monitor.receivedHistory, monitor.sentHistory], colors: [model.accent, .white.opacity(0.45)],
                              capacity: NetworkMonitor.historyLength)
                        .frame(maxWidth: .infinity).frame(height: 50)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetCard()
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private func rate(_ icon: String, label: String, value: Double?) -> some View {
        let text = value.map { model.t("%@/s", Int64($0).formatted(.byteCount(style: .file).locale(model.locale))) } ?? "–"
        return HStack(spacing: 6) {
            Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(model.accent).frame(width: 14)
            Text(text).font(.system(size: 15, weight: .semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(text)
    }
}

/// A small line chart of recent values, newest on the right. Decorative; the numbers beside it carry the meaning.
struct Sparkline: View {
    let series: [[Double]]
    let colors: [Color]
    let capacity: Int

    var body: some View {
        GeometryReader { proxy in
            let top = max(1, series.flatMap { $0 }.max() ?? 1)
            ZStack {
                ForEach(series.indices, id: \.self) { index in
                    Path { path in
                        let values = series[index]
                        guard values.count > 1 else { return }
                        for (offset, value) in values.enumerated() {
                            let step = Double(values.count - 1 - offset) / Double(max(1, capacity - 1))
                            let point = CGPoint(x: proxy.size.width * (1 - step), y: proxy.size.height * (1 - value / top))
                            offset == 0 ? path.move(to: point) : path.addLine(to: point)
                        }
                    }
                    .stroke(colors[index], style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct BatteryWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var monitor: BatteryMonitor
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t("Battery")).widgetCaption()
            if let reading = monitor.reading {
                let low = reading.fraction <= 0.2 && !reading.onPower
                HStack(spacing: 8) {
                    Image(systemName: icon(reading)).font(.system(size: 22)).foregroundStyle(low ? Color.orange : model.accent)
                        .accessibilityHidden(true)
                    Text(reading.fraction.formatted(.percent.precision(.fractionLength(0)).locale(model.locale)))
                        .font(WidgetFormat.bigNumber(wide ? 34 : 28))
                }
                Spacer(minLength: 0)
                Text(state(reading)).font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
            } else {
                Spacer(minLength: 0)
                Text(model.t("This Mac has no battery.")).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
        }
        .widgetCard()
        .onAppear { monitor.refresh() }
    }

    private func icon(_ reading: BatteryMonitor.Reading) -> String {
        if reading.charging { return "battery.100percent.bolt" }
        let levels = [(0.88, "100"), (0.63, "75"), (0.38, "50"), (0.13, "25")]
        return "battery." + (levels.first { reading.fraction >= $0.0 }?.1 ?? "0") + "percent"
    }

    /// "Charging", "On battery", and so on; the wide widget adds the time macOS estimates.
    private func state(_ reading: BatteryMonitor.Reading) -> String {
        if reading.charged && reading.onPower { return model.t("Fully charged") }
        if reading.charging {
            guard wide, let minutes = reading.minutesToFull else { return model.t("Charging") }
            return model.t("Charging · %@ until full", hours(minutes))
        }
        if reading.onPower { return model.t("On power, not charging") }
        guard wide, let minutes = reading.minutesToEmpty else { return model.t("On battery") }
        return model.t("On battery · %@ left", hours(minutes))
    }

    private func hours(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(model.locale))
    }
}

struct DaysLeftWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore
    let wide: Bool

    var body: some View {
        let state = widgets.data.daysLeft
        VStack(alignment: .leading, spacing: 2) {
            Text(state.title.isEmpty ? model.t("Days Left") : state.title).widgetCaption()
            if let days = widgets.daysLeft() {
                Text(days == 0 ? model.t("Today") : abs(days).formatted(.number.locale(model.locale)))
                    .font(WidgetFormat.bigNumber(wide ? 38 : 32)).lineLimit(1).minimumScaleFactor(0.5)
                if days != 0 { Text(label(days)).font(.callout).foregroundStyle(.white.opacity(0.75)) }
                Spacer(minLength: 0)
                if wide, let target = state.target {
                    Text(target.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: model.locale)))
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
            } else {
                Spacer(minLength: 0)
                Text(model.t("Choose a date in Setup → Widgets.")).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
        }
        .widgetCard()
    }

    private func label(_ days: Int) -> String {
        switch days {
        case 1: return model.t("day left")
        case 2...: return model.t("days left")
        case -1: return model.t("day ago")
        default: return model.t("days ago")
        }
    }
}
