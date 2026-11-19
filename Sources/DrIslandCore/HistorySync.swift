import Foundation

/// Where the alert history is backed up. The history always stays in this Mac too; the backup only adds a copy.
public enum HistorySyncMode: String, CaseIterable, Sendable {
    /// A secret gist in the user's GitHub account, through `gh` (default).
    case gist
    /// A file in the OneDrive folder the Microsoft app syncs on this Mac.
    case oneDrive
    /// Only this Mac: no backup.
    case local

    public var title: String {
        switch self {
        case .gist: return "Gist do GitHub"
        case .oneDrive: return "OneDrive"
        case .local: return "Só neste Mac"
        }
    }
}

/// The alert history as it is written to a backup: the entries plus when it was last cleared,
/// so a "Limpar histórico" on one Mac is not undone by the copy of another.
public struct HistoryBackup: Equatable, Sendable {
    public var entries: [AlertEntry]
    /// Entries at or before this date were cleared and are dropped on merge. `nil` = never cleared.
    public var clearedAt: Date?

    public init(entries: [AlertEntry] = [], clearedAt: Date? = nil) {
        self.entries = entries; self.clearedAt = clearedAt
    }

    private struct Wire: Codable {
        var version: Int
        var clearedAt: Date?
        var entries: [Lossy]
    }

    /// Entries that no longer decode (removed kinds) are skipped, like in `AlertLog.decode`.
    private struct Lossy: Codable {
        let entry: AlertEntry?
        init(_ entry: AlertEntry) { self.entry = entry }
        init(from decoder: Decoder) throws { entry = try? AlertEntry(from: decoder) }
        func encode(to encoder: Encoder) throws { try entry.encode(to: encoder) }
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    public func encoded() -> Data {
        let wire = Wire(version: 1, clearedAt: clearedAt, entries: entries.map(Lossy.init))
        return (try? Self.encoder().encode(wire)) ?? Data("{\"version\":1,\"entries\":[]}".utf8)
    }

    /// `nil` when the data is not a backup at all (so a broken file is reported instead of being taken as empty).
    public static func decode(_ data: Data) -> HistoryBackup? {
        // Dates stay in the default (exact) encoding: a clear must not round away the entries just before it.
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        return HistoryBackup(entries: wire.entries.compactMap(\.entry), clearedAt: wire.clearedAt)
    }
}

public enum HistorySync {
    /// The union of two histories by entry id, newest first, without what was cleared, too old or beyond the cap.
    public static func merge(_ a: HistoryBackup, _ b: HistoryBackup, now: Date = Date()) -> HistoryBackup {
        let clearedAt = [a.clearedAt, b.clearedAt].compactMap { $0 }.max()
        var seen = Set<UUID>()
        let cutoff = now.addingTimeInterval(-Double(AlertLog.keepDays) * 86_400)
        let entries = (a.entries + b.entries)
            .filter { seen.insert($0.id).inserted }
            .filter { entry in entry.date >= cutoff && (clearedAt.map { entry.date > $0 } ?? true) }
            .sorted { $0.date > $1.date }
        return HistoryBackup(entries: Array(entries.prefix(AlertLog.maxEntries)), clearedAt: clearedAt)
    }

    /// What one sync has to do: the merged history, and whether this Mac and the backup each need it written.
    public struct Plan: Equatable, Sendable {
        public let merged: HistoryBackup
        public let updateLocal: Bool
        public let updateRemote: Bool
    }

    /// `remote == nil` means there is no backup yet: it is created with what this Mac has.
    public static func plan(local: HistoryBackup, remote: HistoryBackup?, now: Date = Date()) -> Plan {
        let merged = merge(local, remote ?? HistoryBackup(), now: now)
        return Plan(merged: merged,
                    updateLocal: !same(merged, local),
                    updateRemote: remote.map { !same(merged, $0) } ?? true)
    }

    /// Same entries and same clear date; order and dropped-but-expired entries do not count as a change.
    static func same(_ a: HistoryBackup, _ b: HistoryBackup) -> Bool {
        a.clearedAt == b.clearedAt && Set(a.entries.map(\.id)) == Set(b.entries.map(\.id))
    }
}

// MARK: - OneDrive

/// The OneDrive folder the Microsoft app syncs (`~/Library/CloudStorage/OneDrive-<organização>`).
/// Each Mac writes its own file, so two Macs never write the same file and OneDrive never makes conflict copies.
public enum OneDriveBackup {
    public static let folderName = "Dr Island"
    static let filePrefix = "dr-island-historico-"

    public static var defaultCloudStorage: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage", isDirectory: true)
    }

    /// OneDrive roots, the work/school ones ("OneDrive-Empresa") before the personal one.
    public static func roots(in cloudStorage: URL = defaultCloudStorage, fileManager: FileManager = .default) -> [URL] {
        let names = (try? fileManager.contentsOfDirectory(atPath: cloudStorage.path)) ?? []
        return names
            .filter { $0.hasPrefix("OneDrive") }
            .sorted { rank($0) == rank($1) ? $0 < $1 : rank($0) < rank($1) }
            .map { cloudStorage.appendingPathComponent($0, isDirectory: true) }
    }

    private static func rank(_ name: String) -> Int { name.lowercased().contains("personal") ? 1 : 0 }

    public static func folder(root: URL) -> URL { root.appendingPathComponent(folderName, isDirectory: true) }

    public static func fileName(device: String) -> String {
        let cleaned = device.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let slug = String(cleaned).split(separator: "-").joined(separator: "-")
        return filePrefix + (slug.isEmpty ? "mac" : slug) + ".json"
    }

