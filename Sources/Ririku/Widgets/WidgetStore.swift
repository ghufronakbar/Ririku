import AppKit
import RirikuCore

/// The running timer the compact island shows while no music plays (R-WID-1).
struct LiveTimer: Equatable {
    let kind: WidgetKind
    let icon: String
}

/// State and actions of the local widgets: timers, the counter, water, the target date, notes, and the apps,
/// shortcuts, and bookmarks the user picked. A running timer only schedules its end (R-WID-4).
@MainActor
final class WidgetStore: ObservableObject {
    static let maximumNotesLength = 10_000

    @Published private(set) var data: WidgetData
    /// Kept apart from `data` because it changes with every key press. Never logged (R-SEC-6).
    @Published var notes: String {
        didSet {
            if notes.count > Self.maximumNotesLength { notes = String(notes.prefix(Self.maximumNotesLength)) }
            saveNotesSoon()
        }
    }
    /// Shows a short notice in the compact island, such as a finished timer (D-021).
    var notice: ((UIText, String) -> Void)?
    /// Called when what the compact island shows may change.
    var changed: (() -> Void)?

    private let defaults: UserDefaults
    private var endTimers: [WidgetKind: Timer] = [:]
    private var notesSave: DispatchWorkItem?
    var calendar = Calendar.autoupdatingCurrent

    init(defaults: UserDefaults, now: Date = Date()) {
        self.defaults = defaults
        data = defaults.data(forKey: "widgetData").flatMap { try? JSONDecoder().decode(WidgetData.self, from: $0) } ?? WidgetData()
        notes = String((defaults.string(forKey: "widgetNotes") ?? "").prefix(Self.maximumNotesLength))
        // Timers that ended while Ririku was closed settle quietly; the others wait for their end again.
        finishDueTimers(now: now, announce: false)
        scheduleEnds(now: now)
    }

    func update(_ change: (inout WidgetData) -> Void) {
        var edited = data
        change(&edited)
        data = edited
        defaults.set(try? JSONEncoder().encode(data), forKey: "widgetData")
        changed?()
    }

    private func saveNotesSoon() {
        notesSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.defaults.set(self.notes, forKey: "widgetNotes")
        }
        notesSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Writes a pending note at once, for example when the app quits.
    func flushNotes() {
        notesSave?.perform()
        notesSave = nil
    }

    // MARK: Timers

    func togglePomodoro(now: Date = Date()) {
        update { $0.pomodoroState.clock.isRunning ? $0.pomodoroState.clock.pause(at: now) : $0.pomodoroState.clock.start(at: now) }
        scheduleEnds(now: now)
    }

    func resetPomodoro() {
        update { $0.pomodoroState.clock.reset() }
        scheduleEnds(now: Date())
    }

    /// Ends the current phase early and moves to the next one, which waits to be started.
    func skipPomodoro() {
        update { $0.pomodoroState.advance(settings: $0.pomodoro) }
        scheduleEnds(now: Date())
    }

    func toggleCountdown(now: Date = Date()) {
        update { data in
            if data.countdown.clock.isRunning { data.countdown.clock.pause(at: now) }
            else {
                if data.countdown.remaining(at: now) == 0 { data.countdown.clock.reset() }
                data.countdown.clock.start(at: now)
            }
        }
        scheduleEnds(now: now)
    }

    func resetCountdown() {
        update { $0.countdown.clock.reset() }
        scheduleEnds(now: Date())
    }

    func adjustCountdown(minutes: Int) { update { $0.countdown.adjust(minutes: minutes) } }

    func toggleStopwatch(now: Date = Date()) {
        update { $0.stopwatch.isRunning ? $0.stopwatch.pause(at: now) : $0.stopwatch.start(at: now) }
    }

    func resetStopwatch() { update { $0.stopwatch.reset() } }

    /// Settles timers whose end has passed, then announces them with a notice and an optional sound.
    func finishDueTimers(now: Date = Date(), announce: Bool = true) {
        var finished: [(UIText, String)] = []
        var edited = data
        if let end = edited.countdown.endDate, end <= now {
            edited.countdown.clock = TimerClock(accumulated: edited.countdown.duration)
            finished.append((UIText("Countdown finished"), "timer"))
        }
        if let end = edited.pomodoroState.endDate(settings: edited.pomodoro), end <= now {
            let wasFocus = edited.pomodoroState.phase == .focus
            edited.pomodoroState.advance(settings: edited.pomodoro)
            if edited.pomodoro.startsNextPhase && announce { edited.pomodoroState.clock.start(at: now) }
            finished.append(wasFocus ? (UIText("Focus finished · time for a break"), "cup.and.saucer")
                                     : (UIText("Break finished · back to focus"), "brain.head.profile"))
        }
        guard !finished.isEmpty else { return }
        update { $0 = edited }
        guard announce else { return }
        for (text, icon) in finished { notice?(text, icon) }
        if data.timerSound { NSSound(named: "Glass")?.play() }
        scheduleEnds(now: now)
    }

