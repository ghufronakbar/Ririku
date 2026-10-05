import SwiftUI
import RirikuCore

// Timers redraw only while they run and are visible; their end is scheduled by `WidgetStore` (R-WID-4).

struct PomodoroWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore
    let wide: Bool

    var body: some View {
        let settings = widgets.data.pomodoro
        let state = widgets.data.pomodoroState
        let running = state.clock.isRunning
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(phaseName(state.phase)).widgetCaption()
                Spacer(minLength: 4)
                ForEach(0..<settings.roundsBeforeLongBreak, id: \.self) { index in
                    Circle().fill(index < state.roundsDone(settings: settings) ? model.accent : Color.white.opacity(0.2)).frame(width: 5, height: 5)
                }
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(model.t("%1$@ of %2$@ focus sessions done", "\(state.roundsDone(settings: settings))", "\(settings.roundsBeforeLongBreak)"))
            TimelineView(.animation(minimumInterval: 1, paused: !running)) { context in
                Text(WidgetFormat.duration(state.remaining(at: context.date, settings: settings), roundingUp: true))
                    .font(WidgetFormat.bigNumber(wide ? 34 : 28)).lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                WidgetButton(icon: running ? "pause.fill" : "play.fill", label: running ? model.t("Pause") : model.t("Start"), prominent: true) {
                    widgets.togglePomodoro()
                }
                WidgetButton(icon: "arrow.counterclockwise", label: model.t("Reset")) { widgets.resetPomodoro() }
                WidgetButton(icon: "forward.end.fill", label: model.t("Skip to the next phase")) { widgets.skipPomodoro() }
            }
        }
        .widgetCard()
    }

    private func phaseName(_ phase: PomodoroPhase) -> String {
        switch phase {
        case .focus: return model.t("Focus")
        case .shortBreak: return model.t("Short Break")
        case .longBreak: return model.t("Long Break")
        }
    }
}

struct CountdownWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore
    let wide: Bool

    var body: some View {
        let state = widgets.data.countdown
        let running = state.clock.isRunning
        // The duration can change only before the countdown starts.
        let fresh = !running && state.clock.accumulated == 0
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t("Countdown")).widgetCaption()
            TimelineView(.animation(minimumInterval: 1, paused: !running)) { context in
                Text(WidgetFormat.duration(state.remaining(at: context.date), roundingUp: true))
                    .font(WidgetFormat.bigNumber(wide ? 34 : 28)).lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                WidgetButton(icon: running ? "pause.fill" : "play.fill", label: running ? model.t("Pause") : model.t("Start"), prominent: true) {
                    widgets.toggleCountdown()
                }
                if fresh {
                    WidgetButton(icon: "minus", label: model.t("One minute less")) { widgets.adjustCountdown(minutes: -1) }
                    WidgetButton(icon: "plus", label: model.t("One minute more")) { widgets.adjustCountdown(minutes: 1) }
                } else {
                    WidgetButton(icon: "arrow.counterclockwise", label: model.t("Reset")) { widgets.resetCountdown() }
                }
            }
        }
        .widgetCard()
    }
}

struct StopwatchWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore
    let wide: Bool

    var body: some View {
        let clock = widgets.data.stopwatch
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t("Stopwatch")).widgetCaption()
            TimelineView(.animation(minimumInterval: 0.1, paused: !clock.isRunning)) { context in
                let elapsed = clock.elapsed(at: context.date)
                Text(WidgetFormat.duration(elapsed) + String(format: ".%d", Int(elapsed * 10) % 10))
                    .font(WidgetFormat.bigNumber(wide ? 34 : 28)).lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                WidgetButton(icon: clock.isRunning ? "pause.fill" : "play.fill", label: clock.isRunning ? model.t("Pause") : model.t("Start"), prominent: true) {
                    widgets.toggleStopwatch()
                }
                WidgetButton(icon: "arrow.counterclockwise", label: model.t("Reset")) { widgets.resetStopwatch() }
                    .disabled(clock.elapsed(at: Date()) == 0)
            }
        }
        .widgetCard()
    }
}
