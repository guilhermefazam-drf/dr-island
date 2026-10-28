import Testing
import Foundation
@testable import DrIslandCore

@Suite struct GitHubParsingTests {
    private let sample = """
    {"data":{
      "authored":{"nodes":[
        {"number":12,"title":"Fix login","url":"https://github.com/acme/app/pull/12","isDraft":false,
         "reviewDecision":"CHANGES_REQUESTED","mergeable":"MERGEABLE","repository":{"nameWithOwner":"acme/app"},
         "commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}},
        {"number":13,"title":"WIP thing","url":"https://github.com/acme/app/pull/13","isDraft":true,
         "reviewDecision":null,"mergeable":"CONFLICTING","repository":{"nameWithOwner":"acme/app"},
         "commits":{"nodes":[{"commit":{"statusCheckRollup":null}}]}},
        {"number":14,"title":"Broken CI","url":"https://github.com/acme/api/pull/14","isDraft":false,
         "reviewDecision":"APPROVED","mergeable":"MERGEABLE","repository":{"nameWithOwner":"acme/api"},
         "commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"FAILURE"}}}]}},
        {}
      ]},
      "review":{"nodes":[
        {"number":99,"title":"Review me","url":"https://github.com/acme/web/pull/99","isDraft":false,
         "reviewDecision":"REVIEW_REQUIRED","mergeable":"UNKNOWN","repository":{"nameWithOwner":"acme/web"},
         "commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}}
      ]}
    }}
    """

    @Test func parsesStatesAndSkipsEmptyNodes() throws {
        let snap = try GitHubParser.parse(Data(sample.utf8))
        #expect(snap.authored.count == 3)
        #expect(snap.authored[0].review == .changesRequested && snap.authored[0].ci == .passing)
        #expect(snap.authored[1].isDraft && snap.authored[1].hasConflicts && snap.authored[1].ci == .none)
        #expect(snap.authored[2].ci == .failing && snap.authored[2].repository == "acme/api")
        #expect(snap.reviewRequested.count == 1)
        #expect(snap.reviewRequested[0].ci == .pending && snap.reviewRequested[0].review == .reviewRequired)
    }

    @Test func keepsMyVerdictOnPullRequestsIAlreadyReviewed() throws {
        func node(_ n: Int, _ state: String) -> String {
            #"{"number":\#(n),"title":"t","url":"https://github.com/a/b/pull/\#(n)","state":"OPEN","reviewDecision":"REVIEW_REQUIRED","repository":{"nameWithOwner":"a/b"},"latestOpinionatedReviews":{"nodes":[{"state":"\#(state)","author":{"login":"Me"}},{"state":"CHANGES_REQUESTED","author":{"login":"other"}}]}}"#
        }
        let json = #"{"data":{"viewer":{"login":"me"},"review":{"nodes":[\#(node(1, "COMMENTED"))]},"reviewed":{"nodes":[\#(node(1, "COMMENTED")),\#(node(2, "APPROVED")),\#(node(3, "CHANGES_REQUESTED"))]}}}"#
        let snap = try GitHubParser.parse(Data(json.utf8))
        #expect(snap.reviewRequested.map(\.number) == [1, 2, 3])
        #expect(snap.reviewRequested.map(\.review) == [.reviewRequired, .approved, .changesRequested])
        // My approval is not the PR's: nobody else has approved, so the PR itself is still waiting.
        #expect(snap.reviewRequested[1].teamReview == .reviewRequired)
    }

    @Test func reviewedWithoutVerdictOrRequestIsNotListed() throws {
        func node(_ n: Int, _ state: String) -> String {
            #"{"number":\#(n),"title":"t","url":"https://github.com/a/b/pull/\#(n)","state":"OPEN","reviewDecision":"CHANGES_REQUESTED","repository":{"nameWithOwner":"a/b"},"latestOpinionatedReviews":{"nodes":[{"state":"\#(state)","author":{"login":"me"}}]}}"#
        }
        // 1 is requested; 2 only commented; 3 approved; 4 was approved by someone else only.
        let json = #"{"data":{"viewer":{"login":"me"},"review":{"nodes":[\#(node(1, "COMMENTED"))]},"reviewed":{"nodes":[\#(node(2, "COMMENTED")),\#(node(3, "APPROVED")),\#(node(4, "DISMISSED"))]}}}"#
        let snap = try GitHubParser.parse(Data(json.utf8))
        #expect(snap.reviewRequested.map(\.number) == [1, 3])
        #expect(snap.reviewRequested.map(\.reviewPending) == [true, false])
        #expect(snap.unlistedOpenIDs == ["https://github.com/a/b/pull/2", "https://github.com/a/b/pull/4"])
    }

