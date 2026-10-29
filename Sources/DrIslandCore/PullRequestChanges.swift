import Foundation

/// The parts of a pull request whose change is worth telling the user about. Cached locally between runs
/// so a change that happened while the app was closed is still noticed. Holds no secrets.
public struct PRFingerprint: Codable, Equatable, Sendable {
    public var id: String
    public var ref: String          // "repo#123"
    public var role: PullRequest.Role
    public var ci: CIState
    public var review: ReviewState
    public var hasConflicts: Bool
    public var commentCount: Int?
    /// Comments written by the user; `nil` when stored by an older version.
    public var ownCommentCount: Int?

    public init(_ pr: PullRequest) {
        id = pr.id
        ref = "\(pr.repository.split(separator: "/").last.map(String.init) ?? pr.repository)#\(pr.number)"
        role = pr.role; ci = pr.ci; review = pr.review; hasConflicts = pr.hasConflicts; commentCount = pr.commentCount; ownCommentCount = pr.ownCommentCount
    }
}

public struct PRChange: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case reviewRequested, ciFailed, ciPassed, approved, changesRequested, conflicts, left
        case newComment, mentioned, merged
        /// Jira tasks, same channels (see `JiraDiff`).
        case jiraNew, jiraStatus, jiraComment, jiraApprovers
        /// A new Claude session started. Only ever shown in the mini island: never logged, never counted as unseen.
        case claudeSession
        /// The network dropped or came back. Mini island only, like `claudeSession`.
        case offline, online
        /// The morning briefing, announced in the mini island. Mini island only, like `claudeSession`.
        case briefing
        /// The Doutor Finanças logo shown once at launch. Mini island only, like `claudeSession`.
        case splash

        /// The source of the alert, written before its message.
        public var origin: String {
            switch self {
            case .jiraNew, .jiraStatus, .jiraComment, .jiraApprovers: return "JIRA"
            case .claudeSession: return "CLAUDE"
            case .offline, .online: return "REDE"
            case .briefing: return "RESUMO"
            case .splash: return "DR ISLAND"
            default: return "GIT"
            }
        }
    }

    /// How loud the change is; also picks its colour.
    public enum Tone: Int, Comparable, Sendable {
        case neutral = 0, success, info, warning, critical
        public static func < (a: Tone, b: Tone) -> Bool { a.rawValue < b.rawValue }
    }

    public var id: String { prID + "|" + kind.rawValue }
    public let prID: String
    public let ref: String
    public let title: String
    public let kind: Kind

    public init(prID: String, ref: String, title: String, kind: Kind) {
        self.prID = prID; self.ref = ref; self.title = title; self.kind = kind
    }

    public var tone: Tone {
        switch kind {
        case .ciFailed, .offline: return .critical
        case .changesRequested, .conflicts: return .warning
        case .reviewRequested: return .info
        case .approved, .ciPassed: return .success
        case .left: return .neutral
        case .merged, .claudeSession, .online: return .success
        case .briefing, .splash: return .info
        case .newComment, .mentioned, .jiraNew, .jiraStatus, .jiraComment, .jiraApprovers: return .info
        }
    }

    /// Short text for the tag on the row.
    public var label: String {
        switch kind {
        case .reviewRequested: return "novo review"
        case .ciFailed: return "CI falhou"
        case .ciPassed: return "CI passou"
        case .approved: return "aprovado"
        case .changesRequested: return "alterações"
        case .conflicts: return "conflitos"
        case .left: return "fechado"
        case .newComment, .jiraComment: return "comentário"
        case .jiraApprovers: return "aprovadores"
        case .claudeSession: return "nova"
        case .offline: return "offline"
        case .online: return "online"
        case .briefing: return "resumo"
        case .splash: return "olá"
        case .mentioned: return "menção"
        case .merged: return "merged"
        case .jiraNew: return "nova"
        case .jiraStatus: return title
        }
    }

    /// Where the alert comes from, shown before its text: "GIT - PR aprovado: acme#1", "JIRA - Novo comentário em A-1".
    public var message: String { "\(kind.origin) - \(body)" }

    private var body: String {
        switch kind {
        case .reviewRequested: return "Review pedido: \(ref)"
        case .ciFailed: return "CI falhou: \(ref)"
        case .ciPassed: return "CI passou: \(ref)"
        case .approved: return "PR aprovado: \(ref)"
        case .changesRequested: return "Alterações pedidas: \(ref)"
        case .conflicts: return "Conflitos: \(ref)"
        case .left: return "Saiu da lista (fechado ou merged): \(ref)"
        case .newComment: return "Novo comentário: \(ref)"
        case .mentioned: return "Mencionado em \(ref)"
        case .merged: return "PR merged: \(ref)"
        case .jiraNew: return "Nova task: \(ref)"
        case .jiraStatus: return "\(ref) passou a «\(title)»"
        case .jiraComment: return "Novo comentário em \(ref)"
        case .claudeSession: return "Nova sessão do Claude iniciada"
        case .offline: return "Sem ligação à internet"
        case .online: return "Ligação restabelecida"
        case .briefing: return title
        case .splash: return "Doutor Finanças"
        case .jiraApprovers: return title.isEmpty ? "Aprovadores de \(ref) removidos" : "Aprovadores de \(ref): \(title)"
        }
    }
}

