import Foundation

/// A Jira Software scrum board (a team's "stream"), as listed by the agile API.
public struct JiraBoard: Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public init(id: Int, name: String) { self.id = id; self.name = name }
}

public enum BoardParser {
    /// One page of `GET /rest/agile/1.0/board`: the boards and whether it was the last page.
    public static func parse(_ data: Data) -> (boards: [JiraBoard], isLast: Bool)? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let values = root["values"] as? [[String: Any]] else { return nil }
        let boards = values.compactMap { raw -> JiraBoard? in
            guard let id = raw["id"] as? Int, let name = raw["name"] as? String else { return nil }
            return JiraBoard(id: id, name: name)
        }
        return (boards, root["isLast"] as? Bool ?? true)
    }

    /// The ids kept in a setting ("483, 846"); anything that is not a number is dropped.
    public static func parseIDs(_ text: String) -> Set<Int> {
        Set(text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) })
    }

    public static func format(_ ids: Set<Int>) -> String { ids.sorted().map(String.init).joined(separator: ",") }
}

extension JiraClient {
    /// The scrum boards the user can see, by name (read-only: a plain GET). At most 5 pages of 50.
    public func fetchBoards(_ config: JiraConfig) async throws -> [JiraBoard] {
        let (site, header) = try prepare(config)
        var boards: [JiraBoard] = []
        var start = 0
        for _ in 0..<5 {
            var components = URLComponents(url: site.appendingPathComponent("rest/agile/1.0/board"), resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "type", value: "scrum"),
                URLQueryItem(name: "maxResults", value: "50"),
                URLQueryItem(name: "startAt", value: String(start)),
            ]
            guard let url = components?.url else { throw JiraError.invalidSite }
            guard let page = BoardParser.parse(try await get(url, authorization: header)) else { throw JiraError.invalidResponse }
            boards += page.boards
            if page.isLast || page.boards.isEmpty { break }
            start += page.boards.count
        }
        return boards.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