    @Test func approvedNeedsTwoPeopleAndCodeRabbit() throws {
        func node(_ n: Int, _ decision: String, _ reviews: [(String, String)]) -> String {
            let list = reviews.map { #"{"state":"\#($0.1)","author":{"login":"\#($0.0)"}}"# }.joined(separator: ",")
            return #"{"number":\#(n),"title":"t","url":"https://github.com/a/b/pull/\#(n)","state":"OPEN","reviewDecision":"\#(decision)","repository":{"nameWithOwner":"a/b"},"latestOpinionatedReviews":{"nodes":[\#(list)]}}"#
        }
        let nodes = [
            node(1, "APPROVED", [("ana", "APPROVED")]),                                                     // one person: not enough
            node(2, "APPROVED", [("ana", "APPROVED"), ("rui", "APPROVED")]),                                 // no CodeRabbit
            node(3, "APPROVED", [("ana", "APPROVED"), ("coderabbitai", "APPROVED")]),                        // only one person
            node(4, "APPROVED", [("ana", "APPROVED"), ("rui", "APPROVED"), ("coderabbitai", "APPROVED")]),   // the bar
            node(5, "REVIEW_REQUIRED", [("ana", "APPROVED"), ("rui", "APPROVED"), ("CodeRabbitAI", "APPROVED")]),
            node(6, "CHANGES_REQUESTED", [("ana", "APPROVED"), ("rui", "APPROVED"), ("coderabbitai", "CHANGES_REQUESTED")]),   // a requested change wins
            node(7, "APPROVED", [("ana", "APPROVED"), ("rui", "APPROVED"), ("coderabbitai", "COMMENTED")]),
        ].joined(separator: ",")
        let snap = try GitHubParser.parse(Data(#"{"data":{"authored":{"nodes":[\#(nodes)]}}}"#.utf8))
        #expect(snap.authored.map(\.review) == [.reviewRequired, .reviewRequired, .reviewRequired, .approved, .approved, .changesRequested, .reviewRequired])
    }

    @Test func countsMyOwnCommentsOnAPullRequest() throws {
        let node = #"{"number":1,"title":"t","url":"https://github.com/a/b/pull/1","state":"OPEN","totalCommentsCount":6,"repository":{"nameWithOwner":"a/b"},"comments":{"nodes":[{"author":{"login":"coderabbitai"}},{"author":{"login":"Me"}}]},"reviews":{"nodes":[{"author":{"login":"me"},"body":""},{"author":{"login":"me"},"body":"ok"},{"author":{"login":"ana"},"body":"x"}]},"reviewThreads":{"nodes":[{"comments":{"nodes":[{"author":{"login":"ana"}},{"author":{"login":"me"}}]}}]}}"#
        let snap = try GitHubParser.parse(Data(#"{"data":{"viewer":{"login":"me"},"authored":{"nodes":[\#(node)]}}}"#.utf8))
        // conversation 1 + review body 1 + inline 1
        #expect(snap.authored[0].ownCommentCount == 3)
    }

    @Test func ownerLabelsAreMeOrInitials() {
        #expect(Owner.label(name: "Luís Pedro Bettencourt Costa", isMine: false) == "LC")
        #expect(Owner.label(name: "luisinhoc", isMine: false) == "LU")
        #expect(Owner.label(name: "Guilherme Fazam", isMine: true) == "eu")
        #expect(Owner.label(name: nil, isMine: false) == nil)
    }

    @Test func pullRequestsKnowTheirAuthor() throws {
        func node(_ n: Int, _ author: String) -> String {
            #"{"number":\#(n),"title":"t","url":"https://github.com/a/b/pull/\#(n)","state":"OPEN","reviewDecision":"REVIEW_REQUIRED","repository":{"nameWithOwner":"a/b"},"author":\#(author)}"#
        }
        let json = #"{"data":{"viewer":{"login":"me"},"authored":{"nodes":[\#(node(1, #"{"login":"me","name":"Eu Mesmo"}"#))]},"review":{"nodes":[\#(node(2, #"{"login":"luisinhoc","name":"Luís Costa"}"#)),\#(node(3, #"{"login":"bot"}"#))]}}}"#
        let snap = try GitHubParser.parse(Data(json.utf8))
        #expect(snap.authored[0].isMine && snap.authored[0].author == "Eu Mesmo")
        #expect(snap.reviewRequested.map(\.isMine) == [false, false])
        #expect(snap.reviewRequested.map(\.author) == ["Luís Costa", "bot"])
    }

    @Test func attentionLevels() throws {
        let snap = try GitHubParser.parse(Data(sample.utf8))
        #expect(snap.authored[0].attention == .warning)   // changes requested
        #expect(snap.authored[1].attention == .warning)   // conflicts
        #expect(snap.authored[2].attention == .critical)  // CI failing
        #expect(snap.reviewRequested[0].attention == .none)
        #expect(snap.attention == .critical)
    }

    @Test func dropsMergedAndClosedPullRequests() throws {
        func node(_ number: Int, _ state: String) -> String {
            #"{"number":\#(number),"title":"t","url":"https://github.com/a/b/pull/\#(number)","state":"\#(state)","repository":{"nameWithOwner":"a/b"}}"#
        }
        let json = #"{"data":{"authored":{"nodes":[\#(node(1, "OPEN")),\#(node(2, "MERGED")),\#(node(3, "CLOSED"))]},"review":{"nodes":[\#(node(4, "MERGED")),\#(node(5, "OPEN"))]}}}"#
        let snap = try GitHubParser.parse(Data(json.utf8))
        #expect(snap.authored.map(\.number) == [1])
        #expect(snap.reviewRequested.map(\.number) == [5])
    }

    @Test func missingReviewAliasIsEmpty() throws {
        let snap = try GitHubParser.parse(Data(#"{"data":{"authored":{"nodes":[]}}}"#.utf8))
        #expect(snap.authored.isEmpty && snap.reviewRequested.isEmpty && snap.attention == .none)
    }

    @Test func invalidPayloadThrows() {
        #expect(throws: Error.self) { try GitHubParser.parse(Data(#"{"errors":[]}"#.utf8)) }
    }
}

@Suite struct GitHubQueryTests {
    @Test func scopeQualifiers() {
        #expect(GitHubClient.scopeQualifiers("") == "")
        #expect(GitHubClient.scopeQualifiers("acme, acme/app") == "org:acme repo:acme/app")
        #expect(GitHubClient.scopeQualifiers("ok, bad one;rm") == "org:ok")
    }

    @Test func argumentsIncludeReviewOnlyWhenEnabled() {
        let on = GitHubClient.arguments(for: .init(includeReviewRequests: true, scope: "acme"))
        #expect(on.contains("r=review-requested:@me is:pr is:open archived:false sort:updated-desc org:acme"))
        #expect(on.contains("a=author:@me is:pr is:open archived:false sort:updated-desc org:acme"))
        let off = GitHubClient.arguments(for: .init(includeReviewRequests: false))
        #expect(!off.contains { $0.hasPrefix("r=") })
        #expect(!(off.last ?? "").contains("review:"))
    }

    @Test func limitIsClamped() {
        #expect(GitHubClient.arguments(for: .init(limit: 500)).contains("n=50"))
        #expect(GitHubClient.arguments(for: .init(limit: 0)).contains("n=1"))
    }

    @Test func errorClassification() {
        #expect(GitHubClient.classify(stderr: "To get started with GitHub CLI, please run:  gh auth login", status: 4) == .notAuthenticated)
        #expect(GitHubClient.classify(stderr: "HTTP 401: Bad credentials", status: 1) == .notAuthenticated)
        #expect(GitHubClient.classify(stderr: "boom\nmore", status: 1) == .failed("boom"))
    }
}
