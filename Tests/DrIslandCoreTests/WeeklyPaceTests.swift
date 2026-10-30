import Foundation
import Testing
@testable import DrIslandCore

@Suite struct WeeklyPaceTests {
    private let calendar = Calendar(identifier: .gregorian)
    /// October 2026: the 26th is a Monday.
    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test func dayProgressSkipsLunch() {
        #expect(WeeklyPace.dayProgress(at: date(26, hour: 8), calendar: calendar) == 0)
        #expect(abs(WeeklyPace.dayProgress(at: date(26, hour: 11), calendar: calendar) - 0.25) < 1e-9)
        // Lunch 13:00–14:00: frozen at half.
        #expect(WeeklyPace.dayProgress(at: date(26, hour: 13), calendar: calendar) == 0.5)
        #expect(WeeklyPace.dayProgress(at: date(26, hour: 13).addingTimeInterval(1800), calendar: calendar) == 0.5)
        #expect(abs(WeeklyPace.dayProgress(at: date(26, hour: 16), calendar: calendar) - 0.75) < 1e-9)
        #expect(WeeklyPace.dayProgress(at: date(26, hour: 18), calendar: calendar) == 1)
        #expect(WeeklyPace.dayProgress(at: date(26, hour: 22), calendar: calendar) == 1)
    }

    @Test func countsWorkdaysFromTheWindowStart() {
        // Window Mon 26 14:00 → Mon 2 Nov 14:00.
        let resets = calendar.date(byAdding: .day, value: 7, to: date(26, hour: 14))!
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(26, hour: 18), calendar: calendar) == 1)
        // Wed 28 at 13:30 (lunch) = 2 finished days + half of today.
        #expect(abs(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(28, hour: 13).addingTimeInterval(1800), calendar: calendar) - 2.5) < 1e-9)
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(31), calendar: calendar) == 5)
        // The reset morning is past the fifth workday: still capped at 5.
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: resets.addingTimeInterval(-3600), calendar: calendar) == 5)
    }

    @Test func windowStartingMidWeekSkipsTheWeekend() {
        // Window Thu 29 → Thu 5 Nov: Thu, Fri, (Sat, Sun), Mon, Tue, Wed.
        let resets = calendar.date(byAdding: .day, value: 7, to: date(29, hour: 9))!
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(31), calendar: calendar) == 2)
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: calendar.date(byAdding: .day, value: 3, to: date(30, hour: 18))!, calendar: calendar) == 3)
    }

    @Test func allowanceNeverDropsBelowOneWorkingHour() {
        // Window starting on Saturday: on the weekend no workday has been earned yet.
        let resets = calendar.date(byAdding: .day, value: 7, to: date(31, hour: 10))!
        #expect(WeeklyPace.elapsedWorkdays(resetsAt: resets, now: date(31, hour: 11), calendar: calendar) == 0)
        #expect(abs(WeeklyPace.allowance(resetsAt: resets, now: date(31, hour: 11), calendar: calendar) - 1.0 / 40) < 1e-9)
    }

    @Test func fractionIsMeasuredAgainstTodaysAllowance() {
        let resets = calendar.date(byAdding: .day, value: 7, to: date(26, hour: 0))!
        // Tuesday after 18:00: 40% allowed, 30% used → 75% of the allowance.
        #expect(abs(WeeklyPace.fraction(weekly: 0.3, resetsAt: resets, now: date(27, hour: 18), calendar: calendar) - 0.75) < 1e-9)
        #expect(WeeklyPace.fraction(weekly: 0.3, resetsAt: nil, now: date(27), calendar: calendar) == 0.3)
    }
}

extension WeeklyPaceTests {
    @Test func customStartMovesTheDay() {
        let cal = Calendar(identifier: .gregorian)
        let noon = cal.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 12))!
        // Start 08:00: noon is the end of the morning, half of the day.
        #expect(WeeklyPace.dayProgress(at: noon, workStartMinute: 8 * 60, calendar: cal) == 0.5)
        #expect(WeeklyPace.workEndMinute(start: 8 * 60) == 17 * 60)
    }
}
