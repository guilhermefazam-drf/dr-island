import Foundation

/// How this Mac's preferences and the gist's copy are reconciled. The most recent change wins; a Mac that has
/// never synced its settings adopts the gist's (so a new Mac does not overwrite them with its defaults).
public enum SettingsSync {
    public enum Action: Equatable, Sendable {
        case none
        /// Write this Mac's settings to the gist.
        case upload
        /// Write these values into this Mac's settings.
        case apply([String: SettingValue])
    }

    /// - Parameters:
    ///   - local: this Mac's synced settings, stamped with when one of them last changed here.
    ///   - remote: the gist's copy, if there is one.
    ///   - firstSync: this Mac has never synced its settings.
    ///   - allowed: the only keys that may be applied (anything else in the gist is ignored).
    public static func plan(local: SettingsBackup, remote: SettingsBackup?, firstSync: Bool, allowed: Set<String>) -> Action {
        guard let remote else { return .upload }
        let incoming = applicable(remote.values, over: local.values, allowed: allowed)
        if firstSync { return incoming.isEmpty ? .none : .apply(incoming) }
        if local.values == remote.values { return .none }
        if remote.updatedAt > local.updatedAt { return incoming.isEmpty ? .upload : .apply(incoming) }
        return .upload
    }

    /// The remote values that would change something here: allowed keys only, of the same kind as the local value
    /// (when there is one), and different from it.
    public static func applicable(_ remote: [String: SettingValue], over local: [String: SettingValue],
                                  allowed: Set<String>) -> [String: SettingValue] {
        remote.filter { key, value in
            guard allowed.contains(key) else { return false }
            guard let current = local[key] else { return true }
            return current.isSameKind(as: value) && current != value
        }
    }
}
