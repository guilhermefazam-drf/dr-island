import Foundation
import Testing
@testable import DrIslandCore

@Suite struct FocusTimerTests {
    private let config = FocusTimer.Config(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, roundsBeforeLongBreak: 2)
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func startsIdleWithFullFocus() {
        let timer = FocusTimer()
        #expect(!timer.isRunning)
        #expect(timer.phase == .focus)
        #expect(timer.remaining(now: t0, config) == 25 * 60)
    }

    @Test func countsDownAndFinishes() {
        var timer = FocusTimer()
        timer.start(now: t0, config)
        #expect(timer.isRunning)
        #expect(timer.remaining(now: t0.addingTimeInterval(60), config) == 24 * 60)
        #expect(timer.tick(now: t0.addingTimeInterval(60), config) == nil)
        #expect(timer.tick(now: t0.addingTimeInterval(25 * 60), config) == .focus)
        #expect(timer.phase == .shortBreak)
        #expect(!timer.isRunning)   // waits for the user unless autoStart
    }

    @Test func pauseKeepsTheTimeLeft() {
        var timer = FocusTimer()
        timer.start(now: t0, config)
        timer.pause(now: t0.addingTimeInterval(10 * 60), config)
        #expect(!timer.isRunning)
        #expect(timer.remaining(now: t0.addingTimeInterval(99 * 60), config) == 15 * 60)
        timer.start(now: t0.addingTimeInterval(100 * 60), config)
        #expect(timer.remaining(now: t0.addingTimeInterval(105 * 60), config) == 10 * 60)
    }

    @Test func longBreakAfterTheConfiguredRounds() {
        var timer = FocusTimer()
        var now = t0
        func run() { timer.start(now: now, config); now = now.addingTimeInterval(3600); timer.tick(now: now, config) }
        run()                                  // focus 1 -> short break
        #expect(timer.phase == .shortBreak)
        run()                                  // break -> focus
        #expect(timer.phase == .focus)
        run()                                  // focus 2 -> long break
        #expect(timer.phase == .longBreak)
        run()
        #expect(timer.phase == .focus)
    }

    @Test func skippingDoesNotCountARound() {
        var timer = FocusTimer()
        timer.skip(now: t0, config)
        #expect(timer.phase == .shortBreak)
        timer.skip(now: t0, config)
        #expect(timer.phase == .focus)
        #expect(timer.completedRounds == 0)
    }

    @Test func autoStartBeginsTheNextPhase() {
        var auto = config
        auto.autoStart = true
        var timer = FocusTimer()
        timer.start(now: t0, auto)
        timer.tick(now: t0.addingTimeInterval(25 * 60), auto)
        #expect(timer.isRunning)
        #expect(timer.phase == .shortBreak)
    }

    @Test func resetAndRoundTrip() throws {
        var timer = FocusTimer()
        timer.start(now: t0, config)
        let decoded = try JSONDecoder().decode(FocusTimer.self, from: JSONEncoder().encode(timer))
        #expect(decoded == timer)
        timer.reset()
        #expect(timer == FocusTimer())
    }
}
