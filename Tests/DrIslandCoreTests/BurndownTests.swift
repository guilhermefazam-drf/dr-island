import Testing
import Foundation
@testable import DrIslandCore

@Suite struct BurndownTests {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    static let sprintID = 7350

    static func date(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }
    static func day(_ d: Int, _ hour: Int = 10) -> Date {
        date(String(format: "2026-10-%02dT%02d:00:00Z", d, hour))
    }

    static let categories = ["A fazer": "new", "Em curso": "indeterminate", "Feito": "done"]

    static func issue(_ key: String, points: Double? = 3, status: String = "A fazer", flagged: Bool = false,
                      events: [SprintIssueEvent] = []) -> SprintIssue {
        SprintIssue(key: key, type: "Task", points: points, status: status, isFlagged: flagged,
                    created: day(1), resolved: nil, events: events)
    }

    static func snapshot(_ issues: [SprintIssue], state: String = "closed",
                         end: Date = day(23, 18)) -> SprintSnapshot {
        SprintSnapshot(
            sprint: SprintRecord(id: sprintID, name: "S1", boardID: 1, start: day(12, 0), end: end,
                                 state: state, completedAt: nil),
            issues: issues, statusCategories: categories, fetchedAt: day(23, 18))
    }

    static func compute(_ s: SprintSnapshot, unit: MetricUnit = .points, now: Date = day(24)) -> BurndownResult {
        Burndown.compute(s, unit: unit, now: now, calendar: calendar)
    }

    static func point(_ r: BurndownResult, _ d: Int) -> BurndownPoint {
        r.points.first { calendar.component(.day, from: $0.date) == d }!
    }

    static func sprintEvent(_ d: Int, from: String?, to: String?) -> SprintIssueEvent {
        SprintIssueEvent(date: day(d), kind: .sprint, from: from, to: to)
    }

    @Test func remainingDropsWhenATaskGetsDone() {
        let done = Self.issue("A-1", status: "Feito", events: [
            SprintIssueEvent(date: Self.day(15), kind: .status, from: "A fazer", to: "Feito")])
        let r = Self.compute(Self.snapshot([done, Self.issue("A-2")]))
        #expect(Self.point(r, 14).remaining == 6)
        #expect(Self.point(r, 15).remaining == 3)
        #expect(r.doneShare == 0.5)
    }

    @Test func idealLineIsLinearInWorkdays() {
        let r = Self.compute(Self.snapshot([Self.issue("A-1"), Self.issue("A-2")]))
        #expect(r.plannedScope == 6)
        #expect(Self.point(r, 12).ideal == 6)
        #expect(Self.point(r, 23).ideal == 0)
        #expect(Self.point(r, 17).ideal == Self.point(r, 16).ideal)
        #expect(Self.point(r, 18).ideal == Self.point(r, 16).ideal)
    }

    @Test func taskRemovedMidSprintCountsWhileItWasThere() {
        let removed = Self.issue("A-1", events: [Self.sprintEvent(16, from: "7350", to: "")])
        let r = Self.compute(Self.snapshot([removed, Self.issue("A-2")]))
        #expect(Self.point(r, 15).scope == 6)
        #expect(Self.point(r, 16).scope == 3)
        #expect(r.plannedScope == 6)
    }

    @Test func taskAddedMidSprintRaisesScopeNotPlanned() {
        let added = Self.issue("A-1", events: [Self.sprintEvent(14, from: "7349", to: "7349, 7350")])
        let r = Self.compute(Self.snapshot([added, Self.issue("A-2")]))
        #expect(r.plannedScope == 3)
        #expect(Self.point(r, 13).scope == 3)
        #expect(Self.point(r, 14).scope == 6)
    }

    @Test func taskCreatedDirectlyInSprint() {
        let created = Self.issue("A-1", events: [Self.sprintEvent(14, from: nil, to: "7350")])
        let r = Self.compute(Self.snapshot([created]))
        #expect(r.plannedScope == 0)
        #expect(Self.point(r, 13).scope == 0)
        #expect(Self.point(r, 14).scope == 3)
    }

    @Test func taskCarriedOverFromAnotherSprint() {
        let carried = Self.issue("A-1", events: [Self.sprintEvent(14, from: "7351", to: "7351,7350")])
        let r = Self.compute(Self.snapshot([carried]))
        #expect(Self.point(r, 13).scope == 0)
        #expect(Self.point(r, 14).scope == 3)
    }

    @Test func pointsEditedMidSprintUsesTheValueOfTheDay() {
        let edited = Self.issue("A-1", points: 8, events: [
            SprintIssueEvent(date: Self.day(15), kind: .points, from: "3", to: "8")])
        let r = Self.compute(Self.snapshot([edited]))
        #expect(Self.point(r, 14).scope == 3)
        #expect(Self.point(r, 15).scope == 8)
    }

    @Test func unitTasksCountsOnePerIssue() {
        let done = Self.issue("A-1", points: 8, status: "Feito", events: [
            SprintIssueEvent(date: Self.day(15), kind: .status, from: "A fazer", to: "Feito")])
        let r = Self.compute(Self.snapshot([done, Self.issue("A-2", points: nil)]), unit: .tasks)
        #expect(Self.point(r, 14).scope == 2)
        #expect(Self.point(r, 14).remaining == 2)
        #expect(Self.point(r, 15).remaining == 1)
    }

    @Test func missingPointsWarning() {
        func five(missing: Int) -> SprintSnapshot {
            Self.snapshot((0..<5).map { Self.issue("A-\($0)", points: $0 < missing ? nil : 3) })
        }
        let two = Self.compute(five(missing: 2))
        #expect(two.missingPointsShare == 0.4)
        #expect(two.showsMissingPointsWarning)
        #expect(!Self.compute(five(missing: 0)).showsMissingPointsWarning)
        #expect(!Self.compute(five(missing: 2), unit: .tasks).showsMissingPointsWarning)
    }

    @Test func overdueActiveSprintKeepsGoingPastTheEnd() {
        let issues = [Self.issue("A-1")]
        let now = Self.day(27)
        let active = Self.compute(Self.snapshot(issues, state: "active"), now: now)
        #expect(active.isOverdue)
        #expect(active.daysLeft == 0)
        #expect(Self.calendar.isDate(active.points.last!.date, inSameDayAs: now))
        let closed = Self.compute(Self.snapshot(issues, state: "closed"), now: now)
        #expect(!closed.isOverdue)
        #expect(Self.calendar.component(.day, from: closed.points.last!.date) == 23)
    }

    @Test func emptySprintDoesNotFail() {
        let r = Self.compute(Self.snapshot([]))
        #expect(!r.points.isEmpty)
        #expect(r.points.allSatisfy { $0.remaining == 0 && $0.scope == 0 && $0.ideal == 0 })
        #expect(r.doneShare == 0)
        #expect(r.missingPointsShare == 0)
    }

    @Test func flaggedOpenCountsOnlyOpenMembers() {
        let open = Self.issue("A-1", flagged: true)
        let done = Self.issue("A-2", status: "Feito", flagged: true)
        let r = Self.compute(Self.snapshot([open, done, Self.issue("A-3")]))
        #expect(r.flaggedOpen == 1)
    }
}