    /// One timer per running countdown or Pomodoro phase, firing at its end.
    private func scheduleEnds(now: Date) {
        endTimers.values.forEach { $0.invalidate() }
        endTimers.removeAll()
        let ends: [(WidgetKind, Date?)] = [(.countdown, data.countdown.endDate), (.pomodoro, data.pomodoroState.endDate(settings: data.pomodoro))]
        for case let (kind, end?) in ends {
            let timer = Timer(fire: max(end, now), interval: 0, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.finishDueTimers() }
            }
            RunLoop.main.add(timer, forMode: .common)
            endTimers[kind] = timer
        }
    }

    /// The timer that ends first, otherwise a running stopwatch.
    var liveTimer: LiveTimer? {
        let ends: [(Date, LiveTimer)] = [
            data.countdown.endDate.map { ($0, LiveTimer(kind: .countdown, icon: "timer")) },
            data.pomodoroState.endDate(settings: data.pomodoro).map { ($0, LiveTimer(kind: .pomodoro, icon: "hourglass")) }
        ].compactMap { $0 }
        if let first = ends.min(by: { $0.0 < $1.0 }) { return first.1 }
        return data.stopwatch.isRunning ? LiveTimer(kind: .stopwatch, icon: "stopwatch") : nil
    }

    /// The time a live timer shows: remaining for countdowns and Pomodoro, elapsed for the stopwatch.
    func liveTime(_ timer: LiveTimer, at now: Date) -> TimeInterval {
        switch timer.kind {
        case .countdown: return data.countdown.remaining(at: now)
        case .pomodoro: return data.pomodoroState.remaining(at: now, settings: data.pomodoro)
        default: return data.stopwatch.elapsed(at: now)
        }
    }

    // MARK: Counter, water, and the target date

    func changeCounter(by delta: Int) { update { $0.counter.change(by: delta) } }

    func resetCounter() { update { $0.counter.value = 0 } }

    func changeWater(by delta: Int, now: Date = Date()) {
        let today = CalendarDays.key(for: now, calendar: calendar)
        update { $0.water.add(delta, today: today) }
    }

    func waterToday(now: Date = Date()) -> Int { data.water.count(today: CalendarDays.key(for: now, calendar: calendar)) }

    /// Days from today to the target date, or nil without one.
    func daysLeft(now: Date = Date()) -> Int? {
        data.daysLeft.target.map { CalendarDays.between(now, $0, calendar: calendar) }
    }

    // MARK: Apps, shortcuts, and bookmarks

    /// Adds apps chosen in an open panel; anything that is not an app bundle is ignored.
    func addApps(_ urls: [URL]) {
        let entries = urls.compactMap { url -> AppEntry? in
            guard url.pathExtension == "app", let bundle = Bundle(url: url) else { return nil }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            return AppEntry(path: url.path, bundleID: bundle.bundleIdentifier, name: name)
        }
        update { data in
            for entry in entries where !data.apps.contains(where: { $0.path == entry.path }) && data.apps.count < WidgetData.maximumItems {
                data.apps.append(entry)
            }
        }
    }

    func removeApp(_ entry: AppEntry) { update { $0.apps.removeAll { $0.path == entry.path } } }

    /// The app's current location: found by its bundle identifier if it moved, otherwise the stored path.
    func appURL(_ entry: AppEntry) -> URL {
        entry.bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) } ?? URL(fileURLWithPath: entry.path)
    }

    func launch(_ entry: AppEntry) {
        NSWorkspace.shared.openApplication(at: appURL(entry), configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard error != nil else { return }
            DispatchQueue.main.async { self?.notice?(UIText("Could not open %@", entry.name), "exclamationmark.triangle") }
        }
    }

    func setShortcut(_ name: String, enabled: Bool) {
        update { data in
            data.shortcuts.removeAll { $0 == name }
            if enabled && data.shortcuts.count < WidgetData.maximumItems { data.shortcuts.append(name) }
        }
    }

    /// Runs a shortcut the user picked through `/usr/bin/shortcuts` with an argument list, never a shell (R-WID-9).
    func runShortcut(_ name: String) {
        guard data.shortcuts.contains(name) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] finished in
            guard finished.terminationStatus != 0 else { return }
            DispatchQueue.main.async { self?.notice?(UIText("Shortcut “%@” failed", name), "exclamationmark.triangle") }
        }
        do { try process.run() } catch { notice?(UIText("Shortcut “%@” failed", name), "exclamationmark.triangle") }
    }

    /// The names from `shortcuts list`, read off the main thread.
    nonisolated static func availableShortcuts() async -> [String] {
        await Task.detached {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return [] }
            let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            process.waitUntilExit()
            return text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }.sorted()
        }.value
    }

    func addBookmark(_ bookmark: Bookmark) {
        update { data in
            if data.bookmarks.count < WidgetData.maximumItems { data.bookmarks.append(bookmark) }
        }
    }

    func removeBookmark(_ bookmark: Bookmark) { update { $0.bookmarks.removeAll { $0.id == bookmark.id } } }

    func moveBookmark(_ bookmark: Bookmark, by offset: Int) {
        update { data in
            guard let index = data.bookmarks.firstIndex(of: bookmark) else { return }
            let target = min(max(0, index + offset), data.bookmarks.count - 1)
            data.bookmarks.insert(data.bookmarks.remove(at: index), at: target)
        }
    }

    /// Opens the address in the default browser; Ririku shows no web content itself (R-WID-11).
    func open(_ bookmark: Bookmark) {
        guard bookmark.isValid, let url = URL(string: bookmark.url) else { return }
        NSWorkspace.shared.open(url)
    }
}
