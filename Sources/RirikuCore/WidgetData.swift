import Foundation

/// A clock that counts while running and keeps its time while paused. It stores dates instead of ticking,
/// so a running timer needs no work until it ends (R-WID-4) and survives the app quitting.
public struct TimerClock: Codable, Equatable, Sendable {
    /// Seconds counted before the current run.
    public var accumulated: TimeInterval
    /// When the current run started; nil while paused or stopped.
    public var startedAt: Date?

    public init(accumulated: TimeInterval = 0, startedAt: Date? = nil) {
        self.accumulated = accumulated
        self.startedAt = startedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accumulated = max(0, container.value(.accumulated, or: 0.0))
        startedAt = container.value(.startedAt, or: nil as Date?)
    }

    public var isRunning: Bool { startedAt != nil }

    public func elapsed(at now: Date) -> TimeInterval {
        accumulated + (startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    public mutating func start(at now: Date) {
        if startedAt == nil { startedAt = now }
    }

    public mutating func pause(at now: Date) {
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    public mutating func reset() {
        accumulated = 0
        startedAt = nil
    }
}

// MARK: Pomodoro

public enum PomodoroPhase: String, Codable, Sendable {
    case focus, shortBreak, longBreak
}

public struct PomodoroSettings: Codable, Equatable, Sendable {
    public static let minuteRange = 1...120
    public static let roundRange = 2...8

    public var focusMinutes = 25
    public var shortBreakMinutes = 5
    public var longBreakMinutes = 15
    public var roundsBeforeLongBreak = 4
    public var startsNextPhase = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let minutes = Self.minuteRange
        focusMinutes = container.value(.focusMinutes, or: 25).clamped(to: minutes)
        shortBreakMinutes = container.value(.shortBreakMinutes, or: 5).clamped(to: minutes)
        longBreakMinutes = container.value(.longBreakMinutes, or: 15).clamped(to: minutes)
        roundsBeforeLongBreak = container.value(.roundsBeforeLongBreak, or: 4).clamped(to: Self.roundRange)
        startsNextPhase = container.value(.startsNextPhase, or: false)
    }

    public func minutes(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }
}

public struct PomodoroState: Codable, Equatable, Sendable {
    public var phase = PomodoroPhase.focus
    /// Focus sessions finished since the last long break.
    public var completedFocus = 0
    public var clock = TimerClock()

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = container.value(.phase, or: .focus)
        completedFocus = max(0, container.value(.completedFocus, or: 0))
        clock = container.value(.clock, or: TimerClock())
    }

    public func duration(_ settings: PomodoroSettings) -> TimeInterval { TimeInterval(settings.minutes(for: phase) * 60) }

    public func remaining(at now: Date, settings: PomodoroSettings) -> TimeInterval {
        max(0, duration(settings) - clock.elapsed(at: now))
    }

    /// When the running phase ends; nil while paused.
    public func endDate(settings: PomodoroSettings) -> Date? {
        clock.startedAt.map { $0.addingTimeInterval(duration(settings) - clock.accumulated) }
    }

    /// Focus sessions to mark as done in the current cycle.
    public func roundsDone(settings: PomodoroSettings) -> Int { min(completedFocus, settings.roundsBeforeLongBreak) }

    /// Moves to the next phase after one ends or is skipped: a break after focus, a long one after enough
    /// focus sessions, and focus after a break.
    public mutating func advance(settings: PomodoroSettings) {
        switch phase {
        case .focus:
            completedFocus += 1
            phase = completedFocus >= settings.roundsBeforeLongBreak ? .longBreak : .shortBreak
        case .shortBreak:
            phase = .focus
        case .longBreak:
            completedFocus = 0
            phase = .focus
        }
        clock.reset()
    }
}

// MARK: Countdown, counter, days left, water

public struct CountdownState: Codable, Equatable, Sendable {
    /// One minute to 23 hours 59 minutes.
    public static let durationRange: ClosedRange<TimeInterval> = 60...86_340

    public var duration: TimeInterval = 600
    public var clock = TimerClock()

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        duration = container.value(.duration, or: 600.0).clamped(to: Self.durationRange)
        clock = container.value(.clock, or: TimerClock())
    }

    public func remaining(at now: Date) -> TimeInterval { max(0, duration - clock.elapsed(at: now)) }

    public var endDate: Date? { clock.startedAt.map { $0.addingTimeInterval(duration - clock.accumulated) } }

    /// Changes the duration while the countdown is stopped, in whole minutes.
    public mutating func adjust(minutes: Int) {
        guard !clock.isRunning, clock.accumulated == 0 else { return }
        duration = (duration + TimeInterval(minutes * 60)).clamped(to: Self.durationRange)
    }
}

public struct CounterState: Codable, Equatable, Sendable {
    public static let valueRange = -999_999...999_999

    public var title = ""
    public var value = 0

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = String(container.value(.title, or: "").prefix(WidgetData.maximumTitleLength))
        value = container.value(.value, or: 0).clamped(to: Self.valueRange)
    }

    public mutating func change(by delta: Int) { value = (value + delta).clamped(to: Self.valueRange) }
}

