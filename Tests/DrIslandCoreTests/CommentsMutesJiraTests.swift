import Foundation
import Testing
@testable import DrIslandCore

@Suite struct CommentsMutesJiraTests {
    private func pr(_ n: Int, role: PullRequest.Role = .authored, comments: Int? = nil, repo: String = "o/r") -> PullRequest {
        PullRequest(number: n, title: "PR \(n)", url: URL(string: "https://github.com/\(repo)/pull/\(n)")!, repository: repo,
                    isDraft: false, ci: .pending, review: .none, hasConflicts: false, role: role, commentCount: comments)
    }
    private func kinds(_ c: [PRChange]) -> [PRChange.Kind] { c.map(\.kind) }

    @Test func newCommentOnOwnPR() {
        let old = PullRequestDiff.fingerprints(of: PullRequestSnapshot(authored: [pr(1, comments: 2)]))
        let now = PullRequestSnapshot(authored: [pr(1, comments: 3)])
        #expect(kinds(PullRequestDiff.changes(from: old, to: now)) == [.newComment])
    }

    @Test func unknownEarlierCountIsNotAComment() {
        let old = PullRequestDiff.fingerprints(of: PullRequestSnapshot(authored: [pr(1, comments: nil)]))
        #expect(PullRequestDiff.changes(from: old, to: PullRequestSnapshot(authored: [pr(1, comments: 5)])).isEmpty)
    }

    @Test func mentionAppearsThenCommentsOnIt() {
        let old = PullRequestDiff.fingerprints(of: PullRequestSnapshot())
        let first = PullRequestSnapshot(mentions: [pr(7, role: .mentioned, comments: 1)])
        #expect(kinds(PullRequestDiff.changes(from: old, to: first)) == [.mentioned])
        let more = PullRequestSnapshot(mentions: [pr(7, role: .mentioned, comments: 2)])
        #expect(kinds(PullRequestDiff.changes(from: PullRequestDiff.fingerprints(of: first), to: more)) == [.newComment])
        // A mention leaving the results is not worth an alert.
        #expect(PullRequestDiff.changes(from: PullRequestDiff.fingerprints(of: first), to: PullRequestSnapshot()).isEmpty)
    }

    @Test func mergedVersusClosed() {
        let p = pr(1)
        let old = PullRequestDiff.fingerprints(of: PullRequestSnapshot(authored: [p]))
        #expect(kinds(PullRequestDiff.changes(from: old, to: PullRequestSnapshot(mergedIDs: [p.id]))) == [.merged])
        #expect(kinds(PullRequestDiff.changes(from: old, to: PullRequestSnapshot())) == [.left])
    }

    @Test func mutesByPRAndRepository() {
        let a = pr(1), b = pr(2, repo: "o/other")
        let byPR = PRMutes.adding(.pr(a, until: nil), to: [])
        #expect(PRMutes.isMuted(prID: a.id, in: byPR))
        #expect(!PRMutes.isMuted(prID: b.id, in: byPR))
        let byRepo = PRMutes.adding(.repository(a, until: nil), to: [])
        #expect(PRMutes.isMuted(prID: pr(9).id, in: byRepo))
        #expect(!PRMutes.isMuted(prID: b.id, in: byRepo))
    }

    @Test func expiredMutesDoNothing() {
        let a = pr(1)
        let expired = [PRMute.pr(a, until: Date().addingTimeInterval(-10))]
        #expect(!PRMutes.isMuted(prID: a.id, in: expired))
        #expect(PRMutes.decode(PRMutes.encode(expired)) == expired)
        #expect(PRMutes.adding(.pr(pr(2), until: nil), to: expired).count == 1)
    }

    @Test func emptyListsAfterNonEmptyOnesLookTruncated() {
        let old = PullRequestDiff.fingerprints(of: PullRequestSnapshot(authored: [pr(1, comments: 0)], reviewRequested: [pr(2, role: .reviewRequested, comments: 0)]))
        #expect(PullRequestSnapshot().looksTruncated(comparedTo: old))
        #expect(PullRequestSnapshot(authored: [pr(1, comments: 0)]).looksTruncated(comparedTo: old))
        #expect(PullRequestSnapshot(reviewRequested: [pr(2, role: .reviewRequested, comments: 0)]).looksTruncated(comparedTo: old))
        #expect(!PullRequestSnapshot(authored: [pr(1, comments: 0)], reviewRequested: [pr(2, role: .reviewRequested, comments: 0)]).looksTruncated(comparedTo: old))
        #expect(!PullRequestSnapshot().looksTruncated(comparedTo: nil))
        #expect(!PullRequestSnapshot().looksTruncated(comparedTo: []))
    }

