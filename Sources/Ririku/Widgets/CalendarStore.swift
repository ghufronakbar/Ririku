import AppKit
import EventKit
import SwiftUI
import RirikuCore

/// Reads events for the Calendar widget (D-020). It only reads: it never creates, changes, or deletes events
/// (R-WID-8). Access is asked for when the widget is added (R-WID-3). Events are read only while a Calendar widget
/// is visible: when it appears, when the calendars change, and when an event starts or ends (R-WID-4).
@MainActor
final class CalendarStore: ObservableObject {
    struct CalendarInfo: Identifiable, Equatable {
        let id: String
        let title: String
        let source: String
        let color: Color
    }

    @Published private(set) var access: PermissionState
    @Published private(set) var agenda: Agenda?
    @Published private(set) var calendars: [CalendarInfo] = []
    /// Calendars the user turned off in Setup. Stored this way so that new calendars show up by default.
    @Published private(set) var hiddenCalendars: Set<String>

    private let defaults: UserDefaults
    private let status: () -> PermissionState
    private let requester: (() async -> Bool)?
    private var store: EKEventStore?
    private var requesting = false
    private var viewers = 0
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    var calendar = Calendar.autoupdatingCurrent

    /// `status` and `requester` replace the system's in tests, which must not show the permission prompt.
    init(defaults: UserDefaults, status: (() -> PermissionState)? = nil, requester: (() async -> Bool)? = nil) {
        self.defaults = defaults
        self.status = status ?? Self.systemStatus
        self.requester = requester
        hiddenCalendars = Set(defaults.stringArray(forKey: "hiddenCalendars") ?? [])
        access = self.status()
    }

    private static func systemStatus() -> PermissionState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    /// Reads the access again, because it can change in System Settings at any time.
    func refreshAccess() {
        let current = status()
        // A store made before access was granted does not see the events, so a new one is made.
        if current != access, current == .granted { store = nil }
        access = current
    }

    /// Shows the system prompt if the user has never answered it. Never asks again after an answer (R-WID-3).
    @discardableResult
    func requestAccessIfNeeded() -> Task<Void, Never>? {
        refreshAccess()
        guard access == .notDetermined, !requesting else { return nil }
        requesting = true
        return Task {
            if let requester {
                _ = await requester()
            } else {
                let store = EKEventStore()
                if (try? await store.requestFullAccessToEvents()) == true { self.store = store }
            }
            requesting = false
            refreshAccess()
            if viewers > 0 { reload() } else { loadCalendars() }
        }
    }

    // MARK: Visible widgets

    func start() {
        viewers += 1
        guard viewers == 1 else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    func stop() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        timer?.invalidate()
        timer = nil
    }

    private func eventStore() -> EKEventStore? {
        guard access == .granted else { return nil }
        if store == nil { store = EKEventStore() }
        return store
    }

    /// Lists the calendars for Setup, without reading events.
    func loadCalendars() {
        refreshAccess()
        guard let store = eventStore() else {
            calendars = []
            return
        }
        calendars = store.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, source: $0.source?.title ?? "", color: Color(cgColor: $0.cgColor)) }
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    private func reload(now: Date = Date()) {
        timer?.invalidate()
        timer = nil
        loadCalendars()
        guard let store = eventStore() else {
            agenda = nil
            return
        }
        let shown = store.calendars(for: .event).filter { !hiddenCalendars.contains($0.calendarIdentifier) }
        let range = Agenda.fetchRange(now: now, calendar: calendar)
        // An empty list would mean every calendar to EventKit.
        let found = shown.isEmpty ? [] : store.events(matching: store.predicateForEvents(withStart: range.start, end: range.end, calendars: shown))
        let events = found.map { event in
            AgendaEvent(id: event.calendarItemIdentifier + "@" + String(event.startDate.timeIntervalSinceReferenceDate),
                        title: event.title ?? "", start: event.startDate, end: event.endDate, allDay: event.isAllDay,
                        calendarID: event.calendar?.calendarIdentifier ?? "")
        }
        agenda = Agenda.make(from: events, now: now, calendar: calendar)
        let next = Agenda.nextChange(after: now, events: events, calendar: calendar)
        let timer = Timer(fire: next.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func color(of event: AgendaEvent) -> Color {
        calendars.first { $0.id == event.calendarID }?.color ?? .white
    }

    func setCalendar(_ id: String, shown: Bool) {
        if shown { hiddenCalendars.remove(id) } else { hiddenCalendars.insert(id) }
        defaults.set(hiddenCalendars.sorted(), forKey: "hiddenCalendars")
        if viewers > 0 { reload() }
    }

    func openCalendarApp() {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
