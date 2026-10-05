import Foundation

/// A calendar event as the Calendar widget shows it, read from EventKit. Ririku never changes events (R-WID-8)
/// and never logs them (R-SEC-6).
public struct AgendaEvent: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var allDay: Bool
    public var calendarID: String

    public init(id: String, title: String, start: Date, end: Date, allDay: Bool, calendarID: String) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.allDay = allDay
        self.calendarID = calendarID
    }

    public func isOngoing(at now: Date) -> Bool { start <= now && now < end }

    /// Whether the event takes place between `from` and `to`. An event without a duration counts at its start.
    func overlaps(from: Date, to: Date) -> Bool { start < to && (end > from || start >= from) }
}

/// What the Calendar widget shows: today's events that have not ended, or tomorrow's once today has none left.
public struct Agenda: Equatable, Sendable {
    public enum Day: Sendable { case today, tomorrow }

    public var day: Day
    public var events: [AgendaEvent]

    public init(day: Day, events: [AgendaEvent]) {
        self.day = day
        self.events = events
    }

    /// The span to read from the calendars: from the start of today to the end of tomorrow.
    public static func fetchRange(now: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: now)
        return (today, calendar.date(byAdding: .day, value: 2, to: today) ?? today.addingTimeInterval(2 * 86_400))
    }

    /// Timed events come first, in order of their start, then all-day events, so the next meeting is not pushed
    /// out of a small widget by a birthday.
    public static func make(from events: [AgendaEvent], now: Date, calendar: Calendar) -> Agenda {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let dayAfter = calendar.date(byAdding: .day, value: 1, to: tomorrow) ?? tomorrow.addingTimeInterval(86_400)
        let remaining = events.filter { $0.overlaps(from: now, to: tomorrow) }
        if !remaining.isEmpty { return Agenda(day: .today, events: sorted(remaining)) }
        let next = events.filter { $0.overlaps(from: tomorrow, to: dayAfter) }
        return Agenda(day: next.isEmpty ? .today : .tomorrow, events: sorted(next))
    }

    /// When the agenda changes without the calendars changing: the next start or end of an event, or midnight.
    public static func nextChange(after now: Date, events: [AgendaEvent], calendar: Calendar) -> Date {
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        let moments = events.flatMap { [$0.start, $0.end] }.filter { $0 > now }
        return min(moments.min() ?? midnight, midnight)
    }

    private static func sorted(_ events: [AgendaEvent]) -> [AgendaEvent] {
        events.sorted { first, second in
            if first.allDay != second.allDay { return !first.allDay }
            if first.start != second.start { return first.start < second.start }
            if first.title != second.title { return first.title < second.title }
            return first.id < second.id
        }
    }
}