public struct DaysLeftState: Codable, Equatable, Sendable {
    public var title = ""
    public var target: Date?

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = String(container.value(.title, or: "").prefix(WidgetData.maximumTitleLength))
        target = container.value(.target, or: nil as Date?)
    }
}

public struct WaterState: Codable, Equatable, Sendable {
    public static let goalRange = 1...20

    public var goal = 8
    /// Glasses on `day`; another day starts again at zero.
    public var count = 0
    public var day = ""

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = container.value(.goal, or: 8).clamped(to: Self.goalRange)
        count = container.value(.count, or: 0).clamped(to: 0...99)
        day = container.value(.day, or: "")
    }

    public func count(today: String) -> Int { day == today ? count : 0 }

    public mutating func add(_ delta: Int, today: String) {
        count = (count(today: today) + delta).clamped(to: 0...99)
        day = today
    }
}

// MARK: Launchers

/// An app the user picked for the Apps widget.
public struct AppEntry: Codable, Equatable, Identifiable, Sendable {
    public var path: String
    public var bundleID: String?
    public var name: String
    public var id: String { path }

    public init(path: String, bundleID: String?, name: String) {
        self.path = path
        self.bundleID = bundleID
        self.name = name
    }
}

/// A web address for the Bookmarks widget, opened in the default browser (R-WID-11).
public struct Bookmark: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var url: String

    public init(id: String = UUID().uuidString, title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }

    /// A bookmark for an `http` or `https` address with a host, titled with the host when no title is given.
    public static func validated(title: String, address: String) -> Bookmark? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard withScheme.count <= 2048, let url = URL(string: withScheme), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), let host = url.host, !host.isEmpty else { return nil }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return Bookmark(title: String((name.isEmpty ? host : name).prefix(WidgetData.maximumTitleLength)), url: url.absoluteString)
    }

    public var isValid: Bool { Bookmark.validated(title: title, address: url) != nil }
}

// MARK: All widget data

/// What the local widgets remember: timer durations and runs, the counter, the target date, water, and the
/// apps, shortcuts, and bookmarks the user picked. Stored as versioned JSON; a missing or unreadable field keeps
/// its default instead of failing the rest (R-COMPAT-3).
public struct WidgetData: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let maximumItems = 12
    public static let maximumTitleLength = 40

    public var version = WidgetData.currentVersion
    public var timerSound = true
    public var pomodoro = PomodoroSettings()
    public var pomodoroState = PomodoroState()
    public var countdown = CountdownState()
    public var stopwatch = TimerClock()
    public var counter = CounterState()
    public var daysLeft = DaysLeftState()
    public var water = WaterState()
    public var chargingNotice = true
    public var apps: [AppEntry] = []
    public var shortcuts: [String] = []
    public var bookmarks: [Bookmark] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = container.value(.version, or: 1)
        timerSound = container.value(.timerSound, or: true)
        pomodoro = container.value(.pomodoro, or: PomodoroSettings())
        pomodoroState = container.value(.pomodoroState, or: PomodoroState())
        countdown = container.value(.countdown, or: CountdownState())
        stopwatch = container.value(.stopwatch, or: TimerClock())
        counter = container.value(.counter, or: CounterState())
        daysLeft = container.value(.daysLeft, or: DaysLeftState())
        water = container.value(.water, or: WaterState())
        chargingNotice = container.value(.chargingNotice, or: true)
        apps = Array((container.elements(.apps) as [AppEntry]).prefix(Self.maximumItems))
        shortcuts = Array((container.elements(.shortcuts) as [String]).filter { !$0.isEmpty }.prefix(Self.maximumItems))
        bookmarks = Array((container.elements(.bookmarks) as [Bookmark]).filter(\.isValid).prefix(Self.maximumItems))
    }
}

// MARK: Calendar days and network rates

public enum CalendarDays {
    /// "2026-10-05" for the day `date` falls on, used to start the water count again each day.
    public static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Whole calendar days from `start` to `end`: 0 on the same day, negative when `end` is earlier.
    public static func between(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }
}

public enum NetworkStats {
    /// Bytes received and sent by one network interface since it came up.
    public struct Counters: Equatable, Sendable {
        public var received: UInt32
        public var sent: UInt32

        public init(received: UInt32, sent: UInt32) {
            self.received = received
            self.sent = sent
        }
    }

    /// Bytes per second received and sent between two samples, for the interfaces present in both.
    /// The counters are 32-bit, so each interface's difference uses wrapping subtraction before they are added.
    public static func rates(from old: [String: Counters], to new: [String: Counters], seconds: Double) -> (received: Double, sent: Double)? {
        guard seconds > 0 else { return nil }
        var received = 0.0
        var sent = 0.0
        for (name, current) in new {
            guard let previous = old[name] else { continue }
            received += Double(current.received &- previous.received)
            sent += Double(current.sent &- previous.sent)
        }
        return (received / seconds, sent / seconds)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
