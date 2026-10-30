import Foundation

/// URL builders for the management charts. Read-only: the client only ever sends these through `JiraClient.get`.
enum SprintMetricsRequests {
    static let pageSize = 50

    static func boardSprintsURL(site: URL, boardID: Int, startAt: Int) -> URL? {
        var components = URLComponents(url: site.appendingPathComponent("rest/agile/1.0/board/\(boardID)/sprint"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "state", value: "active,closed"),
            URLQueryItem(name: "maxResults", value: String(pageSize)),
            URLQueryItem(name: "startAt", value: String(startAt)),
        ]
        return components?.url
    }

    /// Issues that are or were in the sprint (an issue removed from it still counts for the burndown).
    static func sprintIssuesJQL(sprintField: String, sprintID: Int) -> String {
        let field = SprintJQL.field(sprintField)
        return "\(field) = \(sprintID) OR \(field) was \(sprintID) ORDER BY created ASC"
    }

    static func sprintIssuesURL(site: URL, sprintID: Int, sprintField: String, pointsField: String?, pageToken: String?) -> URL? {
        var components = URLComponents(url: site.appendingPathComponent("rest/api/3/search/jql"), resolvingAgainstBaseURL: false)
        let fields = ["status", "issuetype", "created", "resolutiondate", JiraConfig.flaggedField] + (pointsField.map { [$0] } ?? []) + [sprintField]
        var items = [
            URLQueryItem(name: "jql", value: sprintIssuesJQL(sprintField: sprintField, sprintID: sprintID)),
            URLQueryItem(name: "fields", value: fields.joined(separator: ",")),
            URLQueryItem(name: "expand", value: "changelog"),
            URLQueryItem(name: "maxResults", value: String(pageSize)),
        ]
        if let pageToken { items.append(URLQueryItem(name: "nextPageToken", value: pageToken)) }
        components?.queryItems = items
        return components?.url
    }

    static func changelogURL(site: URL, key: String, startAt: Int) -> URL? {
        var components = URLComponents(url: site.appendingPathComponent("rest/api/3/issue/\(key)/changelog"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "startAt", value: String(startAt)),
            URLQueryItem(name: "maxResults", value: "100"),
        ]
        return components?.url
    }
}

enum SprintMetricsParser {
    /// One page of `GET /rest/agile/1.0/board/{id}/sprint`.
    static func sprintsPage(_ data: Data, boardID: Int) -> (sprints: [SprintRecord], isLast: Bool)? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let values = root["values"] as? [[String: Any]] else { return nil }
        let sprints = values.compactMap { raw -> SprintRecord? in
            guard let id = raw["id"] as? Int, let name = raw["name"] as? String else { return nil }
            func date(_ key: String) -> Date? { (raw[key] as? String).flatMap(SprintParser.parseDate) }
            return SprintRecord(id: id, name: name, boardID: boardID, start: date("startDate"), end: date("endDate"),
                                state: (raw["state"] as? String)?.lowercased() ?? "", completedAt: date("completeDate"))
        }
        return (sprints, root["isLast"] as? Bool ?? true)
    }

    /// Newest start first; sprints without a start date go last (by id, newest first).
    static func sortedNewestFirst(_ sprints: [SprintRecord]) -> [SprintRecord] {
        sprints.sorted { a, b in
            switch (a.start, b.start) {
            case let (x?, y?) where x != y: return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.id > b.id
            }
        }
    }

    /// The story-points field: "Story Points" wins over "Story point estimate".
    static func pointsField(_ data: Data) -> (id: String, name: String)? {
        guard let fields = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        for wanted in ["Story Points", "Story point estimate"] {
            if let match = fields.first(where: { $0["name"] as? String == wanted }), let id = match["id"] as? String {
                return (id, wanted)
            }
        }
        return nil
    }

    /// Status name → status category key (`new`, `indeterminate`, `done`).
    static func statusCategories(_ data: Data) -> [String: String]? {
        guard let statuses = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        var result: [String: String] = [:]
        for status in statuses {
            guard let name = status["name"] as? String,
                  let key = (status["statusCategory"] as? [String: Any])?["key"] as? String else { continue }
            result[name] = key
        }
        return result
    }

    /// One page of `GET /rest/api/3/issue/{key}/changelog`.
    static func changelogPage(_ data: Data) -> (histories: [[String: Any]], isLast: Bool)? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let values = root["values"] as? [[String: Any]] else { return nil }
        return (values, root["isLast"] as? Bool ?? true)
    }
}