public enum PullRequestDiff {
    public static func fingerprints(of snapshot: PullRequestSnapshot) -> [PRFingerprint] {
        (snapshot.authored + snapshot.reviewRequested + snapshot.mentions).map(PRFingerprint.init)
    }

    /// Changes between the cached fingerprints and a new, successful reading.
    /// `old == nil` means there is no cache yet: that reading is only the baseline and reports nothing.
    /// Only the user's own PRs report CI, review and conflict changes; review requests report arrival and departure.
    public static func changes(from old: [PRFingerprint]?, to snapshot: PullRequestSnapshot) -> [PRChange] {
        guard let old else { return [] }
        let previous = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [PRChange] = []
        var currentIDs = Set<String>()

        for pr in snapshot.authored + snapshot.reviewRequested + snapshot.mentions {
            currentIDs.insert(pr.id)
            func change(_ kind: PRChange.Kind) { result.append(PRChange(prID: pr.id, ref: PRFingerprint(pr).ref, title: pr.title, kind: kind)) }
            guard let before = previous[pr.id] else {
                if pr.role == .reviewRequested, pr.reviewPending { change(.reviewRequested) }
                if pr.role == .mentioned { change(.mentioned) }
                continue
            }
            // Only other people's comments count: the user's own never raise the alert.
            if let now = pr.commentCount, let was = before.commentCount, pr.role != .reviewRequested,
               now - (pr.ownCommentCount ?? 0) > was - (before.ownCommentCount ?? 0) { change(.newComment) }
            guard pr.role == .authored, before.role == .authored else { continue }
            if pr.ci == .failing, before.ci != .failing { change(.ciFailed) }
            if pr.ci == .passing, before.ci != .passing { change(.ciPassed) }
            if pr.review == .approved, before.review != .approved { change(.approved) }
            if pr.review == .changesRequested, before.review != .changesRequested { change(.changesRequested) }
            if pr.hasConflicts, !before.hasConflicts { change(.conflicts) }
        }
        for gone in old where !currentIDs.contains(gone.id) && !snapshot.unlistedOpenIDs.contains(gone.id) && gone.role != .mentioned {
            let merged = gone.role == .authored && snapshot.mergedIDs.contains(gone.id)
            result.append(PRChange(prID: gone.id, ref: gone.ref, title: "", kind: merged ? .merged : .left))
        }
        return result
    }
}

