import Testing
import Foundation
@testable import DrIslandCore

@Suite struct SprintTests {
    private func date(_ iso: String) -> Date { SprintParser.parseDate(iso)! }
    private var sprint: SprintInfo {
        SprintInfo(name: "Sprint 42", start: date("2026-10-12T09:00:00.000Z"), end: date("2026-10-26T09:00:00.000Z"))
    }

    @Test func progressIsClampedAndLinear() {
        #expect(sprint.progress(now: date("2026-10-01T00:00:00.000Z")) == 0)   // not started
        #expect(sprint.progress(now: date("2026-10-19T09:00:00.000Z")) == 0.5)
        #expect(sprint.progress(now: date("2026-11-30T00:00:00.000Z")) == 1)   // overdue
    }

    @Test func degenerateSprintDoesNotDivideByZero() {
        let d = date("2026-10-12T09:00:00.000Z")
        #expect(SprintInfo(name: "x", start: d, end: d).progress(now: d) == 1)
    }

    @Test func remainingNeverGoesNegative() {
        #expect(sprint.remaining(now: date("2026-10-25T09:00:00.000Z")) == 86_400)
        #expect(sprint.remaining(now: date("2026-12-01T00:00:00.000Z")) == 0)
    }

    @Test func levelFollowsDaysLeft() {
        #expect(sprint.level(now: date("2026-10-15T09:00:00.000Z")) == .normal)
        #expect(sprint.level(now: date("2026-10-24T10:00:00.000Z")) == .warning)    // < 3 d
        #expect(sprint.level(now: date("2026-10-26T01:00:00.000Z")) == .critical)   // < 1 d
    }

    @Test func remainingLabel() {
        #expect(SprintInfo.remainingLabel(3 * 86_400 + 4 * 3600) == "3d 4h")
        #expect(SprintInfo.remainingLabel(5 * 3600 + 20 * 60) == "5h 20m")
        #expect(SprintInfo.remainingLabel(40 * 60) == "40m")
        #expect(SprintInfo.remainingLabel(0) == "terminada")
    }

    @Test func parsesJiraDateVariants() {
        #expect(SprintParser.parseDate("2026-10-12T09:00:00.000Z") != nil)
        #expect(SprintParser.parseDate("2026-10-12T09:00:00Z") != nil)
        #expect(SprintParser.parseDate("2026-10-12T10:00:00.000+0100") == SprintParser.parseDate("2026-10-12T09:00:00.000Z"))
        #expect(SprintParser.parseDate("2026-10-12T10:00:00.000+01:00") == SprintParser.parseDate("2026-10-12T09:00:00.000Z"))
        #expect(SprintParser.parseDate("not a date") == nil)
    }

    @Test func findsTheSprintFieldID() {
        let fields = """
        [{"id":"summary","name":"Summary","schema":{"type":"string"}},
         {"id":"customfield_10020","name":"Sprint","custom":true,"schema":{"type":"array","custom":"com.pyxis.greenhopper.jira:gh-sprint"}}]
        """
        #expect(SprintParser.sprintFieldID(Data(fields.utf8)) == "customfield_10020")
        #expect(SprintParser.sprintFieldID(Data("[]".utf8)) == nil)
        #expect(SprintParser.sprintFieldID(Data("junk".utf8)) == nil)
    }

    @Test func picksTheActiveSprintAmongCarryOvers() {
        let json = """
        {"issues":[{"key":"A-1","fields":{"customfield_10020":[
            {"id":1,"name":"Sprint 41","state":"closed","startDate":"2026-09-28T09:00:00.000Z","endDate":"2026-10-12T09:00:00.000Z"},
            {"id":2,"name":"Sprint 42","state":"active","startDate":"2026-10-12T09:00:00.000Z","endDate":"2026-10-26T09:00:00.000Z"}]}},
          {"key":"A-2","fields":{"customfield_10020":null}},
          {"key":"A-3","fields":{"customfield_10020":[
            {"id":2,"name":"Sprint 42","state":"active","startDate":"2026-10-12T09:00:00.000Z","endDate":"2026-10-26T09:00:00.000Z"}]}}]}
        """
        let found = SprintParser.activeSprint(Data(json.utf8), field: "customfield_10020")
        #expect(found?.name == "Sprint 42")
        #expect(found?.end == date("2026-10-26T09:00:00.000Z"))
    }

    @Test func noActiveSprintOrMissingDatesIsNil() {
        let closed = #"{"issues":[{"key":"A-1","fields":{"f":[{"name":"S","state":"closed","startDate":"2026-09-28T09:00:00.000Z","endDate":"2026-10-12T09:00:00.000Z"}]}}]}"#
        let noDates = #"{"issues":[{"key":"A-1","fields":{"f":[{"name":"S","state":"active"}]}}]}"#
        #expect(SprintParser.activeSprint(Data(closed.utf8), field: "f") == nil)
        #expect(SprintParser.activeSprint(Data(noDates.utf8), field: "f") == nil)
        #expect(SprintParser.activeSprint(Data("junk".utf8), field: "f") == nil)
    }

