import Foundation
import Testing
@testable import DrIslandCore

@Suite struct WeeklyPaceTests {
    private let calendar = Calendar(identifier: .gregorian)
    /// October 2026: the 26th is a Monday.
    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test func countsWorkdaysFromTheWindowStart() {
        // Window Mon 26 14:00 → Mon 2 Nov 14:00.
        let resets = calendar.date(byAdding: .day, value: 7, to: date(26, hour: 14))!
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(26, hour: 15), calendar: calendar) == 1)
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(28), calendar: calendar) == 3)
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(31), calendar: calendar) == 5)
        // The reset morning is past the fifth workday: still capped at 5.
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: resets.addingTimeInterval(-3600), calendar: calendar) == 5)
    }

    @Test func windowStartingMidWeekSkipsTheWeekend() {
        // Window Thu 29 → Thu 5 Nov: Thu, Fri, (Sat, Sun), Mon, Tue, Wed.
        let resets = calendar.date(byAdding: .day, value: 7, to: date(29, hour: 9))!
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(31), calendar: calendar) == 2)
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: calendar.date(byAdding: .day, value: 3, to: date(30))!, calendar: calendar) == 3)
    }

    @Test func allowanceIsAtLeastOneWorkday() {
        // Window starting on Saturday: on the weekend no workday has started yet.
        let resets = calendar.date(byAdding: .day, value: 7, to: date(31, hour: 10))!
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(31, hour: 11), calendar: calendar) == 0)
        #expect(WeeklyPace.allowance(resetsAt: resets, now: date(31, hour: 11), calendar: calendar) == 0.2)
    }

    @Test func fractionIsMeasuredAgainstTodaysAllowance() {
        let resets = calendar.date(byAdding: .day, value: 7, to: date(26, hour: 0))!
        // Tuesday: 40% allowed, 30% used → 75% of the allowance.
        #expect(abs(WeeklyPace.fraction(weekly: 0.3, resetsAt: resets, now: date(27), calendar: calendar) - 0.75) < 1e-9)
        #expect(WeeklyPace.fraction(weekly: 0.3, resetsAt: nil, now: date(27), calendar: calendar) == 0.3)
    }
}
