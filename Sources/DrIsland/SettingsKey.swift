import Foundation
import DrIslandCore

/// Non-secret preferences live in UserDefaults. Secrets (e.g. a future Jira API token) go in the Keychain only.
enum SettingsKey {
    static let showBorder = "showBorder"
    static let expandOnHover = "expandOnHover"
    static let showOnAllScreens = "showOnAllScreens"
    static let disabledScreens = "disabledScreens"
    static let targetScreen = "targetScreen"          // "notch" | "main"
    static let claudeRefreshSeconds = "claudeRefreshSeconds"
    static let amberThreshold = "amberThreshold"
    static let redThreshold = "redThreshold"
    static let showWeekly = "showWeekly"
    static let borderThickness = "borderThickness"
    static let notchWidthAdjust = "notchWidthAdjust"    // pt, fine-tuning on top of the detected size
    static let notchHeightAdjust = "notchHeightAdjust"
    static let githubEnabled = "githubEnabled"
    static let githubGhPath = "githubGhPath"
    static let githubIncludeReviewRequests = "githubIncludeReviewRequests"
    static let githubScope = "githubScope"
    static let githubRefreshSeconds = "githubRefreshSeconds"
    static let claudeLocalFallback = "claudeLocalFallback"   // estimate from local logs while the API is rate-limited
    static let claudeManualLimit = "claudeManualLimit"       // tokens per 5h session; 0 = automatic
    static let usageCalibrationLimit = "usageCalibrationLimit" // internal: tokens that equalled 100% in the last real reading
    static let animSpeed = "animSpeed"                // 0.5…3, multiplies how fast the springs run
    static let animBounce = "animBounce"              // 0…1, how much the island overshoots
    static let animCollapseDelay = "animCollapseDelay" // seconds the pointer may be away before it closes
    static let animEffect = "animEffect"              // IslandEffect.rawValue
    static let claudeUpdateAnimation = "claudeUpdateAnimation"       // the border sweeps on every fresh Claude reading
    static let claudeNewSessionAnimation = "claudeNewSessionAnimation" // the border flashes when a new Claude session starts
    static let claudeNewSessionNotice = "claudeNewSessionNotice"       // the mini island says "Nova sessão" (never logged)
    static let alertPulse = "alertPulse"              // border pulses in the colour of the change
    static let alertDot = "alertDot"                  // blue dot until the island is opened
    static let alertRow = "alertRow"                  // changed rows highlighted with a tag
    static let alertConfetti = "alertConfetti"        // confetti over the mini island when a PR is approved or merged
    static let alertBanner = "alertBanner"            // island opens by itself for a few seconds
    static let alertNotification = "alertNotification" // macOS notification
    static let alertSound = "alertSound"
    static let alertComments = "alertComments"        // new comments and mentions on PRs
    static let alertMerged = "alertMerged"            // own PR merged
    static let alertJira = "alertJira"                // Jira task changes
    static let prMutes = "prMutes"                    // JSON list of PRMute
    static let alertOnClose = "alertOnClose"          // also report PRs that left the list (merged/closed)
    static let showForecast = "showForecast"          // "esgota às HH:mm" under the session bar
    static let shortcuts = "shortcuts"                // JSON list of DevShortcut
    static let quietEnabled = "quietEnabled"          // silence sound/notifications inside the quiet hours
    static let quietStart = "quietStart"              // minutes since midnight
    static let quietEnd = "quietEnd"
    static let quietFocus = "quietFocus"              // also stay silent while a macOS Focus is on
    static let quietMuted = "quietMuted"              // manual "silenciar agora"
    static let showAlertsBlock = "showAlertsBlock"    // recent alerts block in the island
    static let alertHistory = "alertHistory"          // JSON list of AlertEntry
    static let showOwner = "showOwner"                // "eu" / initials before each PR and task row
    static let showOutOfSprint = "showOutOfSprint"    // Jira card: my tasks that are not in the active sprint
    static let showSprint = "showSprint"              // "Sprint" block: active Jira sprint dates and elapsed time
    static let showTimeline = "showTimeline"          // "linha do tempo" block: what happened today
    static let briefingAuto = "briefingAuto"          // the day briefing opens by itself, once a day
    static let briefingActive = "briefingActive"      // the briefing block is showing (until dismissed)
    static let briefingSince = "briefingSince"        // timeIntervalSince1970 the showing briefing counts from
    static let briefingLastShown = "briefingLastShown" // when the briefing last opened by itself
    static let briefingLastSeen = "briefingLastSeen"  // when the island was last looked at (closed)
    static let claudeGauge = "claudeGauge"            // "bar" | "ring": how the session is drawn in the Claude block
    static let islandLayout = "islandLayout"          // JSON IslandLayoutConfig
    static let showFocus = "showFocus"                // focus timer block in the island
    static let focusMinutes = "focusMinutes"
    static let focusShortBreak = "focusShortBreak"
    static let focusLongBreak = "focusLongBreak"
    static let focusRounds = "focusRounds"
    static let focusAutoStart = "focusAutoStart"
    static let focusState = "focusState"              // JSON FocusTimer, so a running timer survives a restart
    static let costEnabled = "costEnabled"            // master switch: scan the logs and compute costs at all
    static let showCost = "showCost"                  // today's tokens and cost in the island
    static let modelPrices = "modelPrices"            // JSON PriceTable
    static let showMusic = "showMusic"                // now-playing player in the island
    static let usageHistory = "usageHistory"          // JSON list of DayUsage
    static let showHistory = "showHistory"            // the small chart in the island
    static let showIsland = "showIsland"              // false = menu bar only
    static let menuBarText = "menuBarText"            // session percentage next to the menu bar icon
    static let hotKey = "hotKey"                      // HotKeyOption.rawValue
    static let jiraEnabled = "jiraEnabled"
    static let jiraSite = "jiraSite"
    static let jiraEmail = "jiraEmail"
    static let jiraJQL = "jiraJQL"
    static let jiraApproverEnabled = "jiraApproverEnabled"
    static let jiraApproverJQL = "jiraApproverJQL"
    static let jiraMaxTasks = "jiraMaxTasks"
    static let jiraRefreshSeconds = "jiraRefreshSeconds"
    static let jiraBacklogEnabled = "jiraBacklogEnabled"  // "Backlog" block: the team backlog grouped by future sprint
    static let jiraBacklogProject = "jiraBacklogProject"  // project key; empty = the one most of my tasks belong to
    static let jiraBacklogJQL = "jiraBacklogJQL"          // empty = Backlog.defaultJQL(project:)
}
