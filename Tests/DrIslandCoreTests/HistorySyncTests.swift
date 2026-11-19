import Foundation
import Testing
@testable import DrIslandCore

@Suite struct HistorySyncTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func entry(_ minutesAgo: Double, _ kind: PRChange.Kind = .approved) -> AlertEntry {
        AlertEntry(date: now.addingTimeInterval(-minutesAgo * 60), kind: kind, prID: "pr", ref: "#1", message: "GIT - PR merged: #1 Título")
    }

    @Test func mergeIsAUnionByIdNewestFirst() {
        let shared = entry(30), onlyHere = entry(10), onlyThere = entry(20)
        let merged = HistorySync.merge(HistoryBackup(entries: [onlyHere, shared]), HistoryBackup(entries: [shared, onlyThere]), now: now)
        #expect(merged.entries.map(\.id) == [onlyHere.id, onlyThere.id, shared.id])
    }

    @Test func clearOnOneMacIsNotUndoneByTheOther() {
        let old = entry(60), new = entry(5)
        let cleared = HistoryBackup(entries: [], clearedAt: now.addingTimeInterval(-30 * 60))
        let merged = HistorySync.merge(cleared, HistoryBackup(entries: [new, old]), now: now)
        #expect(merged.entries.map(\.id) == [new.id])
        #expect(merged.clearedAt == cleared.clearedAt)
    }

    @Test func mergeDropsExpiredAndCaps() {
        let expired = entry(Double(AlertLog.keepDays + 1) * 24 * 60)
        let many = (0..<(AlertLog.maxEntries + 5)).map { entry(Double($0)) }
        let merged = HistorySync.merge(HistoryBackup(entries: many), HistoryBackup(entries: [expired]), now: now)
        #expect(merged.entries.count == AlertLog.maxEntries)
        #expect(!merged.entries.contains { $0.id == expired.id })
    }

    @Test func planWritesOnlyWhereSomethingIsMissing() {
        let a = entry(1), b = entry(2)
        let first = HistorySync.plan(local: HistoryBackup(entries: [a]), remote: nil, now: now)
        #expect(!first.updateLocal && first.updateRemote)

        let both = HistorySync.plan(local: HistoryBackup(entries: [a]), remote: HistoryBackup(entries: [b]), now: now)
        #expect(both.updateLocal && both.updateRemote && both.merged.entries.count == 2)

        let inSync = HistorySync.plan(local: HistoryBackup(entries: [a, b]), remote: HistoryBackup(entries: [b, a]), now: now)
        #expect(!inSync.updateLocal && !inSync.updateRemote)
    }

    @Test func backupRoundTripsExactlyAndSkipsUnknownKinds() throws {
        let backup = HistoryBackup(entries: [entry(1.234)], clearedAt: now.addingTimeInterval(-0.5))
        #expect(HistoryBackup.decode(backup.encoded()) == backup)

        var json = try #require(String(data: backup.encoded(), encoding: .utf8))
        json = json.replacingOccurrences(of: "\"approved\"", with: "\"oldRemovedKind\"")
        #expect(HistoryBackup.decode(Data(json.utf8))?.entries.isEmpty == true)
        #expect(HistoryBackup.decode(Data("not json".utf8)) == nil)
    }

    // MARK: OneDrive

    @Test func oneDriveFileNamePerMac() {
        #expect(OneDriveBackup.fileName(device: "MacBook Pro do Guilherme") == "dr-island-historico-macbook-pro-do-guilherme.json")
        #expect(OneDriveBackup.fileName(device: "  ") == "dr-island-historico-mac.json")
    }

    @Test func oneDriveRootsPreferWorkAndMergeEveryMac() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("drisland-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: base) }
        for name in ["OneDrive-Personal", "OneDrive-Doutor Finanças", "Dropbox"] {
            try fm.createDirectory(at: base.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let roots = OneDriveBackup.roots(in: base).map(\.lastPathComponent)
        #expect(roots == ["OneDrive-Doutor Finanças", "OneDrive-Personal"])

        let folder = OneDriveBackup.folder(root: base.appendingPathComponent(roots[0]))
        #expect(OneDriveBackup.read(folder: folder, now: now) == nil)
        let a = entry(1), b = entry(2)
        try OneDriveBackup.write(HistoryBackup(entries: [a]), folder: folder, device: "Mac A")
        try OneDriveBackup.write(HistoryBackup(entries: [b]), folder: folder, device: "Mac B")
        try Data("a meio da sincronização".utf8).write(to: folder.appendingPathComponent("dr-island-historico-mac-c.json"))
        #expect(OneDriveBackup.read(folder: folder, now: now)?.entries.map(\.id) == [a.id, b.id])
    }

    // MARK: Gist

    @Test func gistBodyIsSecretOnCreateOnly() throws {
        let backup = HistoryBackup(entries: [entry(1)])
        let created = try #require(JSONSerialization.jsonObject(with: GistSyncClient.body(backup, create: true)) as? [String: Any])
        #expect(created["public"] as? Bool == false)
        #expect(created["description"] as? String == GistSyncClient.gistDescription)
        let updated = try #require(JSONSerialization.jsonObject(with: GistSyncClient.body(backup, create: false)) as? [String: Any])
        #expect(updated["public"] == nil && updated["description"] == nil)

        let content = try #require(((updated["files"] as? [String: Any])?[GistSyncClient.fileName] as? [String: Any])?["content"] as? String)
        #expect(HistoryBackup.decode(Data(content.utf8)) == backup)
    }

    @Test func gistParsing() throws {
        let backup = HistoryBackup(entries: [entry(1)])
        let content = String(decoding: backup.encoded(), as: UTF8.self)
        func gist(_ file: [String: Any]) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["id": "abc", "files": [GistSyncClient.fileName: file]])
        }
        #expect(try GistSyncClient.parseGist(gist(["content": content, "truncated": false])) == backup)
        #expect(throws: GistSyncError.truncated) { try GistSyncClient.parseGist(gist(["content": "", "truncated": true])) }
        #expect(throws: GistSyncError.notFound) { try GistSyncClient.parseGist(Data("{\"files\":{}}".utf8)) }
        #expect(GistSyncClient.firstID("\n abc123 \ndef\n") == "abc123")
        #expect(GistSyncClient.firstID("") == nil)
    }
}
