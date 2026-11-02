import Foundation

/// Reading the bugs of a project from Jira: only GETs, through `JiraClient.get`.
enum BugsRequests {
    /// Bugs opened or resolved in the last weeks (a week more than shown, so the first one is complete).
    static func recentJQL(project: String, typeIDs: [String], weeks: Int) -> String {
        "project = \(project) AND issuetype in (\(typeIDs.joined(separator: ","))) AND (created >= -\(weeks + 1)w OR resolved >= -\(weeks + 1)w) ORDER BY created ASC"
    }

    static func openJQL(project: String, typeIDs: [String]) -> String {
        "project = \(project) AND issuetype in (\(typeIDs.joined(separator: ","))) AND resolution = Unresolved"
    }

    static func searchURL(site: URL, jql: String, pageToken: String?) -> URL? {
        var components = URLComponents(url: site.appendingPathComponent("rest/api/3/search/jql"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "jql", value: jql),
            URLQueryItem(name: "fields", value: "created,resolutiondate"),
            URLQueryItem(name: "maxResults", value: "50"),
        ]
        if let pageToken { components?.queryItems?.append(URLQueryItem(name: "nextPageToken", value: pageToken)) }
        return components?.url
    }

    static func issueTypesURL(site: URL) -> URL { site.appendingPathComponent("rest/api/3/issuetype") }
}

enum BugsParser {
    /// Ids of the issue types that are bugs ("Bug", "Problema", "Erro"…), by the same rule the task rows use.
    static func bugTypeIDs(_ data: Data) -> [String]? {
        guard let types = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        return types.compactMap { type in
            guard let id = type["id"] as? String, let name = type["name"] as? String,
                  type["subtask"] as? Bool != true, JiraIssueKind(typeName: name) == .bug else { return nil }
            return id
        }
    }

    /// The bugs of one page of `search/jql` (those without a readable creation date are skipped).
    static func records(_ data: Data) -> [BugRecord]? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let issues = root["issues"] as? [[String: Any]] else { return nil }
        return issues.compactMap { issue in
            guard let key = issue["key"] as? String, let fields = issue["fields"] as? [String: Any],
                  let created = (fields["created"] as? String).flatMap(SprintParser.parseDate) else { return nil }
            return BugRecord(key: key, created: created, resolved: (fields["resolutiondate"] as? String).flatMap(SprintParser.parseDate))
        }
    }
}

extension JiraClient {
    /// The bugs of `project` opened or resolved in the last `weeks` (up to 200) and how many are open now (up to 100).
    public func fetchBugs(_ config: JiraConfig, project: String, weeks: Int = BugFlow.defaultWeeks) async throws -> (recent: [BugRecord], openCount: Int, openCapped: Bool) {
        guard project.range(of: "^[A-Za-z][A-Za-z0-9_]*$", options: .regularExpression) != nil else { throw JiraError.invalidResponse }
        let (site, header) = try prepare(config)
        guard let typeIDs = BugsParser.bugTypeIDs(try await get(BugsRequests.issueTypesURL(site: site), authorization: header)) else { throw JiraError.invalidResponse }
        guard !typeIDs.isEmpty else { return ([], 0, false) }

        func read(_ jql: String, pages: Int) async throws -> (bugs: [BugRecord], more: Bool) {
            var all: [BugRecord] = []
            var token: String?
            for _ in 0..<pages {
                guard let url = BugsRequests.searchURL(site: site, jql: jql, pageToken: token) else { throw JiraError.invalidSite }
                let data = try await get(url, authorization: header)
                guard let page = BugsParser.records(data) else { throw JiraError.invalidResponse }
                all += page
                token = BacklogParser.nextPageToken(data)
                if token == nil { return (all, false) }
            }
            return (all, true)
        }
        let recent = try await read(BugsRequests.recentJQL(project: project, typeIDs: typeIDs, weeks: weeks), pages: 4)
        let open = try await read(BugsRequests.openJQL(project: project, typeIDs: typeIDs), pages: 2)
        return (recent.bugs, open.bugs.count, open.more)
    }
}
