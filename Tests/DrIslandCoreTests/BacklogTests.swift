import Testing
import Foundation
@testable import DrIslandCore

@Suite struct BacklogTests {
    private func task(_ key: String) -> JiraTask {
        JiraTask(key: key, summary: key, status: "To Do", category: .todo, priority: nil, url: URL(string: "https://x.atlassian.net/browse/\(key)")!)
    }

    @Test func groupsFollowSprintStartThenBacklogLast() {
        let early = PlannedSprint(id: 9, name: "Sprint 44", start: SprintParser.parseDate("2026-11-09T09:00:00.000Z"))
        let late = PlannedSprint(id: 3, name: "Sprint 45", start: SprintParser.parseDate("2026-11-23T09:00:00.000Z"))
        let undated = PlannedSprint(id: 1, name: "Sprint 46")
        let groups = Backlog.groups([task("T-1"), task("T-2"), task("T-3"), task("T-4"), task("T-5")],
                                    sprints: ["T-2": late, "T-3": early, "T-4": undated, "T-5": early])
        #expect(groups.map(\.title) == ["Sprint 44", "Sprint 45", "Sprint 46", "Backlog"])
        #expect(groups[0].tasks.map(\.key) == ["T-3", "T-5"])   // rank order kept
        #expect(groups[3].tasks.map(\.key) == ["T-1"])
    }

    @Test func noBacklogGroupWhenEveryTaskIsPlanned() {
        let s = PlannedSprint(id: 1, name: "S")
        #expect(Backlog.groups([task("T-1")], sprints: ["T-1": s]).map(\.title) == ["S"])
        #expect(Backlog.groups([], sprints: [:]).isEmpty)
    }

    @Test func parsesOnlyFutureSprints() throws {
        let json = #"""
        {"issues":[
          {"key":"T-1","fields":{"customfield_10020":[{"id":5,"name":"Old","state":"closed"},{"id":7,"name":"Next","state":"future","startDate":"2026-11-09T09:00:00.000Z"}]}},
          {"key":"T-2","fields":{"customfield_10020":[{"id":6,"name":"Now","state":"active"}]}},
          {"key":"T-3","fields":{"customfield_10020":null}}
        ]}
        """#
        let result = BacklogParser.futureSprints(Data(json.utf8), field: "customfield_10020")
        #expect(result.count == 1)
        #expect(result["T-1"]?.name == "Next")
        #expect(result["T-1"]?.id == 7)
    }

    @Test func guessesTheMostCommonProject() {
        #expect(Backlog.guessProject(from: ["TEP-1", "ABC-2", "TEP-3"]) == "TEP")
        #expect(Backlog.guessProject(from: []) == nil)
    }

    @Test func pageTokenStopsOnLastPage() {
        #expect(BacklogParser.nextPageToken(Data(#"{"nextPageToken":"abc","isLast":false}"#.utf8)) == "abc")
        #expect(BacklogParser.nextPageToken(Data(#"{"nextPageToken":"abc","isLast":true}"#.utf8)) == nil)
        #expect(BacklogParser.nextPageToken(Data(#"{"issues":[]}"#.utf8)) == nil)
    }
}
