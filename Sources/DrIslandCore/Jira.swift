import Foundation

public struct JiraTask: Equatable, Identifiable, Sendable {
    public enum Category: Equatable, Sendable { case todo, inProgress, done }

    public var id: String { key }
    public let key: String
    public let summary: String
    public let status: String
    public let category: Category
    public let priority: String?
    public let url: URL
    public let commentCount: Int?
    public let labels: [String]
    /// Names in the "Approvers" field (`approversField`), sorted; `nil` when the field was not returned.
    public let approvers: [String]?
    /// Display name of the assignee (nil when unassigned).
    public let assignee: String?
    /// Display names of the comments' authors, as returned with the task (nil when not returned).
    public let commentAuthors: [String]?
    /// Whether the task is in the active sprint (nil when the Sprint field was not read).
    public let inActiveSprint: Bool?
    /// Ids of the sprints the task is in (empty when the Sprint field was not read).
    public let sprintIDs: [Int]
    /// Name of the issue type as Jira returns it ("Bug", "Story"…); nil when not returned.
    public let issueType: String?
    public var kind: JiraIssueKind { JiraIssueKind(typeName: issueType) }
    /// Whether the issue carries Jira's flag (the "Impediment" in the Flagged field).
    public let isFlagged: Bool
    /// The team marks sprint goals with the label `Sprint_Goal` (any case, `-`/`_`/space tolerated).
    public var isSprintGoal: Bool {
        labels.contains { $0.lowercased().filter { $0.isLetter } == "sprintgoal" }
    }

    public init(key: String, summary: String, status: String, category: Category, priority: String?, url: URL, commentCount: Int? = nil, labels: [String] = [], approvers: [String]? = nil, assignee: String? = nil, commentAuthors: [String]? = nil, inActiveSprint: Bool? = nil, issueType: String? = nil, isFlagged: Bool = false, sprintIDs: [Int] = []) {
        self.sprintIDs = sprintIDs
        self.isFlagged = isFlagged
        self.issueType = issueType
        self.inActiveSprint = inActiveSprint
        self.commentAuthors = commentAuthors
        self.assignee = assignee
        self.commentCount = commentCount
        self.approvers = approvers
        self.labels = labels
        self.key = key; self.summary = summary; self.status = status
        self.category = category; self.priority = priority; self.url = url
    }
}

/// The kind of work behind a Jira issue type, so the list can tell bugs from features at a glance.
public enum JiraIssueKind: Equatable, Sendable {
    case bug, feature, task, epic, subtask, other

    /// Tolerant of case, accents and the Portuguese/English names the team's projects use.
    public init(typeName: String?) {
        let name = (typeName ?? "").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        let words = name.split { !$0.isLetter }.map(String.init)
        func has(_ any: String...) -> Bool { any.contains { name.contains($0) } }
        if has("bug", "erro", "defeito", "defect", "incident", "problema", "problem") { self = .bug }
        else if has("sub-task", "subtask", "subtarefa", "sub tarefa") || words == ["sub", "task"] { self = .subtask }
        else if has("epic") { self = .epic }
        else if has("story", "feature", "historia", "melhoria", "improvement", "funcionalidade") { self = .feature }
        else if has("task", "tarefa") { self = .task }
        else { self = .other }
    }
}

public struct JiraConfig: Equatable, Sendable {
    public var site: String
    public var email: String
    public var token: String
    public var jql: String
    /// Tasks waiting on (or involving) the user as approver; shown in their own block.
    public var approverJQL: String
    public var maxResults: Int

    public static let defaultJQL = "assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC, updated DESC"

    /// Earlier default: `approver` is not a JQL field on this Jira (the field is the custom "Approvers", cf[10127]).
    public static let legacyApproverJQL = "approver = currentUser() AND statusCategory != Done ORDER BY updated DESC"
    /// The custom "Approvers" field of this Jira (the same one `defaultApproverJQL` filters on).
    public static let approversField = "customfield_10127"
    /// Jira's standard "Flagged" (impediment) field; a non-empty array means the issue is flagged.
    public static let flaggedField = "customfield_10006"
    public static let defaultApproverJQL = "cf[10127] = currentUser() AND statusCategory != Done ORDER BY updated DESC"

