import SwiftUI

/// The closed panel: the music island, or a running timer while no music plays (R-WID-1), with a notice below it
/// for a few seconds (R-UI-6).
struct CompactPanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    @ObservedObject var widgets: WidgetStore

    var body: some View {
        VStack(spacing: 0) {
            if let live = model.liveTimer {
                LiveTimerStrip(model: model, widgets: widgets, timer: live)
            } else {
                MusicIslandView(model: model, music: music)
            }
            if let notice = model.notice {
                HStack(spacing: 6) {
                    Image(systemName: notice.icon).foregroundStyle(model.accent).accessibilityHidden(true)
                    Text(model.t(notice.text)).lineLimit(1).minimumScaleFactor(0.85)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: PanelMetrics.noticeHeight)
            }
        }
    }
}

/// A timer's icon left of the notch and its time right of it.
private struct LiveTimerStrip: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore
    let timer: LiveTimer

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: timer.icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(model.accent).accessibilityHidden(true)
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(WidgetFormat.duration(widgets.liveTime(timer, at: context.date), roundingUp: timer.kind != .stopwatch))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
        }
        .padding(.horizontal, 10)
        .frame(height: model.islandHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timer.kind.title(model))
    }
}
