import Foundation
import DrIslandCore

/// Reads Claude Code transcripts from `~/.claude/projects` (read-only) and groups them into 5h session blocks.
/// Parsed entries are cached per file (path + modification date + size), so repeated scans only re-read the
/// transcripts that changed, normally just the active session's.
enum LocalUsageScanner {
    /// Enough history to infer a "biggest session" limit without scanning the whole archive.
    static let historyDays = 14

    private struct CachedFile {
        let modified: Date
        let size: Int
        let entries: [LogEntry]
    }

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var files: [String: CachedFile] = [:]

        func get(_ path: String, modified: Date, size: Int) -> [LogEntry]? {
            lock.lock(); defer { lock.unlock() }
            guard let cached = files[path], cached.modified == modified, cached.size == size else { return nil }
            return cached.entries
        }

        func set(_ path: String, _ file: CachedFile) {
            lock.lock(); defer { lock.unlock() }
            files[path] = file
        }

        func prune(keeping paths: Set<String>) {
            lock.lock(); defer { lock.unlock() }
            files = files.filter { paths.contains($0.key) }
        }
    }

    private static let cache = Cache()

    static func scan(now: Date = Date()) async -> [UsageBlock] {
        LocalUsageEstimator.blocks(from: await entries(now: now))
    }

    /// Every response of the last `historyDays`, for blocks and for cost summaries.
    static func entries(now: Date = Date()) async -> [LogEntry] {
        await Task.detached(priority: .utility) { scanSync(now: now) }.value
    }

    private static func scanSync(now: Date) -> [LogEntry] {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        let cutoff = now.addingTimeInterval(-Double(historyDays) * 86_400)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey, .fileSizeKey]
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { return [] }
        var entries: [LogEntry] = []
        var seenPaths = Set<String>()
        for case let url as URL in files where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true, let modified = values?.contentModificationDate, modified >= cutoff else { continue }
            let size = values?.fileSize ?? 0
            seenPaths.insert(url.path)
            if let cached = cache.get(url.path, modified: modified, size: size) {
                entries += cached
            } else if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
                let parsed = LogLineParser.parse(file: data, since: cutoff)
                cache.set(url.path, CachedFile(modified: modified, size: size, entries: parsed))
                entries += parsed
            }
        }
        cache.prune(keeping: seenPaths)
        // The cutoff moves forward between scans, so drop cached entries that fell out of the window.
        return entries.filter { $0.timestamp >= cutoff }
    }
}
