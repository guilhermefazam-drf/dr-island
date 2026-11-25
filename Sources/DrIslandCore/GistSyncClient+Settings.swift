import Foundation

extension GistSyncClient {
    /// The file holding the preferences, next to the history in the same secret gist.
    public static let settingsFileName = "dr-island-settings.json"
    public static let sharedDescription = "Dr Island: histórico de avisos e definições (sincronizado pela app, não editar)"

    /// The gist's settings, or nil when it has none yet.
    public func readSettings(id: String) throws -> SettingsBackup? {
        try Self.parseSettings(run(["api", "gists/\(id)"]))
    }

    public func updateSettings(id: String, _ backup: SettingsBackup) throws {
        _ = try run(["api", "gists/\(id)", "--method", "PATCH", "--input", "-"], input: Self.settingsBody(backup))
    }

    // MARK: Pure parts (tested)

    static func settingsBody(_ backup: SettingsBackup) -> Data {
        let body: [String: Any] = [
            "description": sharedDescription,
            "files": [settingsFileName: ["content": String(decoding: backup.encoded(), as: UTF8.self)]],
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    static func parseSettings(_ data: Data) throws -> SettingsBackup? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [String: Any] else { throw GistSyncError.invalidResponse }
        guard let file = files[settingsFileName] as? [String: Any] else { return nil }
        if file["truncated"] as? Bool == true { throw GistSyncError.truncated }
        guard let content = file["content"] as? String, let backup = SettingsBackup.decode(Data(content.utf8)) else {
            throw GistSyncError.invalidResponse
        }
        return backup
    }
}
