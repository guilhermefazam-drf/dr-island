import Foundation

/// The active Jira sprint: its name and planned dates. `end` is the planned end; the sprint may be closed earlier.
public struct SprintInfo: Equatable, Sendable {
    public enum Level: Equatable, Sendable { case normal, warning, critical }

    public let name: String
    public let start: Date
    public let end: Date

    public init(name: String, start: Date, end: Date) {
        self.name = name; self.start = start; self.end = end
    }

    /// Elapsed share of the sprint, 0…1 (1 when the dates are degenerate or the end has passed).
    public func progress(now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(max(now.timeIntervalSince(start) / total, 0), 1)
    }

    public func remaining(now: Date) -> TimeInterval { max(end.timeIntervalSince(now), 0) }

    /// Amber in the last 3 days, red in the last day.
    public func level(now: Date) -> Level {
        let left = remaining(now: now)
        return left < 86_400 ? .critical : left < 3 * 86_400 ? .warning : .normal
    }

    /// "3d 4h", "5h 20m", "40m"; "terminada" at zero.
    public static func remainingLabel(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        guard minutes > 0 else { return "terminada" }
        let (days, hours, mins) = (minutes / 1440, minutes % 1440 / 60, minutes % 60)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}

/// Jira issue keys (`TEP-2005`) found in free text, such as a pull request title.
public enum JiraKeys {
    public static func extract(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![A-Za-z0-9])[A-Z][A-Z0-9]{1,9}-[0-9]+(?![0-9])"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var seen = Set<String>()
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }.filter { seen.insert($0).inserted }
    }
}

public enum SprintParser {
    /// For each returned issue, whether it is in an active sprint.
    public static func membership(_ data: Data, field: String) -> [String: Bool] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let issues = root["issues"] as? [[String: Any]] else { return [:] }
        var result: [String: Bool] = [:]
        for issue in issues {
            guard let key = issue["key"] as? String else { continue }
            let sprints = ((issue["fields"] as? [String: Any])?[field] as? [[String: Any]]) ?? []
            result[key] = sprints.contains { ($0["state"] as? String)?.lowercased() == "active" }
        }
        return result
    }

    /// The id of the Jira Software "Sprint" field (it is a `customfield_NNNNN` that differs per site).
    public static func sprintFieldID(_ data: Data) -> String? {
        guard let fields = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        let match = fields.first { field in
            (field["schema"] as? [String: Any])?["custom"] as? String == "com.pyxis.greenhopper.jira:gh-sprint"
        } ?? fields.first { ($0["name"] as? String) == "Sprint" && ($0["custom"] as? Bool) == true }
        return match?["id"] as? String
    }

    /// The sprint with `state == active` found on the issues' sprint field (an issue carried over lists several).
    /// When more than one qualifies, the one that started last wins.
    public static func activeSprint(_ data: Data, field: String) -> SprintInfo? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let issues = root["issues"] as? [[String: Any]] else { return nil }
        let sprints = issues.compactMap { ($0["fields"] as? [String: Any])?[field] as? [[String: Any]] }.flatMap { $0 }
        return sprints.compactMap { raw -> SprintInfo? in
            guard (raw["state"] as? String)?.lowercased() == "active",
                  let name = raw["name"] as? String,
                  let start = (raw["startDate"] as? String).flatMap(parseDate),
                  let end = (raw["endDate"] as? String).flatMap(parseDate) else { return nil }
            return SprintInfo(name: name, start: start, end: end)
        }.max { $0.start < $1.start }
    }

    /// Jira writes `2026-10-12T09:00:00.000Z` or `…000+0100` depending on the endpoint.
    public static func parseDate(_ text: String) -> Date? {
        for options in [ISO8601DateFormatter.Options([.withInternetDateTime, .withFractionalSeconds]), [.withInternetDateTime]] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: text) { return date }
        }
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

extension JiraClient {
    /// The active sprint, or nil when there is none (or the site has no Sprint field). The field id is looked up once
    /// per call; pass it back in via `field` to skip that request. The user's own tasks decide which sprint, falling
    /// back to any open sprint.
    /// The id of the Sprint field of this site, nil when it has none.
    public func sprintFieldID(_ config: JiraConfig) async throws -> String? {
        let (site, header) = try prepare(config)
        return SprintParser.sprintFieldID(try await get(site.appendingPathComponent("rest/api/3/field"), authorization: header))
    }

    /// Whether each of `keys` is in an active sprint (a key that is not found comes back as false). A key that does not
    /// exist makes Jira reject the whole query, so then the keys are asked one by one and only the failures are dropped.
    public func fetchSprintMembership(_ config: JiraConfig, keys: [String], field: String) async throws -> [String: Bool] {
        let valid = Array(Set(keys.filter { JiraKeys.extract(from: $0) == [$0] })).sorted().prefix(40)
        guard !valid.isEmpty else { return [:] }
        func ask(_ chunk: [String]) async throws -> [String: Bool] {
            let (site, header) = try prepare(config)
            var components = URLComponents(url: site.appendingPathComponent("rest/api/3/search/jql"), resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "jql", value: "key in (\(chunk.joined(separator: ",")))"),
                URLQueryItem(name: "fields", value: field),
                URLQueryItem(name: "maxResults", value: String(max(1, min(chunk.count, 50)))),
            ]
            guard let url = components?.url else { throw JiraError.invalidSite }
            return SprintParser.membership(try await get(url, authorization: header), field: field)
        }
        var found: [String: Bool] = [:]
        do { found = try await ask(Array(valid)) } catch JiraError.http(400) {
            for key in valid { if let one = try? await ask([key]) { found.merge(one) { $1 } } }
        }
        return Dictionary(uniqueKeysWithValues: valid.map { ($0, found[$0] ?? false) })
    }

    public func fetchActiveSprint(_ config: JiraConfig, field: String?) async throws -> (sprint: SprintInfo?, field: String?) {
        let (site, header) = try prepare(config)
        var fieldID = field
        if fieldID == nil {
            let data = try await get(site.appendingPathComponent("rest/api/3/field"), authorization: header)
            fieldID = SprintParser.sprintFieldID(data)
        }
        guard let fieldID else { return (nil, nil) }
        for jql in ["assignee = currentUser() AND sprint in openSprints() ORDER BY updated DESC", "sprint in openSprints() ORDER BY updated DESC"] {
            var components = URLComponents(url: site.appendingPathComponent("rest/api/3/search/jql"), resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "jql", value: jql),
                URLQueryItem(name: "fields", value: fieldID),
                URLQueryItem(name: "maxResults", value: "10"),
            ]
            guard let url = components?.url else { throw JiraError.invalidSite }
            if let sprint = SprintParser.activeSprint(try await get(url, authorization: header), field: fieldID) { return (sprint, fieldID) }
        }
        return (nil, fieldID)
    }
}
