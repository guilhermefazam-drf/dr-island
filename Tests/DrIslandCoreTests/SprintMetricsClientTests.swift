import Testing
import Foundation
@testable import DrIslandCore

@Suite struct SprintMetricsClientTests {
    private let site = URL(string: "https://x.atlassian.net")!

    @Test func boardSprintsURLAsksForActiveAndClosed() throws {
        let url = try #require(SprintMetricsRequests.boardSprintsURL(site: site, boardID: 483, startAt: 0))
        let text = url.absoluteString
        #expect(text.contains("rest/agile/1.0/board/483/sprint"))
        #expect(text.contains("state=active,closed"))
        #expect(text.contains("startAt=0"))
    }

    @Test func issuesJQLFiltersBySprintId() {
        #expect(SprintMetricsRequests.sprintIssuesJQL(sprintField: "customfield_10000", sprintID: 7648)
                == "cf[10000] = 7648 ORDER BY created ASC")
    }

    @Test func issuesURLExpandsChangelogAndAsksForTheFields() throws {
        let url = try #require(SprintMetricsRequests.sprintIssuesURL(
            site: site, sprintID: 7648, sprintField: "customfield_10000", pointsField: "customfield_10016", pageToken: nil))
        let items = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
        #expect(url.absoluteString.contains("rest/api/3/search/jql"))
        #expect(items["expand"] == "changelog")
        let fields = Set((items["fields"] ?? "").split(separator: ",").map(String.init))
        for field in ["status", "issuetype", "created", "resolutiondate", JiraConfig.flaggedField, "customfield_10016", "customfield_10000"] {
            #expect(fields.contains(field), "missing \(field)")
        }
        #expect(items["nextPageToken"] == nil)

        let next = try #require(SprintMetricsRequests.sprintIssuesURL(
            site: site, sprintID: 7648, sprintField: "customfield_10000", pointsField: nil, pageToken: "abc"))
        #expect(next.absoluteString.contains("nextPageToken=abc"))
    }

    @Test func changelogURLPagesByStartAt() throws {
        let url = try #require(SprintMetricsRequests.changelogURL(site: site, key: "TEP-1", startAt: 100))
        #expect(url.absoluteString.contains("rest/api/3/issue/TEP-1/changelog"))
        #expect(url.absoluteString.contains("startAt=100"))
    }

    @Test func parsesSprintsPage() throws {
        let json = """
        {"isLast": true, "values": [
          {"id": 1, "name": "Sprint 1", "state": "closed", "startDate": "2026-09-01T09:00:00.000Z",
           "endDate": "2026-09-14T09:00:00.000Z", "completeDate": "2026-09-14T10:00:00.000Z", "originBoardId": 483},
          {"id": 2, "name": "Sprint 2", "state": "active", "startDate": "2026-09-15T09:00:00.000Z",
           "endDate": "2026-09-28T09:00:00.000Z", "originBoardId": 483},
          {"id": 3, "name": "Sprint 3", "state": "future", "originBoardId": 483}
        ]}
        """
        let page = try #require(SprintMetricsParser.sprintsPage(Data(json.utf8), boardID: 483))
        #expect(page.isLast)
        #expect(page.sprints.map(\.id) == [1, 2, 3])
        #expect(page.sprints[0].boardID == 483)
        #expect(page.sprints[0].start == SprintParser.parseDate("2026-09-01T09:00:00.000Z"))
        #expect(page.sprints[0].completedAt == SprintParser.parseDate("2026-09-14T10:00:00.000Z"))
        #expect(page.sprints[1].completedAt == nil)
        #expect(page.sprints[2].start == nil)
        #expect(page.sprints[2].state == "future")
    }

    @Test func sortsSprintsByStartDescendingUndatedLast() {
        let d = { (s: String) in SprintParser.parseDate(s) }
        let sprints = [
            SprintRecord(id: 3, name: "c", boardID: 1, start: nil, end: nil, state: "future", completedAt: nil),
            SprintRecord(id: 1, name: "a", boardID: 1, start: d("2026-09-01T09:00:00.000Z"), end: nil, state: "closed", completedAt: nil),
            SprintRecord(id: 2, name: "b", boardID: 1, start: d("2026-09-15T09:00:00.000Z"), end: nil, state: "active", completedAt: nil),
        ]
        #expect(SprintMetricsParser.sortedNewestFirst(sprints).map(\.id) == [2, 1, 3])
    }

    @Test func findsThePointsFieldByName() throws {
        let json = """
        [{"id": "customfield_10020", "name": "Sprint"},
         {"id": "customfield_10016", "name": "Story point estimate"},
         {"id": "customfield_10028", "name": "Story Points"}]
        """
        let field = try #require(SprintMetricsParser.pointsField(Data(json.utf8)))
        #expect(field.id == "customfield_10028")
        #expect(field.name == "Story Points")
        let fallback = try #require(SprintMetricsParser.pointsField(Data(#"[{"id": "customfield_10016", "name": "Story point estimate"}]"#.utf8)))
        #expect(fallback.id == "customfield_10016")
        #expect(SprintMetricsParser.pointsField(Data(#"[{"id": "a", "name": "Other"}]"#.utf8)) == nil)
    }

    @Test func parsesStatusCategories() throws {
        let json = """
        [{"id": "3", "name": "Em Progresso", "statusCategory": {"key": "indeterminate"}},
         {"id": "10001", "name": "Done", "statusCategory": {"key": "done"}},
         {"id": "1", "name": "Por Fazer", "statusCategory": {"key": "new"}}]
        """
        let map = try #require(SprintMetricsParser.statusCategories(Data(json.utf8)))
        #expect(map == ["3": "indeterminate", "10001": "done", "1": "new"])
    }

    @Test func parsesAChangelogPage() throws {
        let json = #"{"isLast": false, "values": [{"id": "1", "created": "2026-09-02T09:00:00.000+0000", "items": []}]}"#
        let page = try #require(SprintMetricsParser.changelogPage(Data(json.utf8)))
        #expect(page.isLast == false)
        #expect(page.histories.count == 1)
    }

    @Test func completesATruncatedChangelog() {
        let initial: [[String: Any]] = [["id": "1", "created": "a"], ["id": "2", "created": "b"]]
        let pages: [[[String: Any]]] = [[["id": "2", "created": "b"], ["id": "3", "created": "c"]], [["id": "4", "created": "d"]]]
        let merged = mergeChangelogPages(initial: initial, pages: pages)
        #expect(merged.compactMap { $0["id"] as? String } == ["1", "2", "3", "4"])
    }
}