    public init(site: String, email: String, token: String, jql: String = JiraConfig.defaultJQL,
                approverJQL: String = JiraConfig.defaultApproverJQL, maxResults: Int = 25) {
        self.site = site; self.email = email; self.token = token; self.jql = jql; self.approverJQL = approverJQL; self.maxResults = maxResults
    }

    public var isComplete: Bool { !site.trimmingCharacters(in: .whitespaces).isEmpty && !email.isEmpty && !token.isEmpty }
}

public enum JiraError: Error, Equatable {
    case notConfigured
    case invalidSite
    case unauthorized
    case rateLimited
    case http(Int)
    case network
    case invalidResponse
    /// A request that is not a plain read was about to go to Jira; the app only ever reads.
    case readOnly
}

public enum JiraOrder {
    /// Sprint goals first, then what is in progress, then the rest. Stable: the JQL's own order is kept inside each group.
    public static func sorted(_ tasks: [JiraTask]) -> [JiraTask] {
        func rank(_ task: JiraTask) -> Int { task.isSprintGoal ? 0 : task.category == .inProgress ? 1 : 2 }
        return tasks.enumerated().sorted { (a, b) in
            let (ra, rb) = (rank(a.element), rank(b.element))
            return ra != rb ? ra < rb : a.offset < b.offset
        }.map(\.element)
    }

    /// The sprint card: what is still the user's first, then what they handed on (to test, review…), each in `sorted` order.
    public static func sprintSorted(_ tasks: [JiraTask], me: String?) -> [JiraTask] {
        let mine = tasks.filter { me != nil && $0.assignee == me }
        let handedOn = tasks.filter { !(me != nil && $0.assignee == me) }
        return sorted(mine) + sorted(handedOn)
    }
}

public enum JiraParser {
    /// `sprintField`: the Sprint custom field's id; when given, each task says whether it is in an active sprint.
    public static func parseTasks(_ data: Data, site: URL, sprintField: String? = nil) throws -> [JiraTask] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let issues = root["issues"] as? [[String: Any]] else { throw JiraError.invalidResponse }
        return issues.compactMap { issue in
            guard let key = issue["key"] as? String,
                  let fields = issue["fields"] as? [String: Any],
                  let summary = fields["summary"] as? String else { return nil }
            let status = fields["status"] as? [String: Any]
            let categoryKey = (status?["statusCategory"] as? [String: Any])?["key"] as? String
            return JiraTask(
                key: key, summary: summary,
                status: status?["name"] as? String ?? "",
                category: category(categoryKey),
                priority: (fields["priority"] as? [String: Any])?["name"] as? String,
                url: site.appendingPathComponent("browse/\(key)"),
                commentCount: (fields["comment"] as? [String: Any])?["total"] as? Int,
                labels: fields["labels"] as? [String] ?? [],
                approvers: (fields[JiraConfig.approversField] as? [[String: Any]]).map { users in
                    users.compactMap { ($0["displayName"] as? String) ?? ($0["accountId"] as? String) }.sorted()
                },
                assignee: (fields["assignee"] as? [String: Any])?["displayName"] as? String,
                commentAuthors: ((fields["comment"] as? [String: Any])?["comments"] as? [[String: Any]])?.compactMap { ($0["author"] as? [String: Any])?["displayName"] as? String },
                inActiveSprint: sprintField.map { field in
                    ((fields[field] as? [[String: Any]]) ?? []).contains { ($0["state"] as? String)?.lowercased() == "active" }
                },
                issueType: (fields["issuetype"] as? [String: Any])?["name"] as? String,
                isFlagged: !((fields[JiraConfig.flaggedField] as? [Any]) ?? []).isEmpty,
                sprintIDs: sprintField.map { field in ((fields[field] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? Int } } ?? []
            )
        }
    }

    public static func parseDisplayName(_ data: Data) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = root["displayName"] as? String else { throw JiraError.invalidResponse }
        return name
    }

    static func category(_ key: String?) -> JiraTask.Category {
        switch key {
        case "indeterminate": return .inProgress
        case "done": return .done
        default: return .todo
        }
    }
}

public struct JiraClient: Sendable {
    // Ephemeral: no cookies or disk cache for authenticated Jira responses.
    public static let defaultSession = URLSession(configuration: .ephemeral)

    private let session: URLSession

    public init(session: URLSession = JiraClient.defaultSession) {
        self.session = session
    }

