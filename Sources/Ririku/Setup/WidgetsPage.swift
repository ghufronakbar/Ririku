import AppKit
import SwiftUI
import UniformTypeIdentifiers
import RirikuCore

/// Settings of the local widgets (R-UI-1). The panel only operates them: start a timer, count, open an app.
struct WidgetsPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var widgets: WidgetStore
    @State private var availableShortcuts: [String]?
    @State private var bookmarkTitle = ""
    @State private var bookmarkAddress = ""
    @State private var bookmarkError: UIText?
    @State private var confirmClearNote = false

    var body: some View {
        let data = widgets.data
        Form {
            Section {
                Text(model.t("Choose which widgets the panel shows, and on which page, in Setup → Layout. These settings apply wherever the widget is."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(model.t("Play a sound when a timer ends"), isOn: binding(\.timerSound))
            }
            Section { pomodoro(data) } header: { header(.pomodoro) }
            Section {
                let countdown = data.countdown
                let fresh = !countdown.clock.isRunning && countdown.clock.accumulated == 0
                minutesStepper(model.t("Length"), value: Int(countdown.duration / 60), range: 1...1439) { minutes in
                    widgets.update { $0.countdown.duration = TimeInterval(minutes * 60) }
                }
                .disabled(!fresh)
                if !fresh {
                    Text(model.t("Reset the countdown in the panel to change its length.")).font(.caption).foregroundStyle(.secondary)
                }
            } header: { header(.countdown) }
            Section {
                TextField(model.t("Title"), text: textBinding(\.counter.title), prompt: Text(model.t("Counter")))
                LabeledContent(model.t("Value"), value: data.counter.value.formatted(.number.locale(model.locale)))
                Button(model.t("Reset")) { widgets.resetCounter() }.disabled(data.counter.value == 0)
            } header: { header(.counter) }
            Section { daysLeft(data) } header: { header(.daysLeft) }
            Section {
                Stepper(model.t("Daily goal: %@ glasses", data.water.goal.formatted(.number.locale(model.locale))),
                        value: Binding(get: { data.water.goal }, set: { goal in widgets.update { $0.water.goal = goal } }),
                        in: WaterState.goalRange)
                Text(model.t("The count starts again at zero every day.")).font(.caption).foregroundStyle(.secondary)
            } header: { header(.water) }
            Section {
                Toggle(model.t("Show a notice when charging starts"), isOn: binding(\.chargingNotice))
                Text(model.t("Shown for a few seconds in the compact island while the Battery widget is on a page."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: { header(.battery) }
            Section { apps(data) } header: { header(.apps) }
            Section { shortcuts(data) } header: { header(.shortcuts) }
            Section { bookmarks(data) } header: { header(.bookmarks) }
            Section {
                Text(model.t("The note is saved on this Mac as you type in the panel."))
                    .font(.caption).foregroundStyle(.secondary)
                Button(model.t("Clear Note…"), role: .destructive) { confirmClearNote = true }
                    .disabled(widgets.notes.isEmpty)
                    .confirmationDialog(model.t("Clear the note?"), isPresented: $confirmClearNote) {
                        Button(model.t("Clear Note"), role: .destructive) { widgets.notes = "" }
                    } message: { Text(model.t("This cannot be undone.")) }
            } header: { header(.notes) }
        }
        .task { availableShortcuts = await WidgetStore.availableShortcuts() }
    }

    // MARK: Sections

    @ViewBuilder
    private func pomodoro(_ data: WidgetData) -> some View {
        let settings = data.pomodoro
        minutesStepper(model.t("Focus"), value: settings.focusMinutes, range: PomodoroSettings.minuteRange) { value in
            widgets.update { $0.pomodoro.focusMinutes = value }
        }
        minutesStepper(model.t("Short Break"), value: settings.shortBreakMinutes, range: PomodoroSettings.minuteRange) { value in
            widgets.update { $0.pomodoro.shortBreakMinutes = value }
        }
        minutesStepper(model.t("Long Break"), value: settings.longBreakMinutes, range: PomodoroSettings.minuteRange) { value in
            widgets.update { $0.pomodoro.longBreakMinutes = value }
        }
        Stepper(model.t("Long break after %@ focus sessions", settings.roundsBeforeLongBreak.formatted(.number.locale(model.locale))),
                value: Binding(get: { settings.roundsBeforeLongBreak }, set: { rounds in widgets.update { $0.pomodoro.roundsBeforeLongBreak = rounds } }),
                in: PomodoroSettings.roundRange)
        Toggle(model.t("Start the next phase automatically"), isOn: binding(\.pomodoro.startsNextPhase))
    }

    @ViewBuilder
    private func daysLeft(_ data: WidgetData) -> some View {
        TextField(model.t("Title"), text: textBinding(\.daysLeft.title), prompt: Text(model.t("Days Left")))
        if let target = data.daysLeft.target {
            DatePicker(model.t("Date"), selection: Binding(get: { target }, set: { date in widgets.update { $0.daysLeft.target = date } }),
                       displayedComponents: .date)
            Button(model.t("Remove Date")) { widgets.update { $0.daysLeft.target = nil } }
        } else {
            Button(model.t("Choose a Date")) {
                let inThirtyDays = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                widgets.update { $0.daysLeft.target = Calendar.autoupdatingCurrent.startOfDay(for: inThirtyDays) }
            }
        }
        Text(model.t("Counts the days until the date, or since it once it has passed."))
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func apps(_ data: WidgetData) -> some View {
        ForEach(data.apps) { app in
            HStack {
                Image(nsImage: NSWorkspace.shared.icon(forFile: widgets.appURL(app).path)).resizable().frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(app.name)
                Spacer()
                Button { widgets.removeApp(app) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless).accessibilityLabel(model.t("Remove %@", app.name))
            }
        }
        Button(model.t("Add Apps…")) { chooseApps() }
            .disabled(data.apps.count >= WidgetData.maximumItems)
    }

    @ViewBuilder
    private func shortcuts(_ data: WidgetData) -> some View {
        let names = Array(Set((availableShortcuts ?? []) + data.shortcuts)).sorted()
        if availableShortcuts == nil {
            Text(model.t("Reading your shortcuts…")).font(.caption).foregroundStyle(.secondary)
        } else if names.isEmpty {
            Text(model.t("No shortcuts found. Create them in the Shortcuts app.")).font(.caption).foregroundStyle(.secondary)
        }
        ForEach(names, id: \.self) { name in
            Toggle(name, isOn: Binding(get: { data.shortcuts.contains(name) }, set: { widgets.setShortcut(name, enabled: $0) }))
                .disabled(!data.shortcuts.contains(name) && data.shortcuts.count >= WidgetData.maximumItems)
        }
        Text(model.t("The widget runs only the shortcuts you turn on here."))
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func bookmarks(_ data: WidgetData) -> some View {
        ForEach(data.bookmarks) { bookmark in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title)
                    Text(bookmark.url).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Menu {
                    Button(model.t("Move Up")) { widgets.moveBookmark(bookmark, by: -1) }.disabled(data.bookmarks.first == bookmark)
                    Button(model.t("Move Down")) { widgets.moveBookmark(bookmark, by: 1) }.disabled(data.bookmarks.last == bookmark)
                    Divider()
                    Button(model.t("Remove"), role: .destructive) { widgets.removeBookmark(bookmark) }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel(model.t("Bookmark actions"))
            }
        }
        TextField(model.t("Title"), text: $bookmarkTitle, prompt: Text(model.t("Optional")))
        HStack {
            TextField(model.t("Address"), text: $bookmarkAddress, prompt: Text(verbatim: "https://"))
                .onSubmit { addBookmark() }
            Button(model.t("Add")) { addBookmark() }
                .disabled(bookmarkAddress.trimmingCharacters(in: .whitespaces).isEmpty || data.bookmarks.count >= WidgetData.maximumItems)
        }
        if let bookmarkError { Text(model.t(bookmarkError)).font(.caption).foregroundStyle(.orange) }
        Text(model.t("Bookmarks open in your default browser."))
            .font(.caption).foregroundStyle(.secondary)
    }

    // MARK: Helpers

    private func header(_ kind: WidgetKind) -> some View {
        Label(kind.title(model), systemImage: kind.icon)
    }

    private func minutesStepper(_ title: String, value: Int, range: ClosedRange<Int>, set: @escaping (Int) -> Void) -> some View {
        Stepper(value: Binding(get: { value }, set: set), in: range) {
            LabeledContent(title, value: model.t("%@ min", value.formatted(.number.locale(model.locale))))
        }
    }

    private func binding(_ path: WritableKeyPath<WidgetData, Bool>) -> Binding<Bool> {
        Binding(get: { widgets.data[keyPath: path] }, set: { value in widgets.update { $0[keyPath: path] = value } })
    }

    private func textBinding(_ path: WritableKeyPath<WidgetData, String>) -> Binding<String> {
        Binding(get: { widgets.data[keyPath: path] },
                set: { value in widgets.update { $0[keyPath: path] = String(value.prefix(WidgetData.maximumTitleLength)) } })
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = model.t("Choose apps for the Apps widget.")
        guard panel.runModal() == .OK else { return }
        widgets.addApps(panel.urls)
    }

    private func addBookmark() {
        guard let bookmark = Bookmark.validated(title: bookmarkTitle, address: bookmarkAddress) else {
            bookmarkError = UIText("Enter a web address, such as https://example.com.")
            return
        }
        widgets.addBookmark(bookmark)
        bookmarkTitle = ""
        bookmarkAddress = ""
        bookmarkError = nil
    }
}
