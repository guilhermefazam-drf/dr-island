import Foundation
import DrIslandCore

enum Settings {
    /// The app was called "Token Island" until 0.2: copy its preferences once, so shortcuts, PR cache and options survive the new bundle id.
    static func migrateLegacyDefaults() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "migratedFromTokenIsland") else { return }
        if let old = d.persistentDomain(forName: "com.fazam.token-island") {
            for (key, value) in old { d.set(value, forKey: key) }
        }
        d.set(true, forKey: "migratedFromTokenIsland")
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.showBorder: true,
            SettingsKey.expandOnHover: true,
            SettingsKey.showOnAllScreens: true,
            SettingsKey.targetScreen: "notch",
            SettingsKey.claudeRefreshSeconds: 120.0,
            SettingsKey.amberThreshold: 60.0,
            SettingsKey.redThreshold: 85.0,
            SettingsKey.showWeekly: true,
            SettingsKey.borderThickness: 3.0,
            SettingsKey.notchWidthAdjust: 0.0,
            SettingsKey.notchHeightAdjust: 0.0,
            SettingsKey.githubEnabled: true,
            SettingsKey.githubGhPath: "",
            SettingsKey.githubIncludeReviewRequests: true,
            SettingsKey.githubScope: "",
            SettingsKey.githubRefreshSeconds: 120.0,
            SettingsKey.claudeLocalFallback: true,
            SettingsKey.claudeManualLimit: 0.0,
            SettingsKey.animSpeed: Settings.defaultAnimSpeed,
            SettingsKey.animBounce: Settings.defaultAnimBounce,
            SettingsKey.animCollapseDelay: Settings.defaultCollapseDelay,
            SettingsKey.animEffect: IslandEffect.default.rawValue,
            SettingsKey.alertPulse: true,
            SettingsKey.claudeNewSessionNotice: true,
            SettingsKey.claudeUpdateAnimation: true,
            SettingsKey.claudeNewSessionAnimation: true,
            SettingsKey.alertDot: true,
            SettingsKey.alertRow: true,
            SettingsKey.alertBanner: false,
            SettingsKey.alertConfetti: true,
            SettingsKey.alertNotification: false,
            SettingsKey.alertSound: false,
            SettingsKey.alertOnClose: false,
            SettingsKey.alertComments: true,
            SettingsKey.alertMerged: true,
            SettingsKey.alertJira: true,
            SettingsKey.prMutes: "[]",
            SettingsKey.showForecast: true,
            SettingsKey.shortcuts: "[]",
            SettingsKey.quietEnabled: false,
            SettingsKey.quietStart: 22 * 60,
            SettingsKey.quietEnd: 8 * 60,
            SettingsKey.quietFocus: true,
            SettingsKey.quietMuted: false,
            SettingsKey.showAlertsBlock: true,
            SettingsKey.alertHistory: "[]",
            SettingsKey.showSprint: true,
            SettingsKey.showOutOfSprint: true,
            SettingsKey.showTimeline: true,
            SettingsKey.showOwner: true,
            SettingsKey.briefingAuto: true,
            SettingsKey.briefingActive: false,
            SettingsKey.briefingSince: 0.0,
            SettingsKey.briefingLastShown: 0.0,
            SettingsKey.briefingLastSeen: 0.0,
            SettingsKey.claudeGauge: "bar",
            SettingsKey.islandLayout: IslandLayoutConfig.vertical.encoded(),
            SettingsKey.showFocus: false,
            SettingsKey.focusMinutes: 25,
            SettingsKey.focusShortBreak: 5,
            SettingsKey.focusLongBreak: 15,
            SettingsKey.focusRounds: 4,
            SettingsKey.focusAutoStart: false,
            SettingsKey.costEnabled: true,
            SettingsKey.showCost: false,
            SettingsKey.modelPrices: PriceTable.standard.encoded(),
            SettingsKey.showMusic: true,
            SettingsKey.usageHistory: "[]",
            SettingsKey.showHistory: false,
            SettingsKey.showIsland: true,
            SettingsKey.menuBarText: false,
            SettingsKey.hotKey: HotKeyOption.default.rawValue,
            SettingsKey.jiraEnabled: false,
            SettingsKey.jiraSite: "",
            SettingsKey.jiraEmail: "",
            SettingsKey.jiraJQL: JiraConfig.defaultJQL,
            SettingsKey.jiraApproverEnabled: true,
            SettingsKey.jiraApproverJQL: JiraConfig.defaultApproverJQL,
            SettingsKey.jiraMaxTasks: 20,
            SettingsKey.jiraRefreshSeconds: 180.0,
        ])
    }

    static var claudeRefreshSeconds: TimeInterval {
        min(max(UserDefaults.standard.double(forKey: SettingsKey.claudeRefreshSeconds), 60), 600)
    }
    static var githubRefreshSeconds: TimeInterval {
        min(max(UserDefaults.standard.double(forKey: SettingsKey.githubRefreshSeconds), 60), 600)
    }
    static var githubEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.githubEnabled) }
    static var githubOptions: GitHubClient.Options {
        let d = UserDefaults.standard
        return .init(ghPath: d.string(forKey: SettingsKey.githubGhPath),
                     includeReviewRequests: d.bool(forKey: SettingsKey.githubIncludeReviewRequests),
                     scope: d.string(forKey: SettingsKey.githubScope) ?? "",
                     includeMentions: d.bool(forKey: SettingsKey.alertComments))
    }
    static var claudeLocalFallback: Bool { UserDefaults.standard.bool(forKey: SettingsKey.claudeLocalFallback) }
    static var claudeManualLimit: Double? {
        let value = UserDefaults.standard.double(forKey: SettingsKey.claudeManualLimit)
        return value > 0 ? value : nil
    }
    static var usageCalibrationLimit: Double? {
        get { let v = UserDefaults.standard.double(forKey: SettingsKey.usageCalibrationLimit); return v > 0 ? v : nil }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: SettingsKey.usageCalibrationLimit) }
    }
    static let defaultAnimSpeed = 1.6
    static let defaultAnimBounce = 0.55
    static let defaultCollapseDelay = 0.2
    static var collapseDelay: TimeInterval {
        min(max(UserDefaults.standard.double(forKey: SettingsKey.animCollapseDelay), 0), 1)
    }
    static let jiraTokenAccount = "jira-api-token"
    static var jiraEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.jiraEnabled) }
    static var showSprint: Bool { UserDefaults.standard.bool(forKey: SettingsKey.showSprint) }
    static var jiraApproverEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.jiraApproverEnabled) }
    static var jiraRefreshSeconds: TimeInterval {
        min(max(UserDefaults.standard.double(forKey: SettingsKey.jiraRefreshSeconds), 60), 900)
    }
    /// `token` is passed in so callers decide when to touch the Keychain.
    static func jiraConfig(token: String) -> JiraConfig {
        let d = UserDefaults.standard
        let jql = (d.string(forKey: SettingsKey.jiraJQL) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let approverJQL = (d.string(forKey: SettingsKey.jiraApproverJQL) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return JiraConfig(site: d.string(forKey: SettingsKey.jiraSite) ?? "",
                          email: (d.string(forKey: SettingsKey.jiraEmail) ?? "").trimmingCharacters(in: .whitespaces),
                          token: token,
                          jql: jql.isEmpty ? JiraConfig.defaultJQL : jql,
                          approverJQL: (approverJQL.isEmpty || approverJQL == JiraConfig.legacyApproverJQL) ? JiraConfig.defaultApproverJQL : approverJQL,
                          maxResults: d.integer(forKey: SettingsKey.jiraMaxTasks))
    }
    /// True while sound and macOS notifications must stay off (manual mute, quiet hours or a Focus).
    static var isQuiet: Bool {
        let d = UserDefaults.standard
        if d.bool(forKey: SettingsKey.quietMuted) { return true }
        if d.bool(forKey: SettingsKey.quietEnabled),
           QuietHours.isQuiet(now: Date(), startMinute: d.integer(forKey: SettingsKey.quietStart), endMinute: d.integer(forKey: SettingsKey.quietEnd)) { return true }
        if d.bool(forKey: SettingsKey.quietFocus) {
            let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
            if let data = try? Data(contentsOf: url), QuietHours.focusIsActive(assertionsJSON: data) { return true }
        }
        return false
    }
    static var alertBanner: Bool { UserDefaults.standard.bool(forKey: SettingsKey.alertBanner) }
    static var alertNotification: Bool { UserDefaults.standard.bool(forKey: SettingsKey.alertNotification) }
    static var alertSound: Bool { UserDefaults.standard.bool(forKey: SettingsKey.alertSound) }
    static var alertOnClose: Bool { UserDefaults.standard.bool(forKey: SettingsKey.alertOnClose) }
    static var prMutes: [PRMute] { PRMutes.decode(UserDefaults.standard.string(forKey: SettingsKey.prMutes) ?? "[]") }

    /// Which kinds of change the user wants to hear about at all.
    static func allows(_ kind: PRChange.Kind) -> Bool {
        let d = UserDefaults.standard
        switch kind {
        case .left: return alertOnClose
        case .merged: return d.bool(forKey: SettingsKey.alertMerged)
        case .newComment, .mentioned: return d.bool(forKey: SettingsKey.alertComments)
        case .jiraNew, .jiraStatus, .jiraComment, .jiraApprovers: return d.bool(forKey: SettingsKey.alertJira)
        default: return true
        }
    }
    static var expandOnHover: Bool { UserDefaults.standard.bool(forKey: SettingsKey.expandOnHover) }
    static var priceTable: PriceTable { PriceTable.decode(UserDefaults.standard.string(forKey: SettingsKey.modelPrices)) }
    static var focusConfig: FocusTimer.Config {
        let d = UserDefaults.standard
        return FocusTimer.Config(focusMinutes: d.integer(forKey: SettingsKey.focusMinutes), shortBreakMinutes: d.integer(forKey: SettingsKey.focusShortBreak),
                                 longBreakMinutes: d.integer(forKey: SettingsKey.focusLongBreak), roundsBeforeLongBreak: d.integer(forKey: SettingsKey.focusRounds),
                                 autoStart: d.bool(forKey: SettingsKey.focusAutoStart))
    }
    static var costEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.costEnabled) }
    static var showMusic: Bool { UserDefaults.standard.bool(forKey: SettingsKey.showMusic) }
    static var showIsland: Bool { UserDefaults.standard.bool(forKey: SettingsKey.showIsland) }
    /// Stable ids (display UUIDs) of the screens the user switched the island off on.
    static var disabledScreens: Set<String> {
        Set((UserDefaults.standard.string(forKey: SettingsKey.disabledScreens) ?? "").split(separator: ",").map(String.init))
    }
    static var showOnAllScreens: Bool { UserDefaults.standard.bool(forKey: SettingsKey.showOnAllScreens) }
    static var targetScreenIsMain: Bool { UserDefaults.standard.string(forKey: SettingsKey.targetScreen) == "main" }
}

extension Notification.Name {
    /// Posted by the settings window to play the current show/hide effect on the real island.
    static let islandPreviewEffect = Notification.Name("islandPreviewEffect")
    /// Posted by `PullRequestStore` when a reading brought new changes (object: nothing; read `lastChanges`).
    static let prChangesDetected = Notification.Name("prChangesDetected")
    /// Posted by the settings window to fire a sample alert with the current options.
    static let prAlertTest = Notification.Name("prAlertTest")
    static let prConfettiTest = Notification.Name("prConfettiTest")
    static let newSessionTest = Notification.Name("newSessionTest")
    /// Asks the open settings window to go to a page (object: the page's raw value).
    static let showSettingsPage = Notification.Name("showSettingsPage")
    /// Posted after the Jira API token is saved or removed so the store re-reads the Keychain.
    static let jiraTokenChanged = Notification.Name("jiraTokenChanged")
}
