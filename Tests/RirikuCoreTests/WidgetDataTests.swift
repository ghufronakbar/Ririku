import Foundation
import Testing
@testable import RirikuCore

private let start = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("Widget timers")
struct WidgetTimerTests {
    @Test("A clock counts while running and keeps its time while paused")
    func countsAndPauses() {
        var clock = TimerClock()
        clock.start(at: start)
        #expect(clock.elapsed(at: start.addingTimeInterval(30)) == 30)
        clock.pause(at: start.addingTimeInterval(30))
        #expect(!clock.isRunning)
        #expect(clock.elapsed(at: start.addingTimeInterval(500)) == 30, "a paused clock does not count")
        clock.start(at: start.addingTimeInterval(100))
        clock.start(at: start.addingTimeInterval(200))
        #expect(clock.elapsed(at: start.addingTimeInterval(110)) == 40, "starting again does not restart the run")
        clock.reset()
        #expect(clock.elapsed(at: start.addingTimeInterval(110)) == 0)
    }

    @Test("Pomodoro moves through focus and breaks, with a long break after enough sessions")
    func advancesPomodoro() {
        var settings = PomodoroSettings()
        settings.roundsBeforeLongBreak = 2
        var state = PomodoroState()
        state.clock.start(at: start)
        #expect(state.endDate(settings: settings) == start.addingTimeInterval(25 * 60))
        #expect(state.remaining(at: start.addingTimeInterval(60), settings: settings) == 24 * 60)
        state.advance(settings: settings)
        #expect(state.phase == .shortBreak)
        #expect(!state.clock.isRunning, "the next phase waits to be started")
        state.advance(settings: settings)
        #expect(state.phase == .focus)
        state.advance(settings: settings)
        #expect(state.phase == .longBreak)
        #expect(state.roundsDone(settings: settings) == 2)
        state.advance(settings: settings)
        #expect(state.phase == .focus)
        #expect(state.completedFocus == 0, "a long break starts a new cycle")
    }

    @Test("A countdown ends at its length and changes length only before it starts")
    func countsDown() {
        var countdown = CountdownState()
        countdown.adjust(minutes: 5)
        #expect(countdown.duration == 15 * 60)
        countdown.adjust(minutes: -100)
        #expect(countdown.duration == 60, "at least one minute")
        countdown.clock.start(at: start)
        #expect(countdown.endDate == start.addingTimeInterval(60))
        #expect(countdown.remaining(at: start.addingTimeInterval(90)) == 0)
        countdown.adjust(minutes: 5)
        #expect(countdown.duration == 60, "a running countdown keeps its length")
    }
}

@Suite("Widget values")
struct WidgetValueTests {
    @Test("Water starts again at zero on another day")
    func countsWaterPerDay() {
        var water = WaterState()
        water.add(3, today: "2026-10-05")
        #expect(water.count(today: "2026-10-05") == 3)
        #expect(water.count(today: "2026-10-06") == 0)
        water.add(-1, today: "2026-10-06")
        #expect(water.count(today: "2026-10-06") == 0, "never below zero")
    }

    @Test("Counts calendar days, not 24-hour periods")
    func countsDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 23))!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 1))!
        #expect(CalendarDays.between(evening, morning, calendar: calendar) == 1)
        #expect(CalendarDays.between(morning, evening, calendar: calendar) == -1)
        #expect(CalendarDays.between(evening, evening, calendar: calendar) == 0)
        #expect(CalendarDays.key(for: evening, calendar: calendar) == "2026-10-05")
    }

    @Test("Bookmarks accept web addresses only")
    func validatesBookmarks() {
        let plain = Bookmark.validated(title: "", address: "example.com/path")
        #expect(plain?.url == "https://example.com/path")
        #expect(plain?.title == "example.com", "the host names a bookmark without a title")
        #expect(Bookmark.validated(title: " Docs ", address: "http://example.com")?.title == "Docs")
        #expect(Bookmark.validated(title: "", address: "javascript:alert(1)") == nil)
        #expect(Bookmark.validated(title: "", address: "file:///etc/passwd") == nil)
        #expect(Bookmark.validated(title: "", address: "https://") == nil)
        #expect(Bookmark.validated(title: String(repeating: "x", count: 99), address: "https://a.b")?.title.count == WidgetData.maximumTitleLength)
    }

    @Test("Network rates add each interface's difference, across counter wraps")
    func measuresNetwork() {
        let old = ["en0": NetworkStats.Counters(received: UInt32.max - 99, sent: 1000), "en1": .init(received: 0, sent: 0)]
        let new = ["en0": NetworkStats.Counters(received: 100, sent: 3000), "en5": .init(received: 9999, sent: 9999)]
        let rates = NetworkStats.rates(from: old, to: new, seconds: 2)
        #expect(rates?.received == 100, "200 bytes after a wrap, over 2 seconds")
        #expect(rates?.sent == 1000)
        #expect(NetworkStats.rates(from: old, to: new, seconds: 0) == nil)
    }
}

@Suite("Widget data storage")
struct WidgetDataStorageTests {
    @Test("Keeps defaults for missing fields and limits values that are out of range")
    func decodesTolerantly() throws {
        let json = """
        {"pomodoro": {"focusMinutes": 0, "roundsBeforeLongBreak": 99}, "countdown": {"duration": 5},
         "water": {"goal": 500, "count": -3}, "counter": {"value": "many"},
         "apps": [{"path": "/Applications/Music.app", "name": "Music"}, {"name": "broken"}],
         "bookmarks": [{"id": "1", "title": "Bad", "url": "javascript:x"}, {"id": "2", "title": "Good", "url": "https://example.com"}],
         "shortcuts": ["", "Morning"], "future": true}
        """
        let data = try JSONDecoder().decode(WidgetData.self, from: Data(json.utf8))
        #expect(data.pomodoro.focusMinutes == 1)
        #expect(data.pomodoro.shortBreakMinutes == 5)
        #expect(data.pomodoro.roundsBeforeLongBreak == 8)
        #expect(data.countdown.duration == 60)
        #expect(data.water.goal == 20)
        #expect(data.water.count == 0)
        #expect(data.counter.value == 0, "an unreadable value keeps the default")
        #expect(data.apps.map(\.name) == ["Music"])
        #expect(data.bookmarks.map(\.title) == ["Good"])
        #expect(data.shortcuts == ["Morning"])
        #expect(data.timerSound)
    }

    @Test("Survives a round trip and keeps at most twelve items per list")
    func roundTrips() throws {
        var data = WidgetData()
        data.counter.value = 7
        data.daysLeft.target = start
        data.bookmarks = (0..<20).map { Bookmark(title: "\($0)", url: "https://example.com/\($0)") }
        let decoded = try JSONDecoder().decode(WidgetData.self, from: JSONEncoder().encode(data))
        #expect(decoded.counter.value == 7)
        #expect(decoded.daysLeft.target == start)
        #expect(decoded.bookmarks.count == WidgetData.maximumItems)
    }
}