/// Joins changelog pages onto the histories already in hand, keeping the first copy of each history id.
func mergeChangelogPages(initial: [[String: Any]], pages: [[[String: Any]]]) -> [[String: Any]] {
    var seen = Set<String>()
    var result: [[String: Any]] = []
    for history in initial + pages.flatMap({ $0 }) {
        if let id = history["id"] as? String {
            guard seen.insert(id).inserted else { continue }
        }
        result.append(history)
    }
    return result
}

extension JiraClient {
    /// The board's active and closed sprints, newest start first (undated last). Read-only; at most 20 pages of 50.
    public func fetchBoardSprints(_ config: JiraConfig, boardID: Int) async throws -> [SprintRecord] {
        let (site, header) = try prepare(config)
        var sprints: [SprintRecord] = []
        var start = 0
        for _ in 0..<20 {
            guard let url = SprintMetricsRequests.boardSprintsURL(site: site, boardID: boardID, startAt: start) else { throw JiraError.invalidSite }
            guard let page = SprintMetricsParser.sprintsPage(try await get(url, authorization: header), boardID: boardID) else { throw JiraError.invalidResponse }
            sprints += page.sprints
            if page.isLast || page.sprints.isEmpty { break }
            start += page.sprints.count
        }
        return SprintMetricsParser.sortedNewestFirst(sprints)
    }

    /// The story-points custom field (id and name), or nil when the site has none.
    public func fetchPointsField(_ config: JiraConfig) async throws -> (id: String, name: String)? {
        let (site, header) = try prepare(config)
        let data = try await get(site.appendingPathComponent("rest/api/3/field"), authorization: header)
        guard (try? JSONSerialization.jsonObject(with: data)) is [[String: Any]] else { throw JiraError.invalidResponse }
        return SprintMetricsParser.pointsField(data)
    }

    public func fetchStatusCategories(_ config: JiraConfig) async throws -> [String: String] {
        let (site, header) = try prepare(config)
        let data = try await get(site.appendingPathComponent("rest/api/3/status"), authorization: header)
        guard let map = SprintMetricsParser.statusCategories(data) else { throw JiraError.invalidResponse }
        return map
    }

    /// Every issue that is or was in the sprint, with its changelog. Issues whose changelog came back truncated get
    /// the rest from the changelog endpoint. All requests are GETs.
    public func fetchSprintSnapshot(_ config: JiraConfig, sprint: SprintRecord, sprintField: String,
                                    points: (id: String, name: String)?) async throws -> SprintSnapshot {
        let (site, header) = try prepare(config)
        var issues: [SprintIssue] = []
        var truncated: [String] = []
        var token: String?
        for _ in 0..<100 {
            guard let url = SprintMetricsRequests.sprintIssuesURL(site: site, sprintID: sprint.id, sprintField: sprintField,
                                                                  pointsField: points?.id, pageToken: token) else { throw JiraError.invalidSite }
            let data = try await get(url, authorization: header)
            let page: (issues: [SprintIssue], truncated: [String], nextPageToken: String?)
            do {
                page = try ChangelogParser.issues(from: data, sprintField: sprintField, pointsField: points?.id, pointsFieldName: points?.name)
            } catch { throw JiraError.invalidResponse }
            issues += page.issues
            truncated += page.truncated
            token = page.nextPageToken
            if token == nil || page.issues.isEmpty { break }
        }

        for key in truncated {
            guard let index = issues.firstIndex(where: { $0.key == key }) else { continue }
            var pages: [[[String: Any]]] = []
            var start = 0
            for _ in 0..<50 {
                guard let url = SprintMetricsRequests.changelogURL(site: site, key: key, startAt: start) else { throw JiraError.invalidSite }
                guard let page = SprintMetricsParser.changelogPage(try await get(url, authorization: header)) else { throw JiraError.invalidResponse }
                pages.append(page.histories)
                if page.isLast || page.histories.isEmpty { break }
                start += page.histories.count
            }
            let histories = mergeChangelogPages(initial: [], pages: pages)
            issues[index].events = ChangelogParser.events(fromHistories: histories, pointsFieldName: points?.name)
        }

        let categories = try await fetchStatusCategories(config)
        return SprintSnapshot(sprint: sprint, issues: issues, statusCategories: categories, fetchedAt: Date())
    }
}
