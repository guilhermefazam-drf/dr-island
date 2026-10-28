import Foundation
import Testing
@testable import DrIslandCore

@Suite struct UsageHistoryTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ day: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))! }

    @Test func peaksOnlyGoUpWithinADay() {
        var list = UsageHistory.recording(session: 0.3, weekly: 0.1, into: [], now: date(10), calendar: calendar)
        list = UsageHistory.recording(session: 0.6, weekly: 0.2, into: list, now: date(10), calendar: calendar)
        list = UsageHistory.recording(session: 0.1, weekly: 0.05, into: list, now: date(10), calendar: calendar)
        #expect(list == [DayUsage(day: "2026-10-10", sessionPeak: 0.6, weeklyPeak: 0.2)])
    }

    @Test func newDayAppendsAndOldDaysAreTrimmed() {
        var list: [DayUsage] = []
        for offset in 0..<70 {
            list = UsageHistory.recording(session: 0.5, weekly: nil, into: list,
                                          now: calendar.date(byAdding: .day, value: offset, to: date(1))!, calendar: calendar)
        }
        #expect(list.count == UsageHistory.keepDays)
        #expect(list.last?.day == "2026-12-09")
    }

    @Test func lastDaysFillsGaps() {
        let list = [DayUsage(day: "2026-10-10", sessionPeak: 0.4), DayUsage(day: "2026-10-12", sessionPeak: 0.8)]
        let days = UsageHistory.lastDays(4, from: list, now: date(12), calendar: calendar)
        #expect(days.map { $0.usage?.sessionPeak } == [nil, 0.4, nil, 0.8])
    }

    @Test func roundTrip() {
        let list = [DayUsage(day: "2026-10-10", sessionPeak: 0.4, weeklyPeak: 0.2)]
        #expect(UsageHistory.decode(UsageHistory.encode(list)) == list)
        #expect(UsageHistory.decode("garbage").isEmpty)
    }
}
