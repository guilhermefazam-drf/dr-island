import Foundation

/// Closed sprints on disk, one JSON file each: a closed sprint never changes, so after the first read the velocity
/// chart and an old sprint's burndown open without asking Jira again. The file name carries a format version, so a
/// change to `SprintSnapshot` simply misses the old files.
public struct SprintSnapshotFileCache: SprintMetricsCache {
    static let version = 1
    let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `~/Library/Application Support/DrIsland/sprints`.
    public static func standard() -> SprintSnapshotFileCache {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return SprintSnapshotFileCache(directory: base.appendingPathComponent("DrIsland/sprints", isDirectory: true))
    }

    func url(for sprintID: Int) -> URL { directory.appendingPathComponent("v\(Self.version)-\(sprintID).json") }

    public func load(sprintID: Int) -> SprintSnapshot? {
        guard let data = try? Data(contentsOf: url(for: sprintID)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(SprintSnapshot.self, from: data)
    }

    /// Only closed sprints are kept: an open one changes and must be read fresh.
    public func save(_ snapshot: SprintSnapshot) {
        guard snapshot.sprint.state == "closed" else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(for: snapshot.sprint.id), options: .atomic)
    }
}
