import Foundation

public enum GitHubError: Error, Equatable {
    case notInstalled
    case notAuthenticated
    case failed(String)
    case invalidResponse
}

/// Talks to GitHub through the user's already-authenticated `gh` CLI (no token handled by this app).
public struct GitHubClient: Sendable {
    public struct Options: Sendable, Equatable {
        public var ghPath: String?              // nil/empty = auto-detect
        public var includeReviewRequests: Bool
        public var scope: String                // "org" or "org/repo", comma-separated; empty = everything
        public var limit: Int
        public var includeMentions: Bool

        public init(ghPath: String? = nil, includeReviewRequests: Bool = true, scope: String = "", limit: Int = 20, includeMentions: Bool = true) {
            self.includeMentions = includeMentions
            self.ghPath = ghPath; self.includeReviewRequests = includeReviewRequests; self.scope = scope; self.limit = limit
        }
    }

    public init() {}

    public static func locateGh(override: String? = nil) -> String? {
        let fm = FileManager.default
        var candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        if let override, !override.isEmpty { candidates.insert(override, at: 0) }
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }

    public func fetch(_ options: Options) async throws -> PullRequestSnapshot {
        guard let gh = Self.locateGh(override: options.ghPath) else { throw GitHubError.notInstalled }
        let arguments = Self.arguments(for: options)
        let data = try await Task.detached { try Self.run(gh, arguments) }.value
        do { return try GitHubParser.parse(data) } catch { throw GitHubError.invalidResponse }
    }

    // MARK: Query building (pure, tested)

    static let fragment = """
    fragment F on PullRequest {
      number title url state isDraft reviewDecision mergeable totalCommentsCount
      author { login ... on User { name } }
      comments(last: 30) { nodes { author { login } } }
      reviews(last: 30) { nodes { author { login } body } }
      reviewThreads(last: 30) { nodes { isResolved comments(first: 10) { nodes { author { login } } } } }
      repository { nameWithOwner }
      latestOpinionatedReviews(first: 30) { nodes { state author { login } } }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
    }
    """

    static func scopeQualifiers(_ scope: String) -> String {
        scope.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || "._/-".contains($0) } }
            .map { $0.contains("/") ? "repo:\($0)" : "org:\($0)" }
            .joined(separator: " ")
    }

    static func arguments(for options: Options) -> [String] {
        let scope = scopeQualifiers(options.scope)
        let common = "is:pr is:open archived:false sort:updated-desc" + (scope.isEmpty ? "" : " " + scope)
        var query = "query($a:String!,$n:Int!"
        var body = "authored: search(query:$a,type:ISSUE,first:$n){nodes{...F}} viewer{login}"
        var args = ["api", "graphql", "-f", "a=author:@me \(common)", "-F", "n=\(max(1, min(options.limit, 50)))"]
        if options.includeReviewRequests {
            query += ",$r:String!"
            body += " review: search(query:$r,type:ISSUE,first:$n){nodes{...F}}"
            args += ["-f", "r=review-requested:@me \(common)"]
            // GitHub drops the user from the requested reviewers once they review, so PRs they already approved or
            // rejected are fetched separately and stay in the list until they are merged or closed.
            query += ",$d:String!"
            body += " reviewed: search(query:$d,type:ISSUE,first:$n){nodes{...F}}"
            args += ["-f", "d=reviewed-by:@me -author:@me \(common)"]
        }
        // Merged PRs only tell "merged" from "closed"; mentions are tracked for alerts. Both are cheap and optional.
        query += ",$m:String!"
        body += " merged: search(query:$m,type:ISSUE,first:10){nodes{...on PullRequest{url}}}"
        args += ["-f", "m=author:@me is:pr is:merged archived:false sort:updated-desc" + (scope.isEmpty ? "" : " " + scope)]
        if options.includeMentions {
            query += ",$t:String!"
            body += " mentions: search(query:$t,type:ISSUE,first:10){nodes{...F}}"
            args += ["-f", "t=mentions:@me -author:@me \(common)"]
        }
        query += "){ \(body) }\n\(fragment)"
        return args + ["-f", "query=\(query)"]
    }

    static func classify(stderr: String, status: Int32) -> GitHubError {
        let text = stderr.lowercased()
        if text.contains("gh auth login") || text.contains("not logged in") || text.contains("http 401") || text.contains("bad credentials") {
            return .notAuthenticated
        }
        let firstLine = stderr.split(separator: "\n").first.map(String.init) ?? "gh terminou com código \(status)"
        return .failed(String(firstLine.prefix(200)))
    }

    // MARK: Process

    private static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["GH_PROMPT_DISABLED"] = "1"
        env["GH_NO_UPDATE_NOTIFIER"] = "1"
        env["NO_COLOR"] = "1"
        process.environment = env
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { throw GitHubError.notInstalled }
        // Drain stderr concurrently so a chatty gh cannot fill the pipe and deadlock.
        let errBox = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errBox.data = err.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw classify(stderr: String(data: errBox.data, encoding: .utf8) ?? "", status: process.terminationStatus)
        }
        return outData
    }
}

private final class DataBox: @unchecked Sendable { var data = Data() }
