import Foundation

public enum CIState: String, Codable, Equatable, Sendable { case passing, failing, pending, none }
public enum ReviewState: String, Codable, Equatable, Sendable { case approved, changesRequested, reviewRequired, none }

public struct PullRequest: Equatable, Identifiable, Sendable {
    public enum Role: String, Codable, Equatable, Sendable { case authored, reviewRequested, mentioned }
    public enum Attention: Int, Comparable, Sendable {
        case none = 0, warning, critical
        public static func < (a: Attention, b: Attention) -> Bool { a.rawValue < b.rawValue }
    }

    public var id: String { url.absoluteString }
    public let number: Int
    public let title: String
    public let url: URL
    public let repository: String
    public let isDraft: Bool
    public let ci: CIState
    public let review: ReviewState
    /// The PR's overall state under the approval bar (see `GitHubParser.overallReview`). For a review request `review` is the
    /// user's own verdict, which can be an approval while the others are still pending; this is what "approved" means for the PR.
    public let teamReview: ReviewState
    /// Who opened it (their name, or their login when they have none), and whether that is the user.
    public let author: String?
    /// Comments the user wrote themselves (conversation, inline and review bodies), nil when unknown. A rise in the
    /// others' comments is what counts as a "new comment".
    public let ownCommentCount: Int?
    public let isMine: Bool
    public let hasConflicts: Bool
    /// False while GitHub is still computing mergeability (`UNKNOWN`): `hasConflicts` then says nothing either way.
    public let conflictsKnown: Bool
    public let role: Role
    /// Comments on the PR (nil when unknown); a rise is reported as a new comment.
    public let commentCount: Int?
    /// False for a PR the user already approved or rejected and that no longer asks for their review: it stays listed
    /// but is not a review request, so it never raises the "novo review" alert.
    public let reviewPending: Bool

    public init(number: Int, title: String, url: URL, repository: String, isDraft: Bool,
                ci: CIState, review: ReviewState, hasConflicts: Bool, role: Role, commentCount: Int? = nil, conflictsKnown: Bool = true, reviewPending: Bool = true, teamReview: ReviewState? = nil, author: String? = nil, isMine: Bool? = nil, ownCommentCount: Int? = nil, unresolvedThreadCount: Int? = nil) {
        self.ownCommentCount = ownCommentCount
        self.unresolvedThreadCount = unresolvedThreadCount
        self.author = author
        self.isMine = isMine ?? (role == .authored)
        self.teamReview = teamReview ?? review
        self.reviewPending = reviewPending
        self.commentCount = commentCount
        self.conflictsKnown = conflictsKnown
        self.number = number; self.title = title; self.url = url; self.repository = repository
        self.isDraft = isDraft; self.ci = ci; self.review = review; self.hasConflicts = hasConflicts; self.role = role
    }

    /// Review threads still open that someone else started (nil when unknown), shown as a fixed badge on the row.
    public let unresolvedThreadCount: Int?

    /// Only the user's own PRs can "need attention"; review requests are just listed.
    public var attention: Attention {
        guard role == .authored else { return .none }
        if ci == .failing { return .critical }
        if review == .changesRequested || hasConflicts { return .warning }
        return .none
    }
}

public struct PullRequestSnapshot: Equatable, Sendable {
    public var authored: [PullRequest]
    public var reviewRequested: [PullRequest]
    /// Other people's PRs where the user was mentioned (tracked for alerts only, never listed).
    public var mentions: [PullRequest]
    /// URLs of the user's recently merged PRs, to tell "merged" from "closed" when a PR leaves the open list.
    public var mergedIDs: Set<String>
    /// Open PRs the user reviewed that are no longer listed (no pending request, no approval or rejection of theirs).
    /// They are not gone, so dropping out of the list must not be announced as "fechado".
    public var unlistedOpenIDs: Set<String>
    public init(authored: [PullRequest] = [], reviewRequested: [PullRequest] = [], mentions: [PullRequest] = [], mergedIDs: Set<String> = [], unlistedOpenIDs: Set<String> = []) {
        self.unlistedOpenIDs = unlistedOpenIDs
        self.authored = authored; self.reviewRequested = reviewRequested; self.mentions = mentions; self.mergedIDs = mergedIDs
    }

    public var attention: PullRequest.Attention { authored.map(\.attention).max() ?? .none }

