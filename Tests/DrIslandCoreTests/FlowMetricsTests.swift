import Testing
import Foundation
@testable import DrIslandCore

@Suite struct FlowMetricsTests {
    private func date(_ iso: String) -> Date { SprintParser.parseDate(iso)! }
    private let now = SprintParser.parseDate("2026-10-20T12:00:00.000Z")!
    private let sprint = SprintRecord(id: 7, name: "S", boardID: 1, start: SprintParser.parseDate("2026-10-12T09:00:00.000Z"),
                                      end: SprintParser.parseDate("2026-10-23T09:00:00.000Z"), state: "active", completedAt: nil)
    private let categories = ["1": "new", "2": "indeterminate", "3": "done"]
    private let names = ["1": "Por fazer", "2": "Em curso", "3": "Concluído"]

    private func issue(_ key: String, status: String, points: Double? = 2, flagged: Bool = false, created: String = "2026-10-10T09:00:00.000Z",
                        events: [SprintIssueEvent] = []) -> SprintIssue {
        SprintIssue(key: key, type: "Story", points: points, status: names[status] ?? status, statusID: status, isFlagged: flagged,
                    created: date(created), resolved: nil, events: events)
    }
    private func move(_ iso: String, from: String, to: String) -> SprintIssueEvent {
        SprintIssueEvent(date: date(iso), kind: .status, from: from, to: to)
    }
    private func snapshot(_ issues: [SprintIssue]) -> SprintSnapshot {
        SprintSnapshot(sprint: sprint, issues: issues, statusCategories: categories, fetchedAt: now, statusNames: names)
    }

    @Test func countsWorkPerStatusInCategoryOrder() {
        let result = FlowMetrics.compute(snapshot([issue("A-1", status: "2", points: 3), issue("A-2", status: "3", points: 5), issue("A-3", status: "1", points: 2), issue("A-4", status: "2", points: 1)]), unit: .points, now: now)
        #expect(result.rows.map(\.name) == ["Por fazer", "Em curso", "Concluído"])
        #expect(result.rows.map(\.amount) == [2, 4, 5])
    }

    @Test func tasksUnitCountsOnePerIssue() {
        let result = FlowMetrics.compute(snapshot([issue("A-1", status: "2", points: 9), issue("A-2", status: "2", points: nil)]), unit: .tasks, now: now)
        #expect(result.rows.first?.amount == 2)
    }

    @Test func medianTimeInAStatusUsesFinishedStaysOnly() {
        // Status 2 lasted 2 days for A-1 and 4 days for A-2 (median 3); A-3 is still in it and does not count.
        let a1 = issue("A-1", status: "3", events: [move("2026-10-12T00:00:00.000Z", from: "1", to: "2"), move("2026-10-14T00:00:00.000Z", from: "2", to: "3")])
        let a2 = issue("A-2", status: "3", events: [move("2026-10-12T00:00:00.000Z", from: "1", to: "2"), move("2026-10-16T00:00:00.000Z", from: "2", to: "3")])
        let a3 = issue("A-3", status: "2", events: [move("2026-10-12T00:00:00.000Z", from: "1", to: "2")])
        let result = FlowMetrics.compute(snapshot([a1, a2, a3]), unit: .tasks, now: now)
        #expect(result.rows.first { $0.id == "2" }?.medianDays == 3)
    }

    @Test func flaggedOrLongStuckTasksAreListedFlaggedFirst() {
        let stuck = issue("A-1", status: "2", events: [move("2026-10-14T12:00:00.000Z", from: "1", to: "2")])          // 6 days in "Em curso"
        let fresh = issue("A-2", status: "2", events: [move("2026-10-19T12:00:00.000Z", from: "1", to: "2")])          // 1 day: not listed
        let flagged = issue("A-3", status: "2", flagged: true, events: [move("2026-10-19T12:00:00.000Z", from: "1", to: "2")])
        let result = FlowMetrics.compute(snapshot([stuck, fresh, flagged]), unit: .tasks, now: now)
        #expect(result.stuck.map(\.key) == ["A-3", "A-1"])
        #expect(result.stuck.first?.isFlagged == true)
        #expect(abs((result.stuck.last?.days ?? 0) - 6) < 0.01)
        #expect(result.flaggedOpen == 1)
    }

    @Test func doneTasksAreNeverStuck() {
        let done = issue("A-1", status: "3", flagged: true, events: [move("2026-10-12T12:00:00.000Z", from: "2", to: "3")])
        let result = FlowMetrics.compute(snapshot([done]), unit: .tasks, now: now)
        #expect(result.stuck.isEmpty)
        #expect(result.flaggedOpen == 0)
    }

    @Test func aTaskWithNoHistoryCountsFromItsCreation() {
        let old = issue("A-1", status: "1", created: "2026-10-12T12:00:00.000Z")   // 8 days in "Por fazer"
        let result = FlowMetrics.compute(snapshot([old]), unit: .tasks, now: now)
        #expect(result.stuck.map(\.key) == ["A-1"])
    }

    @Test func stuckListIsCapped() {
        let issues = (1...6).map { issue("A-\($0)", status: "2", events: [move("2026-10-12T12:00:00.000Z", from: "1", to: "2")]) }
        #expect(FlowMetrics.compute(snapshot(issues), unit: .tasks, now: now).stuck.count == FlowMetrics.stuckLimit)
    }

    @Test func aStatusMissingFromTheNameMapFallsBackToTheIssueStatusName() {
        var snap = snapshot([issue("A-1", status: "9")])
        snap.statusNames = [:]
        #expect(FlowMetrics.compute(snap, unit: .tasks, now: now).rows.first?.name == "9")
    }

    @Test func emptySprintGivesAnEmptyResult() {
        let result = FlowMetrics.compute(snapshot([]), unit: .tasks, now: now)
        #expect(result.rows.isEmpty && result.stuck.isEmpty)
    }
}
