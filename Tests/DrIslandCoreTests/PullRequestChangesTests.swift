import Foundation
import Testing
@testable import DrIslandCore

@Suite struct PullRequestChangesTests {
    @Test func messagesStartWithTheirOrigin() {
        func message(_ kind: PRChange.Kind) -> String { PRChange(prID: "x", ref: "TEP-1", title: "t", kind: kind).message }
        #expect(message(.jiraComment) == "JIRA - Novo comentário em TEP-1")
        #expect(message(.approved) == "GIT - PR aprovado: TEP-1")
        #expect(message(.ciFailed).hasPrefix("GIT - "))
        #expect(message(.offline).hasPrefix("REDE - "))
        #expect(message(.briefing) == "RESUMO - t")
    }

    private func pr(_ n: Int, role: PullRequest.Role = .authored, ci: CIState = .pending, review: ReviewState = .none, conflicts: Bool = false) -> PullRequest {
        PullRequest(number: n, title: "PR \(n)", url: URL(string: "https://github.com/o/r/pull/\(n)")!, repository: "o/r",
                    isDraft: false, ci: ci, review: review, hasConflicts: conflicts, role: role)
    }
    private func snap(authored: [PullRequest] = [], review: [PullRequest] = []) -> PullRequestSnapshot {
        PullRequestSnapshot(authored: authored, reviewRequested: review)
    }
    private func kinds(_ changes: [PRChange]) -> [PRChange.Kind] { changes.map(\.kind) }

    @Test func myOwnCommentsDoNotRaiseNewComment() {
        func mine(comments: Int, own: Int) -> PullRequest {
            PullRequest(number: 9, title: "PR 9", url: URL(string: "https://github.com/o/r/pull/9")!, repository: "o/r", isDraft: false, ci: .none,
                        review: .none, hasConflicts: false, role: .authored, commentCount: comments, ownCommentCount: own)
        }
        let old = PullRequestDiff.fingerprints(of: snap(authored: [mine(comments: 4, own: 2)]))
        // Two more comments, both mine: nothing. One of theirs among them: alert.
        #expect(PullRequestDiff.changes(from: old, to: snap(authored: [mine(comments: 6, own: 4)])).isEmpty)
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap(authored: [mine(comments: 6, own: 3)]))) == [.newComment])
        // A cache from before the own count existed compares the total, as it always did.
        var legacy = old; legacy[0].ownCommentCount = nil
        #expect(kinds(PullRequestDiff.changes(from: legacy, to: snap(authored: [mine(comments: 5, own: 0)]))) == [.newComment])
    }

    @Test func alreadyReviewedPullRequestDoesNotRaiseNewReview() {
        let done = PullRequest(number: 3, title: "PR 3", url: URL(string: "https://github.com/o/r/pull/3")!, repository: "o/r",
                               isDraft: false, ci: .none, review: .approved, hasConflicts: false, role: .reviewRequested, reviewPending: false)
        let old = PullRequestDiff.fingerprints(of: snap())
        #expect(PullRequestDiff.changes(from: old, to: snap(review: [done])).isEmpty)
        // A request that is still pending keeps alerting even when others already rejected the PR.
        let pending = pr(4, role: .reviewRequested, review: .changesRequested)
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap(review: [pending]))) == [.reviewRequested])
    }

    @Test func pullRequestStillOpenButUnlistedIsNotAnnouncedAsClosed() {
        let old = PullRequestDiff.fingerprints(of: snap(review: [pr(5, role: .reviewRequested)]))
        let now = PullRequestSnapshot(unlistedOpenIDs: ["https://github.com/o/r/pull/5"])
        #expect(PullRequestDiff.changes(from: old, to: now).isEmpty)
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap())) == [.left])
    }

    @Test func noCacheIsOnlyABaseline() {
        #expect(PullRequestDiff.changes(from: nil, to: snap(authored: [pr(1, ci: .failing)], review: [pr(2, role: .reviewRequested)])).isEmpty)
    }

    @Test func unchangedReportsNothing() {
        let s = snap(authored: [pr(1, ci: .passing)], review: [pr(2, role: .reviewRequested)])
        #expect(PullRequestDiff.changes(from: PullRequestDiff.fingerprints(of: s), to: s).isEmpty)
    }

    @Test func newReviewRequestIsReportedButNewOwnPRIsNot() {
        let old = PullRequestDiff.fingerprints(of: snap())
        let changes = PullRequestDiff.changes(from: old, to: snap(authored: [pr(1)], review: [pr(2, role: .reviewRequested)]))
        #expect(kinds(changes) == [.reviewRequested])
        #expect(changes.first?.ref == "r#2")
    }

    @Test func ciReviewAndConflictTransitionsOnOwnPRs() {
        let old = PullRequestDiff.fingerprints(of: snap(authored: [pr(1, ci: .pending)]))
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap(authored: [pr(1, ci: .failing)]))) == [.ciFailed])
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap(authored: [pr(1, ci: .passing)]))) == [.ciPassed])
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap(authored: [pr(1, review: .approved)]))) == [.approved])
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap(authored: [pr(1, review: .changesRequested)]))) == [.changesRequested])
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap(authored: [pr(1, conflicts: true)]))) == [.conflicts])
    }

    @Test func alreadyFailingDoesNotRepeat() {
        let s = snap(authored: [pr(1, ci: .failing)])
        #expect(PullRequestDiff.changes(from: PullRequestDiff.fingerprints(of: s), to: s).isEmpty)
    }

    @Test func reviewRequestsOnlyReportArrivalAndDeparture() {
        let old = PullRequestDiff.fingerprints(of: snap(review: [pr(2, role: .reviewRequested, ci: .pending)]))
        #expect(PullRequestDiff.changes(from: old, to: snap(review: [pr(2, role: .reviewRequested, ci: .failing)])).isEmpty)
        #expect(kinds(PullRequestDiff.changes(from: old, to: snap())) == [.left])
    }

    @Test func removedPRIsReportedAsLeft() {
        let old = PullRequestDiff.fingerprints(of: snap(authored: [pr(1)]))
        let changes = PullRequestDiff.changes(from: old, to: snap())
        #expect(kinds(changes) == [.left])
        #expect(changes.first?.tone == .neutral)
    }

    @Test func toneOrderingPutsFailuresFirst() {
        #expect(PRChange.Tone.critical > .warning && PRChange.Tone.warning > .info && PRChange.Tone.info > .success)
    }

    @Test func unknownMergeabilityKeepsThePreviousConflictState() {
        func pr(_ conflicts: Bool, known: Bool) -> PullRequest {
            PullRequest(number: 1, title: "t", url: URL(string: "https://github.com/o/r/pull/1")!, repository: "o/r", isDraft: false,
                        ci: .passing, review: .none, hasConflicts: conflicts, role: .authored, conflictsKnown: known)
        }
        let before = PullRequestDiff.fingerprints(of: PullRequestSnapshot(authored: [pr(true, known: true)]))
        let unknown = PullRequestSnapshot(authored: [pr(false, known: false)]).resolvingUnknownConflicts(using: before)
        #expect(unknown.authored[0].hasConflicts)
        let known = PullRequestSnapshot(authored: [pr(false, known: true)]).resolvingUnknownConflicts(using: before)
        #expect(!known.authored[0].hasConflicts)
    }
}
