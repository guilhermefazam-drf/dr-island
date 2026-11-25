import Foundation
import Testing
@testable import DrIslandCore

@Suite struct SettingsSyncTests {
    private let allowed: Set<String> = ["islandTheme", "showWeekly", "jiraMaxTasks", "animSpeed"]
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 2_000)

    private func backup(_ values: [String: SettingValue], at date: Date, device: String = "mac") -> SettingsBackup {
        SettingsBackup(updatedAt: date, device: device, values: values)
    }

    @Test func roundTripKeepsEachKind() {
        let b = backup(["a": .bool(true), "b": .int(3), "c": .double(0.5), "d": .string("claro")], at: t1, device: "MacBook")
        #expect(SettingsBackup.decode(b.encoded()) == b)
    }

    @Test func unknownValuesAreSkippedNotFatal() {
        let json = #"{"version":1,"updatedAt":0,"device":"x","values":{"ok":{"int":2},"bad":{"weird":1}}}"#
        let b = SettingsBackup.decode(Data(json.utf8))
        #expect(b?.values == ["ok": .int(2)])
        #expect(SettingsBackup.decode(Data("not json".utf8)) == nil)
    }

    @Test func noRemoteUploads() {
        #expect(SettingsSync.plan(local: backup(["islandTheme": .string("claro")], at: t0), remote: nil, firstSync: true, allowed: allowed) == .upload)
    }

    @Test func firstSyncAdoptsTheGistEvenIfLocalLooksNewer() {
        let local = backup(["islandTheme": .string("grafite")], at: t1)
        let remote = backup(["islandTheme": .string("aurora")], at: t0)
        #expect(SettingsSync.plan(local: local, remote: remote, firstSync: true, allowed: allowed) == .apply(["islandTheme": .string("aurora")]))
    }

    @Test func newestWins() {
        let older = backup(["islandTheme": .string("grafite")], at: t0)
        let newer = backup(["islandTheme": .string("claro")], at: t1)
        #expect(SettingsSync.plan(local: newer, remote: older, firstSync: false, allowed: allowed) == .upload)
        #expect(SettingsSync.plan(local: older, remote: newer, firstSync: false, allowed: allowed) == .apply(["islandTheme": .string("claro")]))
    }

    @Test func sameValuesDoNothing() {
        let a = backup(["showWeekly": .bool(true)], at: t0)
        let b = backup(["showWeekly": .bool(true)], at: t1)
        #expect(SettingsSync.plan(local: a, remote: b, firstSync: false, allowed: allowed) == .none)
    }

    @Test func onlyAllowedKeysOfTheSameKindAreApplied() {
        let local = ["jiraMaxTasks": SettingValue.int(20), "showWeekly": .bool(true)]
        let remote: [String: SettingValue] = [
            "jiraMaxTasks": .string("lots"),       // wrong kind
            "showWeekly": .bool(false),            // fine
            "githubGhPath": .string("/tmp/evil"),  // not allowed
            "animSpeed": .double(2),               // allowed, not set here yet
        ]
        #expect(SettingsSync.applicable(remote, over: local, allowed: allowed) == ["showWeekly": .bool(false), "animSpeed": .double(2)])
    }

    @Test func newerRemoteWithNothingApplicableUploads() {
        let local = backup(["islandTheme": .string("claro")], at: t0)
        let remote = backup(["islandTheme": .string("claro"), "githubGhPath": .string("/x")], at: t1)
        #expect(SettingsSync.plan(local: local, remote: remote, firstSync: false, allowed: allowed) == .upload)
    }

    @Test func gistBodyAndParsing() throws {
        let b = backup(["islandTheme": .string("claro")], at: t1)
        let body = try #require(JSONSerialization.jsonObject(with: GistSyncClient.settingsBody(b)) as? [String: Any])
        let files = try #require(body["files"] as? [String: Any])
        let file = try #require(files[GistSyncClient.settingsFileName] as? [String: Any])
        let content = try #require(file["content"] as? String)
        #expect(SettingsBackup.decode(Data(content.utf8)) == b)
        #expect(files[GistSyncClient.fileName] == nil)   // the history file is left alone

        let gist = try JSONSerialization.data(withJSONObject: ["files": [GistSyncClient.settingsFileName: ["content": content, "truncated": false]]])
        #expect(try GistSyncClient.parseSettings(gist) == b)
        let without = try JSONSerialization.data(withJSONObject: ["files": [GistSyncClient.fileName: ["content": "{}"]]])
        #expect(try GistSyncClient.parseSettings(without) == nil)
    }
}
