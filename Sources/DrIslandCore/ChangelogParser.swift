import Foundation

/// Parses `search/jql?expand=changelog` responses into `SprintIssue`s.
public enum ChangelogParser {
    public static func issues(from data: Data, sprintField: String, pointsField: String?) throws
        -> (issues: [SprintIssue], truncated: [String], nextPageToken: String?) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        var issues: [SprintIssue] = []
        var truncated: [String] = []
        for raw in (root["issues"] as? [[String: Any]]) ?? [] {
            guard let key = raw["key"] as? String,
                  let fields = raw["fields"] as? [String: Any],
                  let created = (fields["created"] as? String).flatMap(SprintParser.parseDate) else { continue }
            let changelog = raw["changelog"] as? [String: Any]
            let histories = (changelog?["histories"] as? [[String: Any]]) ?? []
            if let total = changelog?["total"] as? Int, total > histories.count { truncated.append(key) }
            issues.append(SprintIssue(
                key: key,
                type: (fields["issuetype"] as? [String: Any])?["name"] as? String,
                points: pointsField.flatMap { (fields[$0] as? NSNumber)?.doubleValue },
                status: (fields["status"] as? [String: Any])?["name"] as? String ?? "",
                statusID: (fields["status"] as? [String: Any])?["id"] as? String,
                isFlagged: !((fields[JiraConfig.flaggedField] as? [Any]) ?? []).isEmpty,
                created: created,
                resolved: (fields["resolutiondate"] as? String).flatMap(SprintParser.parseDate),
                events: events(fromHistories: histories, sprintField: sprintField, pointsField: pointsField)))
        }
        return (issues, truncated, root["nextPageToken"] as? String)
    }

    /// Status (by status id), Sprint and (when `pointsField` is given) story-point changes, oldest first.
    /// Sprint and points items are matched by custom-field id: a site can have a second field also named "Sprint".
    public static func events(fromHistories histories: [[String: Any]], sprintField: String, pointsField: String?) -> [SprintIssueEvent] {
        var result: [SprintIssueEvent] = []
        for history in histories {
            guard let date = (history["created"] as? String).flatMap(SprintParser.parseDate) else { continue }
            for item in (history["items"] as? [[String: Any]]) ?? [] {
                guard let field = item["field"] as? String else { continue }
                let fieldID = item["fieldId"] as? String
                let kind: SprintIssueEvent.Kind
                let from: String?, to: String?
                if field == "status" {
                    kind = .status; from = text(item["from"]); to = text(item["to"])
                } else if fieldID == sprintField {
                    kind = .sprint; from = text(item["from"]); to = text(item["to"])
                } else if let pointsField, fieldID == pointsField {
                    kind = .points; from = text(item["fromString"]); to = text(item["toString"])
                } else { continue }
                result.append(SprintIssueEvent(date: date, kind: kind, from: from, to: to))
            }
        }
        // Stable: events from one history keep their order when dates tie.
        return result.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }.map(\.element)
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }
}
