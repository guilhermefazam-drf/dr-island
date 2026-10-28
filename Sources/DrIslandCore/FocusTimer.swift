import Foundation

/// A Pomodoro-style timer: focus, short breaks, and a long break after a few focus rounds.
/// Pure state (no clock, no sleeping): callers pass the time in, so it is easy to test and to persist.
public struct FocusTimer: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        case focus, shortBreak, longBreak

        public var title: String {
            switch self {
            case .focus: return "Foco"
            case .shortBreak: return "Pausa"
            case .longBreak: return "Pausa longa"
            }
        }
    }

    public struct Config: Codable, Equatable, Sendable {
        public var focusMinutes: Int
        public var shortBreakMinutes: Int
        public var longBreakMinutes: Int
        public var roundsBeforeLongBreak: Int
        /// Start the next phase by itself instead of waiting for the user.
        public var autoStart: Bool

        public init(focusMinutes: Int = 25, shortBreakMinutes: Int = 5, longBreakMinutes: Int = 15, roundsBeforeLongBreak: Int = 4, autoStart: Bool = false) {
            self.focusMinutes = max(1, focusMinutes)
            self.shortBreakMinutes = max(1, shortBreakMinutes)
            self.longBreakMinutes = max(1, longBreakMinutes)
            self.roundsBeforeLongBreak = max(1, roundsBeforeLongBreak)
            self.autoStart = autoStart
        }
    }

    public private(set) var phase: Phase = .focus
    /// Focus rounds finished since the last long break.
    public private(set) var completedRounds = 0
    /// Set while running.
    public private(set) var endsAt: Date?
    /// Set while paused or waiting to start, so a pause keeps the time left.
    public private(set) var pausedRemaining: TimeInterval?

    public init() {}

    public var isRunning: Bool { endsAt != nil }

    public func duration(of phase: Phase, _ config: Config) -> TimeInterval {
        switch phase {
        case .focus: return TimeInterval(config.focusMinutes * 60)
        case .shortBreak: return TimeInterval(config.shortBreakMinutes * 60)
        case .longBreak: return TimeInterval(config.longBreakMinutes * 60)
        }
    }

    public func remaining(now: Date, _ config: Config) -> TimeInterval {
        if let endsAt { return max(0, endsAt.timeIntervalSince(now)) }
        return pausedRemaining ?? duration(of: phase, config)
    }

    /// 0 at the start of the phase, 1 at its end.
    public func progress(now: Date, _ config: Config) -> Double {
        let total = duration(of: phase, config)
        return total > 0 ? min(max(1 - remaining(now: now, config) / total, 0), 1) : 0
    }

    public mutating func start(now: Date, _ config: Config) {
        guard !isRunning else { return }
        endsAt = now.addingTimeInterval(remaining(now: now, config))
        pausedRemaining = nil
    }

    public mutating func pause(now: Date, _ config: Config) {
        guard isRunning else { return }
        pausedRemaining = remaining(now: now, config)
        endsAt = nil
    }

    /// Back to the first focus round, stopped.
    public mutating func reset() { self = FocusTimer() }

    /// Jumps to the next phase without counting the current one as finished (focus skipped does not count as a round).
    public mutating func skip(now: Date, _ config: Config) {
        advance(countRound: false, now: now, config)
    }

    /// Call as time passes; returns the phase that just ended, if any (at most one per call).
    @discardableResult
    public mutating func tick(now: Date, _ config: Config) -> Phase? {
        guard let endsAt, endsAt <= now else { return nil }
        let finished = phase
        advance(countRound: true, now: now, config)
        return finished
    }

    private mutating func advance(countRound: Bool, now: Date, _ config: Config) {
        switch phase {
        case .focus:
            if countRound { completedRounds += 1 }
            phase = completedRounds > 0 && completedRounds % config.roundsBeforeLongBreak == 0 && countRound ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .focus
        }
        endsAt = nil
        pausedRemaining = nil
        if config.autoStart { start(now: now, config) }
    }
}
