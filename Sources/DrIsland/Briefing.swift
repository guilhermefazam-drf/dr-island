import Foundation
import DrIslandCore

/// The state of the day briefing, kept in the defaults so the island, the settings and the controller agree.
/// What it shows comes from `DayBriefing` over the alert history.
enum Briefing {
    private static var defaults: UserDefaults { .standard }

    static var isActive: Bool { defaults.bool(forKey: SettingsKey.briefingActive) }
    static var since: Date { Date(timeIntervalSince1970: defaults.double(forKey: SettingsKey.briefingSince)) }
    private static var lastSeen: Date? { date(SettingsKey.briefingLastSeen) }
    private static var lastShown: Date? { date(SettingsKey.briefingLastShown) }

    private static func date(_ key: String) -> Date? {
        let t = defaults.double(forKey: key)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// Where a briefing starts counting: the last time the island was looked at, or a day back when never.
    private static func start(now: Date) -> Date { lastSeen ?? now.addingTimeInterval(-86_400) }

    static func pendingCount(now: Date = Date()) -> Int {
        DayBriefing.entries(AlertLog.decode(defaults.string(forKey: SettingsKey.alertHistory)), since: start(now: now)).count
    }

    /// Shows the briefing block (by the button, or by itself in the morning).
    static func activate(now: Date = Date()) {
        defaults.set(start(now: now).timeIntervalSince1970, forKey: SettingsKey.briefingSince)
        defaults.set(true, forKey: SettingsKey.briefingActive)
    }

    /// Hides it and counts the island as seen from now on.
    static func dismiss(now: Date = Date()) {
        defaults.set(false, forKey: SettingsKey.briefingActive)
        defaults.set(now.timeIntervalSince1970, forKey: SettingsKey.briefingLastSeen)
    }

    /// The island closed after being open: what was in it has been seen. Held back while a briefing is waiting to be read.
    static func markSeen(now: Date = Date()) {
        guard !isActive else { return }
        defaults.set(now.timeIntervalSince1970, forKey: SettingsKey.briefingLastSeen)
    }

    /// True once a day, in the morning, when there is something new and the briefing is allowed to open by itself.
    static func shouldOpenByItself(now: Date = Date()) -> Bool {
        guard defaults.bool(forKey: SettingsKey.briefingAuto), !isActive else { return false }
        return DayBriefing.shouldAutoShow(lastShown: lastShown, pending: pendingCount(now: now), now: now)
    }

    /// "3 PRs · 2 Jira" for what the briefing would list, for the mini island.
    static func summaryText(now: Date = Date()) -> String {
        DayBriefing.summary(DayBriefing.entries(AlertLog.decode(defaults.string(forKey: SettingsKey.alertHistory)), since: start(now: now)))
    }

    static func openedByItself(now: Date = Date()) {
        defaults.set(now.timeIntervalSince1970, forKey: SettingsKey.briefingLastShown)
        activate(now: now)
    }
}