    /// Accepts "empresa.atlassian.net" or a full URL; returns `https://host[:port]`. HTTP is rejected because the token is sent as Basic auth.
    public static func normalizedSite(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let components = URLComponents(string: text), components.scheme == "https",
              let host = components.host, host.contains(".") else { return nil }
        var base = URLComponents()
        base.scheme = "https"
        base.host = host
        base.port = components.port
        return base.url
    }

    static func authorizationHeader(email: String, token: String) -> String {
        "Basic " + Data("\(email):\(token)".utf8).base64EncodedString()
    }

    static func searchURL(site: URL, jql: String, maxResults: Int, extraFields: [String] = []) -> URL? {
        var components = URLComponents(url: site.appendingPathComponent("rest/api/3/search/jql"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "jql", value: jql),
            URLQueryItem(name: "fields", value: (["summary", "status", "priority", "issuetype", "comment", "labels", "assignee", JiraConfig.approversField, JiraConfig.flaggedField] + extraFields).joined(separator: ",")),
            URLQueryItem(name: "maxResults", value: String(max(1, min(maxResults, 50)))),
        ]
        return components?.url
    }

    public func fetchTasks(_ config: JiraConfig, sprintField: String? = nil) async throws -> [JiraTask] {
        try await search(config, jql: config.jql, sprintField: sprintField)
    }

    /// The active sprint's tasks that are or were the user's: `assignee was` keeps a task in view after it moves to
    /// someone else (test, review), so its state can be followed to the end of the sprint.
    /// Only the given sprints (the teams' current ones, which may be past their end but not closed yet).
    public static func sprintTasksJQL(field: String?, sprintIDs: [Int]) -> String {
        "\(SprintJQL.field(field)) in (\(sprintIDs.map(String.init).joined(separator: ","))) AND assignee was currentUser() ORDER BY rank"
    }

    public func fetchSprintTasks(_ config: JiraConfig, field: String?, sprintIDs: [Int]) async throws -> [JiraTask] {
        guard !sprintIDs.isEmpty else { return [] }
        return try await search(config, jql: Self.sprintTasksJQL(field: field, sprintIDs: sprintIDs), sprintField: field)
    }

    /// The tasks where the user is an approver (`config.approverJQL`).
    /// With `sprintField`, each task says whether it is in the active sprint.
    public func fetchApprovals(_ config: JiraConfig, sprintField: String? = nil) async throws -> [JiraTask] {
        try await search(config, jql: config.approverJQL, sprintField: sprintField)
    }

    private func search(_ config: JiraConfig, jql: String, sprintField: String? = nil) async throws -> [JiraTask] {
        let (site, header) = try prepare(config)
        guard let url = Self.searchURL(site: site, jql: jql, maxResults: config.maxResults, extraFields: sprintField.map { [$0] } ?? []) else { throw JiraError.invalidSite }
        let data = try await get(url, authorization: header)
        return try JiraParser.parseTasks(data, site: site, sprintField: sprintField)
    }

    /// Returns the account's display name; used by the settings "Testar" button.
    public func myself(_ config: JiraConfig) async throws -> String {
        let (site, header) = try prepare(config)
        let data = try await get(site.appendingPathComponent("rest/api/3/myself"), authorization: header)
        return try JiraParser.parseDisplayName(data)
    }

    func prepare(_ config: JiraConfig) throws -> (URL, String) {
        guard config.isComplete else { throw JiraError.notConfigured }
        guard let site = Self.normalizedSite(config.site) else { throw JiraError.invalidSite }
        return (site, Self.authorizationHeader(email: config.email, token: config.token))
    }

    /// Jira is read-only for this app: every request goes through `get`, which refuses anything but GET/HEAD.
    static func requireReadOnly(_ request: URLRequest) throws {
        let method = (request.httpMethod ?? "GET").uppercased()
        guard method == "GET" || method == "HEAD", request.httpBody == nil else { throw JiraError.readOnly }
    }

    func get(_ url: URL, authorization: String) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try Self.requireReadOnly(request)
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw JiraError.network }
        guard let http = response as? HTTPURLResponse else { throw JiraError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 401, 403: throw JiraError.unauthorized
        case 429: throw JiraError.rateLimited
        default: throw JiraError.http(http.statusCode)
        }
    }
}