    // MARK: Jira

    private func task(_ key: String, _ status: String = "To Do", comments: Int? = 0, approvers: [String]? = nil) -> JiraTask {
        JiraTask(key: key, summary: "S \(key)", status: status, category: .todo, priority: nil,
                 url: URL(string: "https://x.atlassian.net/browse/\(key)")!, commentCount: comments, approvers: approvers)
    }

    @Test func jiraIgnoresMyOwnComments() {
        func t(total: Int, authors: [String]) -> JiraTask {
            JiraTask(key: "A-1", summary: "S", status: "To Do", category: .todo, priority: nil,
                     url: URL(string: "https://x.atlassian.net/browse/A-1")!, commentCount: total, commentAuthors: authors)
        }
        let old = JiraDiff.fingerprints(of: [t(total: 1, authors: ["Ana"])], me: "Eu")
        // I commented: not an alert. Someone else did: alert.
        #expect(JiraDiff.changes(from: old, to: [t(total: 2, authors: ["Ana", "Eu"])], me: "Eu").isEmpty)
        #expect(JiraDiff.changes(from: old, to: [t(total: 2, authors: ["Ana", "Rui"])], me: "Eu").map(\.kind) == [.jiraComment])
        // Cache from before the own count existed: no alert for what was already there.
        var legacy = old; legacy[0].ownCommentCount = nil
        #expect(JiraDiff.changes(from: legacy, to: [t(total: 1, authors: ["Ana"])], me: "Eu").isEmpty)
    }

    @Test func jiraChanges() {
        #expect(JiraDiff.changes(from: nil, to: [task("A-1")]).isEmpty)
        let old = JiraDiff.fingerprints(of: [task("A-1")])
        #expect(kinds(JiraDiff.changes(from: old, to: [task("A-1"), task("A-2")])) == [.jiraNew])
        let moved = JiraDiff.changes(from: old, to: [task("A-1", "In Review")])
        #expect(kinds(moved) == [.jiraStatus])
        #expect(moved.first?.message == "JIRA - A-1 passou a «In Review»")
        #expect(kinds(JiraDiff.changes(from: old, to: [task("A-1", comments: 1)])) == [.jiraComment])
        #expect(JiraDiff.changes(from: old, to: [task("A-1")]).isEmpty)
    }

    @Test func jiraApproverChanges() {
        let old = JiraDiff.fingerprints(of: [task("A-1", approvers: ["Ana"])])
        let added = JiraDiff.changes(from: old, to: [task("A-1", approvers: ["Ana", "Rui"])])
        #expect(kinds(added) == [.jiraApprovers])
        #expect(added.first?.message == "JIRA - Aprovadores de A-1: Ana, Rui")
        #expect(kinds(JiraDiff.changes(from: old, to: [task("A-1", approvers: [])])) == [.jiraApprovers])
        #expect(JiraDiff.changes(from: old, to: [task("A-1", approvers: ["Ana"])]).isEmpty)
        // Stored before approvers were tracked (or the field not returned): nothing to compare, nothing announced.
        let legacy = JiraDiff.fingerprints(of: [task("A-1")])
        #expect(JiraDiff.changes(from: legacy, to: [task("A-1", approvers: ["Ana"])]).isEmpty)
    }
}

@Suite struct SprintGoalTests {
    @Test func detectsLabelLoosely() {
        func task(_ labels: [String]) -> JiraTask {
            JiraTask(key: "T-1", summary: "s", status: "x", category: .todo, priority: nil, url: URL(string: "https://x.test")!, labels: labels)
        }
        #expect(task(["Frontend", "Sprint_Goal"]).isSprintGoal)
        #expect(task(["sprint-goal"]).isSprintGoal)
        #expect(!task(["Frontend"]).isSprintGoal)
        #expect(!task([]).isSprintGoal)
    }
}

@Suite struct JiraOrderTests {
    @Test func sprintGoalThenInProgressThenRest() {
        func t(_ key: String, _ cat: JiraTask.Category, _ labels: [String] = []) -> JiraTask {
            JiraTask(key: key, summary: "s", status: "x", category: cat, priority: nil, url: URL(string: "https://x.test")!, labels: labels)
        }
        let sorted = JiraOrder.sorted([t("A", .todo), t("B", .inProgress), t("C", .todo, ["Sprint_Goal"]), t("D", .inProgress), t("E", .todo)])
        #expect(sorted.map(\.key) == ["C", "B", "D", "A", "E"])
    }
}
