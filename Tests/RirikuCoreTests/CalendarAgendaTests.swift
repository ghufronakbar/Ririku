import Foundation
import Testing
@testable import RirikuCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
    return calendar
}()

/// 2026-10-05 at the given time in Jakarta.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 5) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}

private func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false) -> AgendaEvent {
    AgendaEvent(id: id, title: id, start: start, end: end, allDay: allDay, calendarID: "work")
}

@Suite("Calendar agenda")
struct CalendarAgendaTests {
    @Test("Today shows events that have not ended, timed ones first, then all-day ones")
    func showsRemainingEvents() {
        let events = [
            event("birthday", at(0), at(0, day: 6), allDay: true),
            event("lunch", at(12), at(13)),
            event("standup", at(9), at(9, 15)),
            event("review", at(10), at(11))
        ]
        let agenda = Agenda.make(from: events, now: at(10, 30), calendar: calendar)
        #expect(agenda.day == .today)
        #expect(agenda.events.map(\.id) == ["review", "lunch", "birthday"], "the standup has ended; the review is ongoing")
        #expect(agenda.events[0].isOngoing(at: at(10, 30)))
        #expect(!agenda.events[1].isOngoing(at: at(10, 30)))
    }

    @Test("Once today has nothing left, tomorrow's events are shown")
    func fallsBackToTomorrow() {
        let events = [
            event("done", at(9), at(10)),
            event("tomorrow", at(9, day: 6), at(10, day: 6)),
            event("later", at(9, day: 7), at(10, day: 7))
        ]
        let agenda = Agenda.make(from: events, now: at(20), calendar: calendar)
        #expect(agenda.day == .tomorrow)
        #expect(agenda.events.map(\.id) == ["tomorrow"], "only tomorrow, not the day after")
    }

    @Test("Without events today or tomorrow, the agenda is today's and empty")
    func emptyAgenda() {
        let agenda = Agenda.make(from: [event("done", at(9), at(10))], now: at(20), calendar: calendar)
        #expect(agenda == Agenda(day: .today, events: []))
    }

    @Test("Events from yesterday that run into today, and events without a duration, are included")
    func includesEdgeEvents() {
        let events = [
            event("night shift", at(22, day: 4), at(6)),
            event("reminder", at(8), at(8)),
            event("past reminder", at(5), at(5))
        ]
        let agenda = Agenda.make(from: events, now: at(5, 30), calendar: calendar)
        #expect(agenda.events.map(\.id) == ["night shift", "reminder"])
    }

    @Test("The agenda changes next when an event starts or ends, or at midnight")
    func nextChange() {
        let events = [event("review", at(10), at(11)), event("lunch", at(12), at(13))]
        #expect(Agenda.nextChange(after: at(9), events: events, calendar: calendar) == at(10))
        #expect(Agenda.nextChange(after: at(10, 30), events: events, calendar: calendar) == at(11))
        #expect(Agenda.nextChange(after: at(14), events: events, calendar: calendar) == at(0, day: 6))
        #expect(Agenda.nextChange(after: at(9), events: [event("tomorrow", at(9, day: 6), at(10, day: 6))], calendar: calendar)
            == at(0, day: 6), "nothing waits past midnight, when the day changes")
    }

    @Test("Events are read from the start of today to the end of tomorrow")
    func fetchRange() {
        let range = Agenda.fetchRange(now: at(15), calendar: calendar)
        #expect(range.start == at(0))
        #expect(range.end == at(0, day: 7))
    }
}