/// What the user chose to silence: a single PR or a whole repository, for a while or for good.
public struct PRMute: Codable, Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String        // "pr:<url>" or "repo:<owner/name>"
    public let label: String
    public let until: Date?       // nil = until removed

    public init(key: String, label: String, until: Date?) { self.key = key; self.label = label; self.until = until }

    public static func pr(_ pr: PullRequest, until: Date?) -> PRMute {
        PRMute(key: "pr:" + pr.id, label: "\(pr.repository)#\(pr.number)", until: until)
    }
    public static func repository(_ pr: PullRequest, until: Date?) -> PRMute {
        PRMute(key: "repo:" + pr.repository, label: pr.repository, until: until)
    }
}

public enum PRMutes {
    public static func decode(_ json: String) -> [PRMute] {
        json.data(using: .utf8).flatMap { try? JSONDecoder().decode([PRMute].self, from: $0) } ?? []
    }
    public static func encode(_ list: [PRMute]) -> String {
        (try? JSONEncoder().encode(list)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    /// Adds a mute, replacing an earlier one for the same target, and drops expired ones.
    public static func adding(_ mute: PRMute, to list: [PRMute], now: Date = Date()) -> [PRMute] {
        active(list.filter { $0.key != mute.key } + [mute], now: now)
    }
    public static func removing(key: String, from list: [PRMute]) -> [PRMute] { list.filter { $0.key != key } }
    public static func active(_ list: [PRMute], now: Date = Date()) -> [PRMute] { list.filter { $0.until.map { $0 > now } ?? true } }

    /// `prID` is the PR's URL (https://github.com/owner/repo/pull/N), which also carries its repository.
    public static func isMuted(prID: String, in list: [PRMute], now: Date = Date()) -> Bool {
        let parts = URL(string: prID)?.pathComponents.filter { $0 != "/" } ?? []
        let repo = parts.count >= 2 ? parts[0] + "/" + parts[1] : nil
        return active(list, now: now).contains { $0.key == "pr:" + prID || (repo != nil && $0.key == "repo:" + repo!) }
    }
}

/// Jira task fingerprint kept between runs, like `PRFingerprint`.
public struct JiraFingerprint: Codable, Equatable, Sendable {
    public var key: String
    public var status: String
    public var commentCount: Int?
    /// `nil` when stored by an older version, so the first reading after an update does not announce every task.
    public var approvers: [String]?
    /// Comments by the user (nil when unknown or stored by an older version).
    public var ownCommentCount: Int?
    public init(_ task: JiraTask, me: String? = nil) {
        key = task.key; status = task.status; commentCount = task.commentCount; approvers = task.approvers
        ownCommentCount = me.flatMap { me in task.commentAuthors.map { $0.filter { $0 == me }.count } }
    }
}

public enum JiraDiff {
    public static func fingerprints(of tasks: [JiraTask], me: String? = nil) -> [JiraFingerprint] { tasks.map { JiraFingerprint($0, me: me) } }

    /// `old == nil` is the first reading: it only becomes the baseline.
    public static func changes(from old: [JiraFingerprint]?, to tasks: [JiraTask], me: String? = nil) -> [PRChange] {
        guard let old else { return [] }
        let previous = Dictionary(old.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [PRChange] = []
        for task in tasks {
            func change(_ kind: PRChange.Kind, _ title: String) { result.append(PRChange(prID: "jira-" + task.key, ref: task.key, title: title, kind: kind)) }
            guard let before = previous[task.key] else { change(.jiraNew, task.summary); continue }
            if task.status != before.status { change(.jiraStatus, task.status) }
            // Only other people's comments: the user's own never raise the alert.
            let mine = JiraFingerprint(task, me: me).ownCommentCount ?? 0
            if let now = task.commentCount, let was = before.commentCount, now - mine > was - (before.ownCommentCount ?? 0) { change(.jiraComment, task.summary) }
            if let now = task.approvers, let was = before.approvers, now != was { change(.jiraApprovers, now.joined(separator: ", ")) }
        }
        return result
    }
}
