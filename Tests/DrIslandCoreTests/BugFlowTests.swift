import Testing
import Foundation
@testable import DrIslandCore

@Suite struct BugFlowTests {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func date(_ iso: String) -> Date { SprintParser.parseDate(iso)! }
    // Friday 2026-10-30: the current week starts on Monday 2026-10-26.
    private let now = SprintParser.parseDate("2026-10-30T12:00:00.000Z")!

    @Test func weeksStartOnMondayAndTheLastOneIsThisWeek() {
        let result = BugFlow.compute([], openNow: 0, openIsCapped: false, now: now, calendar: calendar)
        #expect(result.weeks.count == 8)
        #expect(result.weeks.last?.start == date("2026-10-26T00:00:00.000Z"))
        #expect(result.weeks.first?.start == date("2026-09-07T00:00:00.000Z"))
    }

    @Test func countsCreatedAndResolvedInTheirOwnWeek() {
        let bugs = [
            BugRecord(key: "B-1", created: date("2026-10-27T10:00:00.000Z"), resolved: date("2026-10-29T10:00:00.000Z")),   // this week, resolved this week
            BugRecord(key: "B-2", created: date("2026-10-20T10:00:00.000Z"), resolved: date("2026-10-27T09:00:00.000Z")),   // last week, resolved this week
            BugRecord(key: "B-3", created: date("2026-10-21T10:00:00.000Z"), resolved: nil),
        ]
        let weeks = BugFlow.compute(bugs, openNow: 1, openIsCapped: false, now: now, calendar: calendar).weeks
        #expect(weeks[7].created == 1 && weeks[7].resolved == 2)
        #expect(weeks[6].created == 2 && weeks[6].resolved == 0)
    }

    @Test func bugsOlderThanTheWindowAreIgnored() {
        let old = BugRecord(key: "B-1", created: date("2026-01-05T10:00:00.000Z"), resolved: date("2026-01-06T10:00:00.000Z"))
        let result = BugFlow.compute([old], openNow: 0, openIsCapped: false, now: now, calendar: calendar)
        #expect(result.weeks.allSatisfy { $0.created == 0 && $0.resolved == 0 })
        #expect(result.medianDaysToResolve == nil)
    }

    @Test func medianDaysToResolve() {
        let bugs = [
            BugRecord(key: "B-1", created: date("2026-10-26T00:00:00.000Z"), resolved: date("2026-10-27T00:00:00.000Z")),   // 1 day
            BugRecord(key: "B-2", created: date("2026-10-20T00:00:00.000Z"), resolved: date("2026-10-27T00:00:00.000Z")),   // 7 days
            BugRecord(key: "B-3", created: date("2026-10-23T00:00:00.000Z"), resolved: date("2026-10-27T00:00:00.000Z")),   // 4 days
        ]
        #expect(BugFlow.compute(bugs, openNow: 0, openIsCapped: false, now: now, calendar: calendar).medianDaysToResolve == 4)
    }

    @Test func openCountIsPassedThrough() {
        let result = BugFlow.compute([], openNow: 100, openIsCapped: true, now: now, calendar: calendar)
        #expect(result.openNow == 100 && result.openIsCapped)
    }
}

@Suite struct BugsClientTests {
    @Test func bugTypesAreFoundByTheSameRuleAsTheTaskRows() {
        let json = #"[{"id":"1","name":"Problema","subtask":false},{"id":"2","name":"História","subtask":false},{"id":"3","name":"Bug","subtask":true},{"id":"4","name":"Erro","subtask":false}]"#
        #expect(BugsParser.bugTypeIDs(Data(json.utf8)) == ["1", "4"])
    }

    @Test func parsesCreatedAndResolutionDatesAndSkipsBrokenOnes() throws {
        let json = #"{"issues":[{"key":"B-1","fields":{"created":"2026-10-20T09:00:00.000+0000","resolutiondate":"2026-10-22T09:00:00.000+0000"}},{"key":"B-2","fields":{"created":"2026-10-21T09:00:00.000+0000","resolutiondate":null}},{"key":"B-3","fields":{}}]}"#
        let records = try #require(BugsParser.records(Data(json.utf8)))
        #expect(records.map(\.key) == ["B-1", "B-2"])
        #expect(records[0].resolved != nil && records[1].resolved == nil)
    }

    @Test func queriesAreScopedToTheProjectAndTheBugTypes() {
        #expect(BugsRequests.recentJQL(project: "TEP", typeIDs: ["1", "4"], weeks: 8) == "project = TEP AND issuetype in (1,4) AND (created >= -9w OR resolved >= -9w) ORDER BY created ASC")
        #expect(BugsRequests.openJQL(project: "TEP", typeIDs: ["1"]) == "project = TEP AND issuetype in (1) AND resolution = Unresolved")
    }

    @Test func searchURLAsksOnlyForTheDates() throws {
        let url = try #require(BugsRequests.searchURL(site: URL(string: "https://x.atlassian.net")!, jql: "project = TEP", pageToken: "abc"))
        #expect(url.absoluteString.contains("fields=created,resolutiondate"))
        #expect(url.absoluteString.contains("nextPageToken=abc"))
    }
}