    /// A PR whose mergeability GitHub is still computing keeps the conflict state it had in the last reading, so it
    /// does not flip off and on (which announced "Conflitos" again each time it came back).
    public func resolvingUnknownConflicts(using old: [PRFingerprint]?) -> PullRequestSnapshot {
        guard let old else { return self }
        let previous = Dictionary(old.map { ($0.id, $0.hasConflicts) }, uniquingKeysWith: { first, _ in first })
        func fixed(_ list: [PullRequest]) -> [PullRequest] {
            list.map { pr in
                guard !pr.conflictsKnown, let was = previous[pr.id], was != pr.hasConflicts else { return pr }
                return PullRequest(number: pr.number, title: pr.title, url: pr.url, repository: pr.repository, isDraft: pr.isDraft,
                                   ci: pr.ci, review: pr.review, hasConflicts: was, role: pr.role, commentCount: pr.commentCount, conflictsKnown: false, reviewPending: pr.reviewPending, teamReview: pr.teamReview, author: pr.author, isMine: pr.isMine, ownCommentCount: pr.ownCommentCount, unresolvedThreadCount: pr.unresolvedThreadCount)
            }
        }
        var copy = self
        copy.authored = fixed(authored); copy.reviewRequested = fixed(reviewRequested); copy.mentions = fixed(mentions)
        return copy
    }

    /// GitHub's search sometimes answers `200` with an empty list for a query that has results (seen a few times in a
    /// dozen calls). A list that was not empty last time and is empty now is more likely that than every PR closing at once.
    public func looksTruncated(comparedTo old: [PRFingerprint]?) -> Bool {
        guard let old else { return false }
        return (authored.isEmpty && old.contains { $0.role == .authored })
            || (reviewRequested.isEmpty && old.contains { $0.role == .reviewRequested })
    }
}

public enum GitHubParser {
    public enum ParseError: Error { case invalidJSON }

