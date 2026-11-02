import Testing
import Foundation
@testable import DrIslandCore

@Suite struct BurndownSummaryTests {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func date(_ iso: String) -> Date { SprintParser.parseDate(iso)! }
    private func result(doneShare: Double = 0.5, flagged: Int = 0, daysLeft: Int = 3, overdue: Bool = false,
                        members: Int = 10, missing: Int = 3) -> BurndownResult {
        BurndownResult(points: [], plannedScope: 10, doneShare: doneShare, flaggedOpen: flagged, daysLeft: daysLeft, isOverdue: overdue,
                       missingPointsShare: 0.3, showsMissingPointsWarning: true, memberCount: members, missingPointsCount: missing)
    }

    @Test func doneAndFlaggedTexts() {
        #expect(BurndownSummary.doneText(result(doneShare: 0.616)) == "62% concluído")
        #expect(BurndownSummary.flaggedText(result(flagged: 1)) == "1 bloqueada")
        #expect(BurndownSummary.flaggedText(result(flagged: 3)) == "3 bloqueadas")
        #expect(BurndownSummary.flaggedText(result(flagged: 0)) == "0 bloqueadas")
    }

    @Test func missingPointsTextUsesTheMembers() {
        #expect(BurndownSummary.missingPointsText(result(members: 10, missing: 3)) == "3 de 10 tasks sem pontos")
    }

    @Test func closedWinsOverEverything() {
        let d = BurndownSummary.deadline(result(overdue: true), closed: true, sprintEnd: date("2026-10-23T12:00:00.000Z"), now: date("2026-11-30T12:00:00.000Z"), calendar: calendar)
        #expect(d == .closed)
        #expect(BurndownSummary.text(d) == "fechada")
    }

    @Test func overdueOnlyOnceTheEndDayIsOver() {
        let end = date("2026-10-23T10:00:00.000Z")
        let sameDayAfterEnd = BurndownSummary.deadline(result(daysLeft: 0, overdue: true), closed: false, sprintEnd: end, now: date("2026-10-23T15:00:00.000Z"), calendar: calendar)
        #expect(sameDayAfterEnd == .today)
        let nextDay = BurndownSummary.deadline(result(daysLeft: 0, overdue: true), closed: false, sprintEnd: end, now: date("2026-10-24T08:00:00.000Z"), calendar: calendar)
        #expect(nextDay == .overdue)
        #expect(BurndownSummary.text(nextDay) == "fora de prazo")
    }

    @Test func daysLeftWordsAndSingular() {
        let now = date("2026-10-20T12:00:00.000Z"), end = date("2026-10-23T12:00:00.000Z")
        #expect(BurndownSummary.text(BurndownSummary.deadline(result(daysLeft: 1), closed: false, sprintEnd: end, now: now, calendar: calendar)) == "acaba em 1 dia")
        #expect(BurndownSummary.text(BurndownSummary.deadline(result(daysLeft: 4), closed: false, sprintEnd: end, now: now, calendar: calendar)) == "acaba em 4 dias")
        #expect(BurndownSummary.text(BurndownSummary.deadline(result(daysLeft: 0), closed: false, sprintEnd: end, now: now, calendar: calendar)) == "acaba hoje")
    }
}
