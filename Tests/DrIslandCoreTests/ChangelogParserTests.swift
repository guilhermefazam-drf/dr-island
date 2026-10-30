import Testing
import Foundation
@testable import DrIslandCore

@Suite struct ChangelogParserTests {
    private func date(_ iso: String) -> Date { SprintParser.parseDate(iso)! }

    private func json(histories: String, total: Int? = nil, count: Int = 3, token: String? = nil, points: String = "5", flagged: String = "[{\"value\":\"Impediment\"}]") -> Data {
        let totalValue = total ?? count
        let next = token.map { ",\"nextPageToken\":\"\($0)\"" } ?? ""
        return Data("""
        {"issues":[
          {"key":"A-1","fields":{"status":{"name":"Em curso"},"issuetype":{"name":"Task"},
            "customfield_10016":\(points),"customfield_10006":\(flagged),
            "created":"2026-10-12T08:00:00.000+0000","resolutiondate":"2026-10-20T10:15:00.000+0000"},
           "changelog":{"total":\(totalValue),"histories":[\(histories)]}},
          {"key":"A-2","fields":{"status":{"name":"Por fazer"},"issuetype":{"name":"Bug"},
            "customfield_10016":null,"customfield_10006":null,
            "created":"2026-10-13T08:00:00.000+0000","resolutiondate":null},
           "changelog":{"total":0,"histories":[]}}
        ]\(next)}
        """.utf8)
    }

    private let threeHistories = """
    {"id":"1","created":"2026-10-15T09:30:00.000+0000","items":[{"field":"status","fromString":"Por fazer","toString":"Em curso","from":"1","to":"2"}]},
    {"id":"2","created":"2026-10-16T09:30:00.000+0000","items":[{"field":"Sprint","from":"7351","to":"7351, 7648","fromString":"S1","toString":"S1, S2"}]},
    {"id":"3","created":"2026-10-17T09:30:00.000+0000","items":[{"field":"Story Points","fromString":"2","toString":"5"}]}
    """

    private func parse(_ data: Data) throws -> (issues: [SprintIssue], truncated: [String], nextPageToken: String?) {
        try ChangelogParser.issues(from: data, sprintField: "customfield_10020", pointsField: "customfield_10016")
    }

    @Test func parsesStatusSprintAndPointsEvents() throws {
        let events = try parse(json(histories: threeHistories)).issues[0].events
        #expect(events.map(\.kind) == [.status, .sprint, .points])
        #expect(events[0].from == "Por fazer" && events[0].to == "Em curso")
        #expect(events[1].from == "7351" && events[1].to == "7351, 7648")
        #expect(events[2].from == "2" && events[2].to == "5")
        #expect(events[0].date == date("2026-10-15T09:30:00.000+0000"))
    }

    @Test func ignoresUnknownFieldsAndSortsByDate() throws {
        let histories = """
        {"id":"2","created":"2026-10-17T09:30:00.000+0000","items":[{"field":"Story Points","fromString":"2","toString":"5"}]},
        {"id":"1","created":"2026-10-15T09:30:00.000+0000","items":[{"field":"assignee","fromString":"a","toString":"b"},{"field":"status","fromString":"Por fazer","toString":"Em curso"}]}
        """
        let events = try parse(json(histories: histories)).issues[0].events
        #expect(events.map(\.kind) == [.status, .points])
    }

    @Test func readsPointsFlagAndDates() throws {
        let issues = try parse(json(histories: threeHistories)).issues
        let a = issues[0]
        #expect(a.key == "A-1" && a.type == "Task" && a.status == "Em curso")
        #expect(a.points == 5)
        #expect(a.isFlagged)
        #expect(a.created == date("2026-10-12T08:00:00.000+0000"))
        #expect(a.resolved == date("2026-10-20T10:15:00.000+0000"))
        #expect(issues[1].points == nil && !issues[1].isFlagged && issues[1].resolved == nil)
    }

    @Test func reportsTruncatedChangelog() throws {
        let one = "{\"id\":\"1\",\"created\":\"2026-10-15T09:30:00.000+0000\",\"items\":[{\"field\":\"status\",\"fromString\":\"a\",\"toString\":\"b\"}]}"
        let histories = Array(repeating: one, count: 100).joined(separator: ",")
        #expect(try parse(json(histories: histories, total: 130)).truncated == ["A-1"])
        #expect(try parse(json(histories: threeHistories)).truncated.isEmpty)
    }

    @Test func returnsNextPageToken() throws {
        #expect(try parse(json(histories: threeHistories, token: "abc")).nextPageToken == "abc")
        #expect(try parse(json(histories: threeHistories)).nextPageToken == nil)
    }

    @Test func taskCreatedDirectlyInSprintHasSprintEventFromEmpty() throws {
        let histories = """
        {"id":"1","created":"2026-10-15T09:30:00.000+0000","items":[{"field":"Sprint","from":"","to":"7648","fromString":"","toString":"S2"}]}
        """
        let event = try parse(json(histories: histories)).issues[0].events[0]
        #expect(event.from == nil)
        #expect(event.to == "7648")
    }
}
