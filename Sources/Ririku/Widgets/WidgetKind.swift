import SwiftUI
import RirikuCore

/// The widgets this version can show, in the order Setup lists them. The raw value is the `kind` stored in the layout.
enum WidgetKind: String, CaseIterable {
    case music, system, clock, pomodoro, countdown, stopwatch, network, battery
    case notes, counter, daysLeft, water, apps, shortcuts, bookmarks

    static let identifiers = Set(allCases.map(\.rawValue))

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .system: return "cpu"
        case .clock: return "clock"
        case .pomodoro: return "hourglass"
        case .countdown: return "timer"
        case .stopwatch: return "stopwatch"
        case .network: return "network"
        case .battery: return "battery.75percent"
        case .notes: return "note.text"
        case .counter: return "plus.forwardslash.minus"
        case .daysLeft: return "calendar.badge.clock"
        case .water: return "drop"
        case .apps: return "square.grid.3x3"
        case .shortcuts: return "command.square"
        case .bookmarks: return "bookmark"
        }
    }

    @MainActor
    func title(_ model: AppModel) -> String {
        switch self {
        case .music: return model.t("Music")
        case .system: return model.t("System")
        case .clock: return model.t("Clock")
        case .pomodoro: return model.t("Pomodoro")
        case .countdown: return model.t("Countdown")
        case .stopwatch: return model.t("Stopwatch")
        case .network: return model.t("Network")
        case .battery: return model.t("Battery")
        case .notes: return model.t("Notes")
        case .counter: return model.t("Counter")
        case .daysLeft: return model.t("Days Left")
        case .water: return model.t("Water")
        case .apps: return model.t("Apps")
        case .shortcuts: return model.t("Shortcuts")
        case .bookmarks: return model.t("Bookmarks")
        }
    }
}

/// Draws one widget of a page at the width the page gives it.
struct WidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel
    let slot: WidgetSlot
    let layout: ExpandedPanelLayout

    var body: some View {
        let wide = slot.wide
        let widgets = model.widgets
        switch WidgetKind(rawValue: slot.kind) {
        case .music:
            if wide {
                MusicWidgetView(model: model, music: music, lyricHeight: layout.lyricHeight, twoRows: layout.twoLyricRows)
            } else {
                MusicSmallWidgetView(model: model, music: music)
            }
        case .system: SystemWidgetView(model: model, monitor: model.system, wide: wide)
        case .clock: ClockWidgetView(model: model, wide: wide)
        case .pomodoro: PomodoroWidgetView(model: model, widgets: widgets, wide: wide)
        case .countdown: CountdownWidgetView(model: model, widgets: widgets, wide: wide)
        case .stopwatch: StopwatchWidgetView(model: model, widgets: widgets, wide: wide)
        case .network: NetworkWidgetView(model: model, monitor: model.network, wide: wide)
        case .battery: BatteryWidgetView(model: model, monitor: model.battery, wide: wide)
        case .notes: NotesWidgetView(model: model, widgets: widgets)
        case .counter: CounterWidgetView(model: model, widgets: widgets, wide: wide)
        case .daysLeft: DaysLeftWidgetView(model: model, widgets: widgets, wide: wide)
        case .water: WaterWidgetView(model: model, widgets: widgets, wide: wide)
        case .apps: AppsWidgetView(model: model, widgets: widgets)
        case .shortcuts: ShortcutsWidgetView(model: model, widgets: widgets)
        case .bookmarks: BookmarksWidgetView(model: model, widgets: widgets)
        case nil: EmptyView()
        }
    }
}
