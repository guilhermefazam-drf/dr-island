import Foundation
import DrIslandCore

/// Which preferences travel to the gist, and how they are read from and written to UserDefaults.
/// Left out: secrets (the Jira token is only in the Keychain), what belongs to this Mac (the `gh` path, screens,
/// notch fine-tuning), the sync's own bookkeeping, and data or running state (history, usage, a running timer).
enum SyncedSettings {
    static let excluded: Set<String> = [
        SettingsKey.githubGhPath, SettingsKey.disabledScreens, SettingsKey.targetScreen, SettingsKey.showOnAllScreens,
        SettingsKey.notchWidthAdjust, SettingsKey.notchHeightAdjust, SettingsKey.usageCalibrationLimit,
        SettingsKey.alertHistory, SettingsKey.historySyncMode, SettingsKey.historyClearedAt,
        SettingsKey.historyGistID, SettingsKey.historyGistLogin,
        SettingsKey.settingsSyncEnabled, SettingsKey.settingsChangedAt, SettingsKey.settingsSyncedOnce,
        SettingsKey.quietMuted, SettingsKey.briefingActive, SettingsKey.briefingSince,
        SettingsKey.briefingLastShown, SettingsKey.briefingLastSeen, SettingsKey.focusState, SettingsKey.usageHistory,
    ]

    /// Every preference that is backed up: all the keys with a default in `Settings.registerDefaults()` (every
    /// preference has one), minus the excluded ones, so a new preference is backed up by default.
    /// Read after `registerDefaults()` (the app delegate registers them before anything else runs).
    static let keys: Set<String> = Set(UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain).keys)
        .subtracting(excluded)

    /// The current values of the backed-up preferences (unset ones without a default are left out).
    static func values(_ defaults: UserDefaults = .standard) -> [String: SettingValue] {
        var out: [String: SettingValue] = [:]
        for key in keys {
            if let value = defaults.object(forKey: key).flatMap(settingValue) { out[key] = value }
        }
        return out
    }

    static func backup(_ defaults: UserDefaults = .standard) -> SettingsBackup {
        let changed = defaults.double(forKey: SettingsKey.settingsChangedAt)
        return SettingsBackup(updatedAt: Date(timeIntervalSince1970: changed), device: Host.current().localizedName ?? "Mac",
                              values: values(defaults))
    }

    static func apply(_ values: [String: SettingValue], _ defaults: UserDefaults = .standard) {
        for (key, value) in values where keys.contains(key) {
            switch value {
            case .bool(let v): defaults.set(v, forKey: key)
            case .int(let v): defaults.set(v, forKey: key)
            case .double(let v): defaults.set(v, forKey: key)
            case .string(let v): defaults.set(v, forKey: key)
            }
        }
    }

    private static func settingValue(_ object: Any) -> SettingValue? {
        switch object {
        case let string as String: return .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            switch String(cString: number.objCType) {
            case "d", "f": return .double(number.doubleValue)
            default: return .int(number.intValue)
            }
        default: return nil   // arrays, data and dictionaries are not used by the synced preferences
        }
    }
}
