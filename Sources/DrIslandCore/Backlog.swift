import Foundation

/// A future sprint a backlog task is planned into.
public struct PlannedSprint: Equatable, Hashable, Sendable {
    public let id: Int
    public let name: String
    /// Planned start; future sprints often have none yet.
    public let start: Date?

    public init(id: Int, name: String, start: Date? = nil) {
        self.id = id; self.name = name; self.start = start
    }
}

/// One group of the "Backlog" card: a future sprint, or the tasks with no sprint (`sprint == nil`).
public struct BacklogGroup: Equatable, Identifiable, Sendable {
    public var id: String { sprint.map { "sprint:\($0.id)" } ?? "backlog" }
    public let sprint: PlannedSprint?
    public let tasks: [JiraTask]
    public var title: String { sprint?.name ?? "Backlog" }

    public init(sprint: PlannedSprint?, tasks: [JiraTask]) {
        self.sprint = sprint; self.tasks = tasks
    }
}

public enum Backlog {
    public static func defaultJQL(project: String) -> String {
        "project = \(project) AND statusCategory != Done AND (sprint is EMPTY OR sprint in futureSprints()) ORDER BY rank"
    }

    /// The project key most of the user's tasks belong to (`TEP-12` → `TEP`), to scope the backlog when none is set.
    public static func guessProject(from keys: [String]) -> String? {
        let projects = keys.compactMap { $0.split(separator: "-").first.map(String.init) }
        let counts = Dictionary(projects.map { ($0, 1) }, uniquingKeysWith: +)
        return projects.first { counts[$0] == counts.values.max() }
    }

    /// As the Jira backlog view: one group per future sprint (by start date, then id), then "Backlog". The JQL's
    /// order (rank) is kept inside each group; a task in no future sprint goes to "Backlog"; empty groups are left out.
    public static func groups(_ tasks: [JiraTask], sprints: [String: PlannedSprint]) -> [BacklogGroup] {
        var bySprint: [PlannedSprint: [JiraTask]] = [:]
        var rest: [JiraTask] = []
        for task in tasks {
            if let sprint = sprints[task.key] { bySprint[sprint, default: []].append(task) } else { rest.append(task) }
        }
        let ordered = bySprint.keys.sorted { a, b in
            switch (a.start, b.start) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.id < b.id
            }
        }
        var result = ordered.map { BacklogGroup(sprint: $0, tasks: bySprint[$0] ?? []) }
        if !rest.isEmpty { result.append(BacklogGroup(sprint: nil, tasks: rest)) }
        return result
    }
}

public enum BacklogParser {
    /// For each issue in a future sprint, that sprint (the earliest one when it lists several).
    public static func futureSprints(_ data: Data, field: String) -> [String: PlannedSprint] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let issues = root["issues"] as? [[String: Any]] else { return [:] }
        var result: [String: PlannedSprint] = [:]
        for issue in issues {
            guard let key = issue["key"] as? String else { continue }
            let raw = ((issue["fields"] as? [String: Any])?[field] as? [[String: Any]]) ?? []
            let future = raw.compactMap { sprint -> PlannedSprint? in
                guard (sprint["state"] as? String)?.lowercased() == "future",
                      let id = sprint["id"] as? Int, let name = sprint["name"] as? String else { return nil }
                return PlannedSprint(id: id, name: name, start: (sprint["startDate"] as? String).flatMap(SprintParser.parseDate))
            }
            if let first = future.min(by: { ($0.start ?? .distantFuture, $0.id) < ($1.start ?? .distantFuture, $1.id) }) {
                result[key] = first
            }
        }
        return result
    }

    static func nextPageToken(_ data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root["isLast"] as? Bool != true else { return nil }
        return root["nextPageToken"] as? String
    }
}

extension JiraClient {
    /// The team backlog (`jql`), up to `limit` tasks over pages of 50, grouped by future sprint. `truncated` = more exist.
    public func fetchBacklog(_ config: JiraConfig, jql: String, sprintField: String?, limit: Int = 100) async throws -> (groups: [BacklogGroup], truncated: Bool) {
        let (site, header) = try prepare(config)
        var tasks: [JiraTask] = []
        var sprints: [String: PlannedSprint] = [:]
        var token: String?
        repeat {
            guard var components = Self.searchURL(site: site, jql: jql, maxResults: 50, extraFields: sprintField.map { [$0] } ?? [])
                .flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else { throw JiraError.invalidSite }
            if let token { components.queryItems?.append(URLQueryItem(name: "nextPageToken", value: token)) }
            guard let url = components.url else { throw JiraError.invalidSite }
            let data = try await get(url, authorization: header)
            tasks += try JiraParser.parseTasks(data, site: site)
            if let sprintField { sprints.merge(BacklogParser.futureSprints(data, field: sprintField)) { $1 } }
            token = BacklogParser.nextPageToken(data)
        } while token != nil && tasks.count < limit
        return (Backlog.groups(Array(tasks.prefix(limit)), sprints: sprints), token != nil || tasks.count > limit)
    }
}
