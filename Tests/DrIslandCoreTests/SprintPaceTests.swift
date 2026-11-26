import Foundation
import Testing
@testable import DrIslandCore

@Suite struct SprintPaceTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: d))! }

    /// Sprint Mon 16 to Fri 27 (10 working days); today is Wed 25 (8th working day).
    private func result(remaining: Double, scope: Double, ideal: Double, planned: Double = 33) -> BurndownResult {
        BurndownResult(points: [BurndownPoint(date: day(16), remaining: planned, scope: planned, ideal: planned),
                                BurndownPoint(date: day(25), remaining: remaining, scope: scope, ideal: ideal)],
                       plannedScope: planned, doneShare: 0, flaggedOpen: 0, daysLeft: 2, isOverdue: false,
                       missingPointsShare: 0, showsMissingPointsWarning: false)
    }

    @Test func behindAndForecastFollowThePaceSoFar() throws {
        let pace = try #require(SprintPace.compute(result(remaining: 15, scope: 35, ideal: 9), start: day(16), end: day(27),
                                                   closed: false, now: day(25).addingTimeInterval(3600 * 10), calendar: calendar))
        #expect(pace.done == 20)
        #expect(pace.behind == 6)
        #expect(pace.workdaysLeft == 2)
        #expect(pace.elapsedShare == 0.8)
        #expect(pace.scopeAdded == 2)
        // 20 done in 8 working days = 2.5 a day; 2 days left → 15 − 5 = 10 still open at the end.
        #expect(pace.forecastLeft == 10)
    }

    @Test func aheadOfTheIdealIsNegative() throws {
        let pace = try #require(SprintPace.compute(result(remaining: 5, scope: 33, ideal: 9), start: day(16), end: day(27),
                                                   closed: false, now: day(25), calendar: calendar))
        #expect(pace.behind < 0)
        #expect(pace.forecastLeft == 0)
    }

    @Test func weekendsDoNotCount() {
        #expect(SprintPace.workdays(from: day(21), through: day(22), calendar) == 0)
        #expect(SprintPace.workdays(from: day(16), through: day(27), calendar) == 10)
    }

    @Test func endedSprintHasNoForecast() throws {
        let pace = try #require(SprintPace.compute(result(remaining: 4, scope: 33, ideal: 0), start: day(16), end: day(20),
                                                   closed: true, now: day(25), calendar: calendar))
        #expect(pace.forecastLeft == nil)
        #expect(pace.workdaysLeft == 0)
        #expect(pace.elapsedShare == 1)
    }

    @Test func noPointsMeansNoPace() {
        let empty = BurndownResult(points: [], plannedScope: 0, doneShare: 0, flaggedOpen: 0, daysLeft: 0, isOverdue: false,
                                   missingPointsShare: 0, showsMissingPointsWarning: false)
        #expect(SprintPace.compute(empty, start: nil, end: nil, closed: false, now: day(25), calendar: calendar) == nil)
    }
}
