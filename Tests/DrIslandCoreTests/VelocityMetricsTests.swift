import Testing
import Foundation
@testable import DrIslandCore

@Suite struct VelocityMetricsTests {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func date(_ iso: String) -> Date { SprintParser.parseDate(iso)! }
    private let now = SprintParser.parseDate("2026-11-30T12:00:00.000Z")!

    private func closedSprint(id: Int, start: String, end: String, doneKeys: Int, openKeys: Int, addedLateKeys: Int = 0) -> SprintSnapshot {
        let startDate = date(start), endDate = date(end)
        let record = SprintRecord(id: id, name: "S\(id)", boardID: 1, start: startDate, end: endDate, state: "closed", completedAt: endDate)
        func issue(_ key: String, done: Bool, created: Date, late: Bool = false) -> SprintIssue {
            var events: [SprintIssueEvent] = []
            if done { events.append(SprintIssueEvent(date: startDate.addingTimeInterval(3 * 86_400), kind: .status, from: "1", to: "3")) }
            if late { events.append(SprintIssueEvent(date: startDate.addingTimeInterval(86_400), kind: .sprint, from: nil, to: String(id))) }
            return SprintIssue(key: key, type: "Story", points: 2, status: done ? "Feito" : "Aberto", statusID: done ? "3" : "1", isFlagged: false,
                               created: created, resolved: nil, events: events)
        }
        var issues: [SprintIssue] = []
        for n in 0..<doneKeys { issues.append(issue("D-\(id)-\(n)", done: true, created: startDate.addingTimeInterval(-86_400))) }
        for n in 0..<openKeys { issues.append(issue("O-\(id)-\(n)", done: false, created: startDate.addingTimeInterval(-86_400))) }
        for n in 0..<addedLateKeys { issues.append(issue("L-\(id)-\(n)", done: true, created: startDate.addingTimeInterval(-86_400), late: true)) }
        return SprintSnapshot(sprint: record, issues: issues, statusCategories: ["1": "new", "3": "done"], fetchedAt: now)
    }

    @Test func plannedAndCompletedPerSprintInTasks() {
        let s = closedSprint(id: 1, start: "2026-10-05T09:00:00.000Z", end: "2026-10-16T09:00:00.000Z", doneKeys: 3, openKeys: 1)
        let result = VelocityMetrics.compute([s], unit: .tasks, now: now, calendar: calendar)
        #expect(result.sprints.first?.planned == 4)
        #expect(result.sprints.first?.completed == 3)
        #expect(result.sprints.first?.added == 0)
        #expect(result.averageCompleted == 3)
    }

    @Test func pointsUnitUsesThePoints() {
        let s = closedSprint(id: 1, start: "2026-10-05T09:00:00.000Z", end: "2026-10-16T09:00:00.000Z", doneKeys: 3, openKeys: 1)
        #expect(VelocityMetrics.compute([s], unit: .points, now: now, calendar: calendar).sprints.first?.completed == 6)
    }

    @Test func workThatCameInAfterTheStartCountsAsAdded() {
        let s = closedSprint(id: 1, start: "2026-10-05T09:00:00.000Z", end: "2026-10-16T09:00:00.000Z", doneKeys: 2, openKeys: 0, addedLateKeys: 1)
        let sprint = VelocityMetrics.compute([s], unit: .tasks, now: now, calendar: calendar).sprints.first
        #expect(sprint?.planned == 2 && sprint?.added == 1 && sprint?.completed == 3)
    }

    @Test func oldestFirstLimitedToTheLatestAndOnlyClosedSprints() {
        var snaps = (1...8).map { closedSprint(id: $0, start: "2026-0\($0)-05T09:00:00.000Z", end: "2026-0\($0)-16T09:00:00.000Z", doneKeys: $0, openKeys: 0) }
        var active = closedSprint(id: 99, start: "2026-11-02T09:00:00.000Z", end: "2026-11-13T09:00:00.000Z", doneKeys: 1, openKeys: 1)
        active.sprint.state = "active"
        snaps.append(active)
        let result = VelocityMetrics.compute(snaps.shuffled(), unit: .tasks, now: now, calendar: calendar)
        #expect(result.sprints.map(\.id) == [3, 4, 5, 6, 7, 8])
    }

    @Test func noSprintsGivesZeroAverage() {
        let result = VelocityMetrics.compute([], unit: .tasks, now: now, calendar: calendar)
        #expect(result.sprints.isEmpty && result.averageCompleted == 0)
    }
}

@Suite struct VelocitySprintNameTests {
    @Test func shortNamesKeepTheSprintNumber() {
        #expect(VelocitySprint(id: 1, name: "SPRINT #18_Clínica", planned: 0, completed: 0, added: 0).shortName == "#18")
        #expect(VelocitySprint(id: 1, name: "Sprint 19", planned: 0, completed: 0, added: 0).shortName == "#19")
        #expect(VelocitySprint(id: 1, name: "Tentative backlog", planned: 0, completed: 0, added: 0).shortName == "Tentativ")
    }
}