    /// All Macs' files merged. `nil` when there is no file yet. A file that is being synced (and does not parse yet) is skipped.
    public static func read(folder: URL, now: Date = Date(), fileManager: FileManager = .default) -> HistoryBackup? {
        let names = ((try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasPrefix(filePrefix) && $0.hasSuffix(".json") }
        let backups = names.compactMap { name in
            (try? Data(contentsOf: folder.appendingPathComponent(name))).flatMap(HistoryBackup.decode)
        }
        guard !backups.isEmpty else { return nil }
        return backups.reduce(HistoryBackup()) { HistorySync.merge($0, $1, now: now) }
    }

    public static func write(_ backup: HistoryBackup, folder: URL, device: String, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try backup.encoded().write(to: folder.appendingPathComponent(fileName(device: device)), options: .atomic)
    }

    /// One sync: reads every Mac's file, merges with this Mac and rewrites this Mac's file when the backup lacks something.
    public static func sync(_ local: HistoryBackup, folder: URL, device: String, now: Date = Date()) throws -> HistorySync.Plan {
        let plan = HistorySync.plan(local: local, remote: read(folder: folder, now: now), now: now)
        if plan.updateRemote { try write(plan.merged, folder: folder, device: device) }
        return plan
    }
}

// MARK: - Gist

public enum GistSyncError: Error, Equatable {
    case notFound
    case truncated
    case invalidResponse
}

/// A secret gist in the user's GitHub account, read and written through the user's `gh` (no token handled by this app).
/// "Secret" means unlisted, not private: whoever has the URL can open it.
public struct GistSyncClient: Sendable {
    public static let fileName = "dr-island-sync.json"
    public static let gistDescription = "Dr Island: histórico de avisos (sincronizado pela app, não editar)"

    let gh: String

    /// `nil` when `gh` is not installed.
    public init?(ghPath: String? = nil) {
        guard let gh = GitHubClient.locateGh(override: ghPath) else { return nil }
        self.gh = gh
    }

    /// The account `gh` is logged in to: the gist is only reused while it is the same.
    public func login() throws -> String {
        let out = try run(["api", "user", "--jq", ".login"])
        let login = String(decoding: out, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !login.isEmpty else { throw GistSyncError.invalidResponse }
        return login
    }

    /// The id of the user's gist holding the history, if there is one.
    public func find() throws -> String? {
        let out = try run(["api", "gists", "--paginate", "--jq", ".[] | select(.files[\"\(Self.fileName)\"] != null) | .id"])
        return Self.firstID(String(decoding: out, as: UTF8.self))
    }

    public func read(id: String) throws -> HistoryBackup {
        try Self.parseGist(run(["api", "gists/\(id)"]))
    }

    /// Creates the secret gist and returns its id.
    public func create(_ backup: HistoryBackup) throws -> String {
        let out = try run(["api", "gists", "--method", "POST", "--input", "-"], input: Self.body(backup, create: true))
        guard let id = (try? JSONSerialization.jsonObject(with: out) as? [String: Any])?["id"] as? String else {
            throw GistSyncError.invalidResponse
        }
        return id
    }

    public func update(id: String, _ backup: HistoryBackup) throws {
        _ = try run(["api", "gists/\(id)", "--method", "PATCH", "--input", "-"], input: Self.body(backup, create: false))
    }

    public struct SyncResult: Sendable {
        public let plan: HistorySync.Plan
        public let gistID: String
        public let login: String
    }

    /// One sync. The known gist is only trusted for the account it was found with; otherwise (or if it was deleted)
    /// the user's gists are searched, and a new secret gist is created when there is none.
    public func sync(_ local: HistoryBackup, knownID: String?, knownLogin: String?, now: Date = Date()) throws -> SyncResult {
        let login = try login()
        var id = login == knownLogin ? knownID : nil
        var remote: HistoryBackup?
        if let known = id {
            do { remote = try read(id: known) } catch GistSyncError.notFound { id = nil }
        }
        if id == nil, let found = try find() {
            id = found
            remote = try read(id: found)
        }
        let plan = HistorySync.plan(local: local, remote: remote, now: now)
        if let id {
            if plan.updateRemote { try update(id: id, plan.merged) }
            return SyncResult(plan: plan, gistID: id, login: login)
        }
        return SyncResult(plan: plan, gistID: try create(plan.merged), login: login)
    }

    public static func url(id: String) -> URL? { URL(string: "https://gist.github.com/\(id)") }

    // MARK: Pure parts (tested)

    static func firstID(_ output: String) -> String? {
        output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    }

    static func body(_ backup: HistoryBackup, create: Bool) -> Data {
        var body: [String: Any] = ["files": [fileName: ["content": String(decoding: backup.encoded(), as: UTF8.self)]]]
        if create { body["public"] = false; body["description"] = gistDescription }
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    static func parseGist(_ data: Data) throws -> HistoryBackup {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let file = (json["files"] as? [String: Any])?[fileName] as? [String: Any] else { throw GistSyncError.notFound }
        if file["truncated"] as? Bool == true { throw GistSyncError.truncated }
        guard let content = file["content"] as? String, let backup = HistoryBackup.decode(Data(content.utf8)) else {
            throw GistSyncError.invalidResponse
        }
        return backup
    }

    private func run(_ arguments: [String], input: Data? = nil) throws -> Data {
        do { return try GitHubClient.run(gh, arguments, input: input) } catch GitHubError.failed(let line) where line.contains("404") {
            throw GistSyncError.notFound
        }
    }
}
