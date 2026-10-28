import Foundation

/// One alert that was shown, kept for a while so the user can look back at what happened.
public struct AlertEntry: Codable, Equatable, Identifiable, Sendable {
    public enum Source: String, CaseIterable, Sendable {
        case pullRequests, jira

        public var title: String {
            switch self {
            case .pullRequests: return "PRs"
            case .jira: return "Jira"
            }
        }
    }

    public let id: UUID
    public let date: Date
    public let kind: PRChange.Kind
    public let prID: String
    public let ref: String
    /// The text the alert showed ("CI falhou: repo#12"), frozen at the time.
    public let message: String

    public init(id: UUID = UUID(), date: Date, kind: PRChange.Kind, prID: String, ref: String, message: String) {
        self.id = id; self.date = date; self.kind = kind; self.prID = prID; self.ref = ref; self.message = message
    }

    public init(_ change: PRChange, date: Date) {
        self.init(date: date, kind: change.kind, prID: change.prID, ref: change.ref, message: change.message)
    }

    /// The message with its origin in front. Entries saved before the origin existed get it added here.
    public var displayMessage: String {
        let prefix = kind.origin + " - "
        return message.hasPrefix(prefix) ? message : prefix + message
    }

    public var tone: PRChange.Tone { PRChange(prID: prID, ref: ref, title: "", kind: kind).tone }

    public var source: Source { kind.alertSource }
}

extension PRChange.Kind {
    public var alertSource: AlertEntry.Source {
        switch self {
        case .jiraNew, .jiraStatus, .jiraComment, .jiraApprovers: return .jira
        default: return .pullRequests
        }
    }
}

public enum AlertLog {
    public static let maxEntries = 300
    public static let keepDays = 30

    /// Adds the alerts of one moment, newest first, and drops what is too old or beyond the cap.
    public static func appending(_ changes: [PRChange], to log: [AlertEntry], now: Date = Date()) -> [AlertEntry] {
        // The same alert again with nothing else in between (a flickering state, a re-read list) adds no information.
        let recentWindow = now.addingTimeInterval(-12 * 3600)
        var added: [AlertEntry] = []
        for change in changes {
            let latest = (added + log).first { $0.prID == change.prID }
            if let latest, latest.kind == change.kind, latest.date >= recentWindow { continue }
            added.append(AlertEntry(change, date: now))
        }
        let cutoff = now.addingTimeInterval(-Double(keepDays) * 86_400)
        return Array((added + log).filter { $0.date >= cutoff }.prefix(maxEntries))
    }

    /// Entries grouped by calendar day, newest day first (entries keep their newest-first order).
    public static func groupedByDay(_ entries: [AlertEntry], calendar: Calendar = .current) -> [(day: Date, entries: [AlertEntry])] {
        var groups: [(day: Date, entries: [AlertEntry])] = []
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let day = calendar.startOfDay(for: entry.date)
            if let index = groups.firstIndex(where: { $0.day == day }) { groups[index].entries.append(entry) } else { groups.append((day, [entry])) }
        }
        return groups
    }

    /// Entries that no longer decode (kinds that were removed, like the old Claude and focus alerts) are skipped, not fatal.
    public static func decode(_ json: String?) -> [AlertEntry] {
        struct Lossy: Decodable {
            let entry: AlertEntry?
            init(from decoder: Decoder) throws { entry = try? AlertEntry(from: decoder) }
        }
        let all = json?.data(using: .utf8).flatMap { try? JSONDecoder().decode([Lossy].self, from: $0) } ?? []
        return all.compactMap(\.entry)
    }

    public static func encode(_ entries: [AlertEntry]) -> String {
        (try? JSONEncoder().encode(entries)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}
