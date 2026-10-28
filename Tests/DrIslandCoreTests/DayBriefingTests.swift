import Foundation
import Testing
@testable import DrIslandCore

@Suite struct DayBriefingTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return c
    }
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
    private func entry(_ kind: PRChange.Kind, at date: Date, id: String = "x") -> AlertEntry {
        AlertEntry(PRChange(prID: id, ref: "r#1", title: "T", kind: kind), date: date)
    }

    @Test func timelineKeepsTodayOldestFirst() {
        let log = [entry(.approved, at: date(21, 11)), entry(.ciFailed, at: date(21, 9)), entry(.merged, at: date(20, 17))]
        let today = DayBriefing.timeline(log, now: date(21, 12), calendar: calendar)
        #expect(today.map(\.kind) == [.ciFailed, .approved])
    }

    @Test func entriesSinceAreNewestFirstAndExcludeTheBoundary() {
        let log = [entry(.ciFailed, at: date(20, 18)), entry(.approved, at: date(21, 9)), entry(.merged, at: date(20, 17))]
        let since = DayBriefing.entries(log, since: date(20, 17))
        #expect(since.map(\.kind) == [.approved, .ciFailed])
    }

    @Test func summaryCountsBySourceBiggestFirst() {
        let log = [entry(.jiraNew, at: date(21, 9)), entry(.ciFailed, at: date(21, 9), id: "a"), entry(.approved, at: date(21, 10), id: "b"), entry(.jiraStatus, at: date(21, 10), id: "c"), entry(.ciFailed, at: date(21, 11), id: "d")]
        #expect(DayBriefing.summary(log) == "3 PRs · 2 Jira")
        #expect(DayBriefing.summary([]) == "")
    }

    @Test func autoShowsOncePerDayAfterFiveWhenSomethingHappened() {
        #expect(DayBriefing.shouldAutoShow(lastShown: nil, pending: 2, now: date(21, 9), calendar: calendar))
        #expect(DayBriefing.shouldAutoShow(lastShown: date(20, 9), pending: 1, now: date(21, 9), calendar: calendar))
        #expect(!DayBriefing.shouldAutoShow(lastShown: date(21, 8), pending: 3, now: date(21, 14), calendar: calendar))
        #expect(!DayBriefing.shouldAutoShow(lastShown: nil, pending: 0, now: date(21, 9), calendar: calendar))
        #expect(!DayBriefing.shouldAutoShow(lastShown: nil, pending: 4, now: date(21, 3), calendar: calendar))
    }

    @Test func sinceLabelNamesTodayYesterdayAndOlder() {
        let now = date(21, 12)
        #expect(DayBriefing.sinceLabel(date(21, 9, 30), now: now, calendar: calendar).hasPrefix("Desde as "))
        #expect(DayBriefing.sinceLabel(date(20, 18, 12), now: now, calendar: calendar).hasPrefix("Desde ontem"))
        #expect(DayBriefing.sinceLabel(date(17, 18), now: now, calendar: calendar).hasPrefix("Desde "))
    }

    @Test func hourlyCountsPerHourOfThatDayOnly() {
        let log = [entry(.approved, at: date(21, 9, 5)), entry(.ciFailed, at: date(21, 9, 50), id: "a"), entry(.merged, at: date(21, 14)), entry(.merged, at: date(20, 9), id: "b")]
        let counts = DayBriefing.hourly(log, day: date(21, 12), calendar: calendar)
        #expect(counts.count == 24)
        #expect(counts[9] == 2 && counts[14] == 1 && counts.reduce(0, +) == 3)
        #expect(DayBriefing.peakHour(counts) == 9)
        #expect(DayBriefing.peakHour(Array(repeating: 0, count: 24)) == nil)
    }

    @Test func hourRangeCoversActivityAndKeepsAMinimumSpan() {
        var counts = Array(repeating: 0, count: 24)
        #expect(DayBriefing.hourRange(counts, endHour: 11) == 8...11 || DayBriefing.hourRange(counts, endHour: 11) == 5...11)
        counts[6] = 1
        #expect(DayBriefing.hourRange(counts, endHour: 15).lowerBound == 6)
        #expect(DayBriefing.hourRange(counts, endHour: 15).upperBound == 15)
        #expect(DayBriefing.hourRange(counts, endHour: 23).upperBound == 23)
        let early = DayBriefing.hourRange(Array(repeating: 0, count: 24), endHour: 2)
        #expect(early.lowerBound >= 0 && early.upperBound <= 23 && early.count >= 3)
    }
}