    /// Parses the `gh api graphql` response built by `GitHubClient` (aliases `authored` and `review`).
    public static func parse(_ data: Data) throws -> PullRequestSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any] else { throw ParseError.invalidJSON }
        let me = ((payload["viewer"] as? [String: Any])?["login"] as? String)
        let authored = pullRequests(in: payload["authored"], role: .authored, viewer: me)
        var review = pullRequests(in: payload["review"], role: .reviewRequested, reviewer: me, viewer: me)
        let requested = Set(review.map(\.id))
        // `reviewed-by` also matches PRs the user only commented on or whose review was dismissed: without their own
        // approval or rejection they were never asked for a review, so they stay out.
        review += pullRequests(in: payload["reviewed"], role: .reviewRequested, reviewer: me, pending: false, viewer: me)
            .filter { !requested.contains($0.id) }
        let known = Set((authored + review).map(\.id))
        let merged = ((payload["merged"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []).compactMap { $0["url"] as? String }
        return PullRequestSnapshot(
            authored: authored, reviewRequested: review,
            mentions: pullRequests(in: payload["mentions"], role: .mentioned, viewer: me).filter { !known.contains($0.id) },
            mergedIDs: Set(merged),
            unlistedOpenIDs: openIDs(in: payload["reviewed"]).subtracting(known)
        )
    }

    private static func openIDs(in search: Any?) -> Set<String> {
        let nodes = (search as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        return Set(nodes.compactMap { $0["state"] as? String == "OPEN" ? $0["url"] as? String : nil })
    }

    private static func pullRequests(in search: Any?, role: PullRequest.Role, reviewer: String? = nil, pending: Bool = true, viewer: String? = nil) -> [PullRequest] {
        guard let nodes = (search as? [String: Any])?["nodes"] as? [[String: Any]] else { return [] }
        return nodes.compactMap { node in
            // Search can also return non-PR nodes, which come back as empty objects.
            // The search index lags a few minutes behind, so a just-merged or just-closed PR can still be returned
            // by `is:open`; the PR's own `state` is live, so only OPEN ones are kept.
            if let state = node["state"] as? String, state != "OPEN" { return nil }
            // Not asked and no verdict of their own (the overall decision would be someone else's): not a review request.
            if !pending, reviewer.flatMap({ myReview(node, login: $0) }) == nil { return nil }
            guard let number = node["number"] as? Int,
                  let title = node["title"] as? String,
                  let urlString = node["url"] as? String, let url = URL(string: urlString) else { return nil }
            let authorNode = node["author"] as? [String: Any]
            let login = authorNode?["login"] as? String
            let name = (authorNode?["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? login
            let repo = ((node["repository"] as? [String: Any])?["nameWithOwner"] as? String) ?? ""
            let rollup = (((node["commits"] as? [String: Any])?["nodes"] as? [[String: Any]])?.first?["commit"] as? [String: Any])?["statusCheckRollup"] as? [String: Any]
            return PullRequest(
                number: number, title: title, url: url, repository: repo,
                isDraft: node["isDraft"] as? Bool ?? false,
                ci: ci(rollup?["state"] as? String),
                review: reviewer.flatMap { myReview(node, login: $0) } ?? overallReview(node),
                hasConflicts: (node["mergeable"] as? String) == "CONFLICTING",
                role: role,
                commentCount: node["totalCommentsCount"] as? Int,
                conflictsKnown: (node["mergeable"] as? String).map { $0 == "CONFLICTING" || $0 == "MERGEABLE" } ?? false,
                reviewPending: pending,
                teamReview: overallReview(node),
                author: name,
                isMine: role == .authored || (viewer != nil && login?.lowercased() == viewer?.lowercased()),
                ownCommentCount: viewer.map { ownComments(in: node, login: $0) },
                unresolvedThreadCount: viewer.map { unresolvedThreads(in: node, login: $0) }
            )
        }
    }

    /// Open review threads whose first comment is not the user's (within the window the query asks for).
    static func unresolvedThreads(in node: [String: Any], login: String) -> Int {
        let threads = (node["reviewThreads"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        return threads.filter { thread in
            guard (thread["isResolved"] as? Bool) == false else { return false }
            let first = ((thread["comments"] as? [String: Any])?["nodes"] as? [[String: Any]])?.first
            return ((first?["author"] as? [String: Any])?["login"] as? String)?.lowercased() != login.lowercased()
        }.count
    }

    /// What `totalCommentsCount` adds up: conversation comments, inline comments and non-empty review bodies. This counts
    /// the user's share of them (within the windows the query asks for).
    static func ownComments(in node: [String: Any], login: String) -> Int {
        func nodes(_ key: String, in parent: [String: Any]) -> [[String: Any]] { (parent[key] as? [String: Any])?["nodes"] as? [[String: Any]] ?? [] }
        func isMe(_ n: [String: Any]) -> Bool { ((n["author"] as? [String: Any])?["login"] as? String)?.lowercased() == login.lowercased() }
        let conversation = nodes("comments", in: node).filter(isMe).count
        let bodies = nodes("reviews", in: node).filter { isMe($0) && !(($0["body"] as? String) ?? "").isEmpty }.count
        let inline = nodes("reviewThreads", in: node).reduce(0) { $0 + nodes("comments", in: $1).filter(isMe).count }
        return conversation + bodies + inline
    }

    /// The user's own verdict on a PR they were asked to review (nil while they have not approved or rejected it).
    static func myReview(_ node: [String: Any], login: String) -> ReviewState? {
        let reviews = ((node["latestOpinionatedReviews"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        let mine = reviews.first { (($0["author"] as? [String: Any])?["login"] as? String)?.lowercased() == login.lowercased() }
        switch mine?["state"] as? String {
        case "APPROVED": return .approved
        case "CHANGES_REQUESTED": return .changesRequested
        default: return nil
        }
    }

    static func ci(_ state: String?) -> CIState {
        switch state {
        case "SUCCESS": return .passing
        case "FAILURE", "ERROR": return .failing
        case "PENDING", "EXPECTED": return .pending
        default: return .none
        }
    }

    /// Human approvals a PR needs, on top of CodeRabbit's, before it counts as approved.
    public static let requiredHumanApprovals = 2

    /// A PR counts as approved only with at least `requiredHumanApprovals` approvals from people and an approval from
    /// CodeRabbit; GitHub's own `reviewDecision` (one approval is enough there) is not trusted for that. A requested
    /// change always wins, and anything short of the bar is still waiting for review.
    static func overallReview(_ node: [String: Any]) -> ReviewState {
        let decision = review(node["reviewDecision"] as? String)
        if decision == .changesRequested { return decision }
        let reviews = ((node["latestOpinionatedReviews"] as? [String: Any])?["nodes"] as? [[String: Any]]) ?? []
        func login(_ r: [String: Any]) -> String { ((r["author"] as? [String: Any])?["login"] as? String)?.lowercased() ?? "" }
        let approvers = Set(reviews.filter { ($0["state"] as? String) == "APPROVED" }.map(login))
        let codeRabbit = approvers.contains { $0.hasPrefix("coderabbit") }
        let humans = approvers.filter { !$0.hasPrefix("coderabbit") && !$0.isEmpty }.count
        if humans >= requiredHumanApprovals, codeRabbit { return .approved }
        return decision == .approved ? .reviewRequired : decision
    }

    static func review(_ decision: String?) -> ReviewState {
        switch decision {
        case "APPROVED": return .approved
        case "CHANGES_REQUESTED": return .changesRequested
        case "REVIEW_REQUIRED": return .reviewRequired
        default: return .none
        }
    }
}