    @Test func savedLayoutKeepsTheSprintBlockAndFoldsOldApprovalsIntoJira() {
        let old = IslandLayoutConfig.decode(#"{"columns":[["claude","sprint","music"],["jiraApprovals","jira"]]}"#)
        #expect(old.columns[0].prefix(3) == [.claude, .sprint, .music])
        #expect(old.columns.flatMap { $0 }.filter { $0 == .jira }.count == 1)
        #expect(old.columns.flatMap { $0 }.count == IslandBlock.allCases.count)
    }

    @Test func tasksKnowWhetherTheyAreInTheActiveSprint() throws {
        let json = """
        {"issues":[
          {"key":"A-1","fields":{"summary":"in","status":{"name":"x"},"f":[{"name":"S","state":"active"}]}},
          {"key":"A-2","fields":{"summary":"carried","status":{"name":"x"},"f":[{"name":"S0","state":"closed"}]}},
          {"key":"A-3","fields":{"summary":"backlog","status":{"name":"x"},"f":null}}]}
        """
        let site = URL(string: "https://acme.atlassian.net")!
        let tasks = try JiraParser.parseTasks(Data(json.utf8), site: site, sprintField: "f")
        #expect(tasks.map(\.inActiveSprint) == [true, false, false])
        // Without the field id nothing is claimed.
        #expect(try JiraParser.parseTasks(Data(json.utf8), site: site).allSatisfy { $0.inActiveSprint == nil })
    }

    @Test func extractsJiraKeysFromPRTitles() {
        #expect(JiraKeys.extract(from: "refactor(TEP-2005): clean up") == ["TEP-2005"])
        #expect(JiraKeys.extract(from: "TEP-1 and TEP-22, again TEP-1") == ["TEP-1", "TEP-22"])   // in order, no repeats
        #expect(JiraKeys.extract(from: "feat: no key here, utf-8 and x-1 are not keys").isEmpty)
        #expect(JiraKeys.extract(from: "ABC-12345-extra") == ["ABC-12345"])
    }

    @Test func membershipMarksOnlyKeysInTheActiveSprint() {
        let json = """
        {"issues":[
          {"key":"A-1","fields":{"f":[{"name":"S","state":"active"}]}},
          {"key":"A-2","fields":{"f":[{"name":"S0","state":"closed"}]}},
          {"key":"A-3","fields":{"f":null}}]}
        """
        let result = SprintParser.membership(Data(json.utf8), field: "f")
        #expect(result == ["A-1": true, "A-2": false, "A-3": false])
        #expect(SprintParser.membership(Data("junk".utf8), field: "f").isEmpty)
    }
}

@Suite struct SprintBoardTests {
    private let json = """
    {"issues":[{"key":"A-1","fields":{"f":[
      {"id":7882,"name":"Sprint 19","state":"active","boardId":846,"startDate":"2026-10-27T12:00:00.000Z","endDate":"2026-11-09T11:00:00.000Z"},
      {"id":7648,"name":"SPRINT #18_Clínica","state":"active","boardId":483,"startDate":"2026-10-12T14:43:54.000Z","endDate":"2026-10-29T23:00:00.000Z"}]}}]}
    """

    @Test func withoutABoardTheLatestStartedWins() {
        #expect(SprintParser.activeSprint(Data(json.utf8), field: "f")?.name == "Sprint 19")
    }

    @Test func aBoardPicksItsSprintEvenPastItsEnd() {
        let sprint = SprintParser.activeSprint(Data(json.utf8), field: "f", board: 483)
        #expect(sprint?.name == "SPRINT #18_Clínica")
        #expect(sprint?.id == 7648)
        #expect(SprintParser.activeSprint(Data(json.utf8), field: "f", board: 999) == nil)
    }

    @Test func sprintTasksAreScopedToTheSprintIds() {
        #expect(JiraClient.sprintTasksJQL(field: "customfield_10000", sprintIDs: [7648, 7882]).hasPrefix("cf[10000] in (7648,7882) AND"))
    }

    @Test func oneSprintPerBoardAndOnlyTheChosenBoards() {
        let all = SprintParser.activeSprints(Data(json.utf8), field: "f")
        #expect(all.map(\.name) == ["SPRINT #18_Clínica", "Sprint 19"])
        let two = SprintParser.activeSprints(Data(json.utf8), field: "f", boards: [483])
        #expect(two.map(\.id) == [7648])
        #expect(SprintParser.activeSprints(Data(json.utf8), field: "f", boards: [1]).isEmpty)
    }

    @Test func parsesBoardsAndTheIdSetting() throws {
        let data = Data(#"{"isLast":true,"values":[{"id":483,"name":"Clínica","type":"scrum"},{"id":846,"name":"Plataforma"}]}"#.utf8)
        #expect(BoardParser.parse(data)?.boards == [JiraBoard(id: 483, name: "Clínica"), JiraBoard(id: 846, name: "Plataforma")])
        #expect(BoardParser.parseIDs("483, 846;x") == [483, 846])
        #expect(BoardParser.format([846, 483]) == "483,846")
    }

    @Test func tasksKeepTheirSprintIds() throws {
        let data = Data(#"{"issues":[{"key":"A-1","fields":{"summary":"x","f":[{"id":7648,"state":"active"},{"id":7351,"state":"closed"}]}}]}"#.utf8)
        let site = URL(string: "https://x.atlassian.net")!
        #expect(try JiraParser.parseTasks(data, site: site, sprintField: "f").first?.sprintIDs == [7648, 7351])
    }
}
