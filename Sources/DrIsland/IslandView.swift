import SwiftUI
import DrIslandCore

@MainActor
final class IslandState: ObservableObject {
    @Published var expanded = false
    /// Height of the visible expanded island (the panel itself is always max height); drives the hover hit area.
    @Published var visibleHeight: CGFloat = 0
    @Published var visibleWidth: CGFloat = 400
    /// "+N mais" clicked: show the full list for that section until the island closes.
    @Published var showAllPRs = false
    @Published var showAllReviews = false
    @Published var showAllJira = false
    @Published var showAllApprovals = false
    /// The settings preview is driving the island, so closing it must not count as "the user saw the alerts".
    var isPreview = false
    /// What the mini island shows while it is up; empty = hidden.
    @Published var peek: [PRChange] = []
    /// An app is in full screen on this island's display: the border and the notification dots stay hidden (the mini island still shows).
    @Published var fullscreen = false
}

extension PRChange.Tone {
    var color: Color {
        switch self {
        case .critical: return Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)
        case .warning: return Color(red: 0xFE / 255, green: 0xBC / 255, blue: 0x2E / 255)
        case .info: return Color(red: 0.36, green: 0.62, blue: 1.0)
        case .success: return Color(red: 0x28 / 255, green: 0xC8 / 255, blue: 0x40 / 255)
        case .neutral: return .gray
        }
    }
}

enum IslandLayout {
    /// Spare room around the island so the springs can overshoot without being clipped by the panel.
    static let overshootX: CGFloat = 24
    static let overshootY: CGFloat = 28
    static let maxPullRequestRows = 4
    static let maxJiraRows = 4
    static let maxPeekRows = 4
    static let peekWidth: CGFloat = 320
    static let peekRowHeight: CGFloat = 22
    /// Rows shown per section after "+N mais" (anything beyond is summarised).
    static let expandedRowLimit = 8
    static let prRowHeight: CGFloat = 25
    static let prHeaderHeight: CGFloat = 26

    static let sectionSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 10
    // Content heights of the blocks; a block drawn on a card adds `cardPadding` on each side.
    static let claudeHeight: CGFloat = 100
    static let claudeRingHeight: CGFloat = 108   // header + a 84 pt ring; the forecast fits beside it
    static let forecastExtra: CGFloat = 27        // the "esgota às" chip and its spacing
    static let costTileHeight: CGFloat = 38
    static let costExtra: CGFloat = 8 + costTileHeight
    static let focusContent: CGFloat = 56
    static let musicContent: CGFloat = 70
    static let musicContentWithProgress: CGFloat = 84
    static let historyContent: CGFloat = 42
    static let shortcutsContent: CGFloat = 34
    static let alertsHeader: CGFloat = 16
    static let alertsRow: CGFloat = 22
    static func card(_ content: CGFloat) -> CGFloat { content + 2 * cardPadding }

    static func baseHeight(_ metrics: NotchMetrics) -> CGFloat { metrics.height + 116 }
    static func panelSize(_ metrics: NotchMetrics) -> CGSize {
        CGSize(width: CGFloat(IslandLayoutConfig.maxWidth) + 2 * overshootX, height: maxHeight(metrics) + overshootY)
    }

    /// The tallest island possible: every block in a single column, the lists fully expanded.
    static func maxHeight(_ metrics: NotchMetrics) -> CGFloat {
        let blocks = max(claudeHeight + forecastExtra, claudeRingHeight) + costExtra + card(focusContent) + card(musicContentWithProgress) + card(historyContent) + card(shortcutsContent)
            + card(16 + 6 + 4 * alertsRow) + card(BriefingBlock.contentHeight(rows: BriefingBlock.maxRows)) + card(TimelineBlock.contentHeight)
        let lists = 4 * (prHeaderHeight + CGFloat(expandedRowLimit + 2) * prRowHeight)
        return metrics.height + 6 + 10 + blocks + lists + 12 * sectionSpacing
    }
}

private enum JiraRow {
    case task(JiraTask)
    case message(String)
    case more(Int)       // collapsed: expands the section
    case less            // expanded: collapses it again
    case overflow(Int)   // expanded but still more than fits; not clickable
}

private enum PRList { case authored, review }

private enum PRRow {
    case pr(PullRequest)
    case message(String)
    case more(Int)       // collapsed: expands the section
    case less            // expanded: collapses it again
    case overflow(Int)   // expanded but still more than fits; not clickable
}

/// Open "U" hugging the outside of the notch, from the top-left edge, round the bottom, to the top-right edge.
struct NotchRing: Shape {
    var cornerRadius: CGFloat
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let x0 = rect.minX + inset
        let x1 = rect.maxX - inset
        let yb = rect.maxY - inset
        let r = max(0, min(cornerRadius, (x1 - x0) / 2, yb - rect.minY))
        var p = Path()
        p.move(to: CGPoint(x: x0, y: rect.minY))
        p.addLine(to: CGPoint(x: x0, y: yb - r))
        p.addRelativeArc(center: CGPoint(x: x0 + r, y: yb - r), radius: r, startAngle: .degrees(180), delta: .degrees(-90))
        p.addLine(to: CGPoint(x: x1 - r, y: yb))
        p.addRelativeArc(center: CGPoint(x: x1 - r, y: yb - r), radius: r, startAngle: .degrees(90), delta: .degrees(-90))
        p.addLine(to: CGPoint(x: x1, y: rect.minY))
        return p
    }
}

/// A short bright segment that travels along the ring; `sweep` runs 0 → 1.22 so the tail also leaves the end.
struct RingSweep: Shape {
    var base: NotchRing
    var sweep: CGFloat
    var length: CGFloat = 0.22

    var animatableData: CGFloat {
        get { sweep }
        set { sweep = newValue }
    }

    func path(in rect: CGRect) -> Path {
        base.path(in: rect).trimmedPath(from: min(max(sweep - length, 0), 1), to: min(max(sweep, 0), 1))
    }
}

/// Small spinning sync arrows shown beside the notch while a refresh runs.
struct SyncIcon: View {
    @State private var angle: Double = 0

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
            .rotationEffect(.degrees(angle))
            .onAppear { withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { angle = 360 } }
    }
}

struct IslandView: View {
    let metrics: NotchMetrics
    let expandedSize: CGSize
    @ObservedObject var state: IslandState
    @ObservedObject var store: UsageStore
    @ObservedObject var prStore: PullRequestStore
    @ObservedObject var jiraStore: JiraStore
    @ObservedObject var musicStore: MusicStore
    @ObservedObject var costStore: CostStore
    @ObservedObject var focusStore: FocusStore
    var openSettings: () -> Void
    /// Height of the screen this island is on: the columns never grow past half of it, they scroll instead.
    var screenHeight: CGFloat = 900

    @State private var showContent = false
    /// Update animation on the ring: a highlight sweeping along it plus a glow pulse.
    @State private var sweep: CGFloat = 0
    @State private var sweepOpacity: Double = 0
    @State private var glow: Double = 0
    /// New Claude session: a comet laps the border (`newSessionLap` 0 → 1.3, the tail leaves last), the border lights up
    /// once it closes, and two sparkles pop beside the notch.
    @State private var newSessionLap: CGFloat = 0
    @State private var newSessionFlash: Double = 0
    @State private var newSessionSparkle: Double = 0
    /// The comet and the flash follow the mini island's outline when it announces the session.
    @State private var newSessionOnMini = false
    @AppStorage(SettingsKey.claudeNewSessionNotice) private var newSessionNotice = true
    /// Stays true for a minimum time after a refresh starts, because the request itself is often too quick to notice.
    @State private var syncing = false
    /// Change alert on the ring: pulses in the colour of the loudest change.
    @State private var peekProgress: CGFloat = 0
    @State private var peekContent: Double = 0
    @State private var peekItems: [PRChange] = []   // kept while the mini island folds back, so it does not go blank
    @State private var confettiTick = 0
    @AppStorage(SettingsKey.alertConfetti) private var alertConfetti = true
    @AppStorage(SettingsKey.showOwner) private var showOwner = true
    /// The pulse follows the mini island when that alert is on, otherwise the notch ring.
    @State private var alertOnMini = false
    @State private var dockX: CGFloat?
    @AppStorage(SettingsKey.showCost) private var showCostLine = false
    @AppStorage(SettingsKey.costEnabled) private var costEnabled = true
    private var showCost: Bool { showCostLine && costEnabled }
    @AppStorage(SettingsKey.showFocus) private var showFocus = false
    @AppStorage(SettingsKey.claudeGauge) private var claudeGauge = "bar"
    @AppStorage(SettingsKey.alertHistory) private var historyJSON = "[]"
    @AppStorage(SettingsKey.showAlertsBlock) private var showAlertsBlock = true
    @AppStorage(SettingsKey.showTimeline) private var showTimeline = true
    @AppStorage(SettingsKey.briefingActive) private var briefingActive = false
    @AppStorage(SettingsKey.briefingSince) private var briefingSince = 0.0
    private var gaugeIsRing: Bool { claudeGauge == "ring" }
    @AppStorage(SettingsKey.islandLayout) private var layoutJSON = IslandLayoutConfig.vertical.encoded()
    @AppStorage(SettingsKey.showHistory) private var showHistory = false
    @AppStorage(SettingsKey.prMutes) private var mutesJSON = "[]"
    @AppStorage(SettingsKey.shortcuts) private var shortcutsJSON = "[]"
    @AppStorage(SettingsKey.showForecast) private var showForecast = true
    @AppStorage(SettingsKey.alertBanner) private var alertBanner = false
    @State private var alertOpacity: Double = 0
    @State private var alertColor: Color = PRChange.Tone.info.color
    /// Silhouette progress (0 = notch, 1 = expanded); width and height are staged separately per effect.
    @State private var widthProgress: CGFloat = 0
    @State private var heightProgress: CGFloat = 0

    @AppStorage(SettingsKey.animSpeed) private var animSpeed = Settings.defaultAnimSpeed
    @AppStorage(SettingsKey.animBounce) private var animBounce = Settings.defaultAnimBounce
    @AppStorage(SettingsKey.animEffect) private var effectName = IslandEffect.default.rawValue
    @AppStorage(SettingsKey.alertPulse) private var alertPulse = true
    @AppStorage(SettingsKey.claudeUpdateAnimation) private var updateAnimation = true
    @AppStorage(SettingsKey.claudeNewSessionAnimation) private var newSessionAnimation = true
    @AppStorage(SettingsKey.alertDot) private var alertDot = true
    @AppStorage(SettingsKey.alertRow) private var alertRow = true
    @AppStorage(SettingsKey.githubIncludeReviewRequests) private var includeReviews = true
    @AppStorage(SettingsKey.showBorder) private var showBorder = true
    @AppStorage(SettingsKey.borderThickness) private var thickness = 3.0
    @AppStorage(SettingsKey.amberThreshold) private var amber = 60.0
    @AppStorage(SettingsKey.redThreshold) private var red = 85.0
    @AppStorage(SettingsKey.showWeekly) private var showWeekly = true

    @ObservedObject private var network = NetworkMonitor.shared
    /// No network path, or the usage endpoint can't be reached: every number shown is stale.
    private var isOffline: Bool { !network.isOnline || store.status == .offline }

    private let notchCornerRadius: CGFloat = 10

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            island
            ring
            miniIsland
            ConfettiBurst(tick: confettiTick)
                .offset(y: metrics.height + 8)
                .allowsHitTesting(false)
            alertRing
            attentionDot
            newsDot
            newSessionSparkles
            syncIndicator
        }
        .frame(width: expandedSize.width, height: expandedSize.height, alignment: .top)
        .animation(.easeOut(duration: 0.2), value: state.expanded)
        .animation(.easeInOut(duration: 0.2), value: syncing)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: prStore.unseen.isEmpty)
        .onChange(of: anyRefreshing) { _, refreshing in
            guard refreshing else { return }
            syncing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { syncing = false }
        }
        .onChange(of: state.peek) { _, items in
            if items.isEmpty {
                newSessionOnMini = false
                withAnimation(.easeIn(duration: 0.12 / speed)) { peekContent = 0 }
                withAnimation(.spring(response: 0.34 / speed, dampingFraction: 0.9)) { peekProgress = 0 }
            } else {
                peekItems = items
                // A PR approved (or merged) gets a little party over the mini island.
                if alertConfetti, items.contains(where: { $0.kind == .approved || $0.kind == .merged }) { confettiTick += 1 }
                withAnimation(.spring(response: 0.42 / speed, dampingFraction: min(openDamping + 0.05, 0.9))) { peekProgress = 1 }
                withAnimation(.easeOut(duration: 0.25).delay(0.1 / speed)) { peekContent = 1 }
            }
        }
        .onChange(of: prStore.alertTick) { _, _ in playAlertPulse() }
        .onChange(of: store.updateTick) { _, _ in if updateAnimation { playUpdateAnimation() } }
        .onChange(of: store.newSessionTick) { _, _ in
            newSessionOnMini = alertBanner && newSessionNotice
            if newSessionAnimation { playNewSessionAnimation() }
        }
        .onChange(of: contentHeight, initial: true) { _, height in state.visibleHeight = height }
        .onChange(of: layoutWidth, initial: true) { _, width in state.visibleWidth = width }
        .onChange(of: state.expanded) { _, expanded in
            let motion = motion(opening: expanded)
            withAnimation(motion.width) { widthProgress = expanded ? 1 : 0 }
            withAnimation(motion.height) { heightProgress = expanded ? 1 : 0 }
            if expanded {
                // The content "arrives" slightly after the bubble starts growing, then settles with a spring.
                DispatchQueue.main.asyncAfter(deadline: .now() + motion.contentDelay) {
                    guard state.expanded else { return }
                    withAnimation(.spring(response: 0.46 / speed, dampingFraction: min(openDamping + 0.1, 0.95))) { showContent = true }
                }
            } else {
                withAnimation(.easeIn(duration: 0.12 / speed)) { showContent = false }
                // Closing after being opened means the user has seen what changed.
                if !state.isPreview { prStore.markSeen() }
            }
        }
    }

    // MARK: Pull requests

    private func prRows(for list: PRList) -> [PRRow] {
        if list == .review && !includeReviews { return [] }
        let items = list == .authored ? prStore.snapshot.authored : prStore.snapshot.reviewRequested
        if !items.isEmpty {
            let expanded = list == .authored ? state.showAllPRs : state.showAllReviews
            let limit = expanded ? IslandLayout.expandedRowLimit : IslandLayout.maxPullRequestRows
            var rows = items.prefix(limit).map(PRRow.pr)
            if items.count > limit { rows.append(expanded ? .overflow(items.count - limit) : .more(items.count - limit)) }
            if expanded && items.count > IslandLayout.maxPullRequestRows { rows.append(.less) }
            return rows
        }
        // Setup problems are reported once, in the first block.
        switch prStore.status {
        case .disabled: return []
        case .loading: return list == .authored ? [.message("A carregar…")] : []
        case .ok: return [.message(list == .authored ? "Sem PRs abertos" : "Sem reviews pendentes")]
        case .notInstalled: return list == .authored ? [.message("gh não encontrado — brew install gh")] : []
        case .notAuthenticated: return list == .authored ? [.message("Corre «gh auth login» no terminal")] : []
        case .error(let message): return list == .authored ? [.message(message)] : []
        }
    }

    private func setShowAll(_ list: PRList, _ value: Bool) {
        if list == .authored { state.showAllPRs = value } else { state.showAllReviews = value }
    }

    private var approvalRows: [JiraRow] {
        guard Settings.jiraApproverEnabled else { return [] }
        let tasks = jiraStore.approvals
        if !tasks.isEmpty { return jiraTaskRows(tasks, expanded: state.showAllApprovals) }
        switch jiraStore.status {
        case .ok: return [.message(jiraStore.approvalsFailed ? "Jira: JQL das aprovações inválido" : "Sem aprovações pendentes")]
        default: return jiraRows(for: [], expanded: false)
        }
    }

    private func jiraTaskRows(_ tasks: [JiraTask], expanded: Bool) -> [JiraRow] {
        let limit = expanded ? IslandLayout.expandedRowLimit : IslandLayout.maxJiraRows
        var rows = tasks.prefix(limit).map(JiraRow.task)
        if tasks.count > limit { rows.append(expanded ? .overflow(tasks.count - limit) : .more(tasks.count - limit)) }
        if expanded && tasks.count > IslandLayout.maxJiraRows { rows.append(.less) }
        return rows
    }

    private var jiraRows: [JiraRow] { jiraRows(for: jiraStore.tasks, expanded: state.showAllJira) }

    private func jiraRows(for tasks: [JiraTask], expanded: Bool) -> [JiraRow] {
        if !tasks.isEmpty { return jiraTaskRows(JiraOrder.sorted(tasks), expanded: expanded) }
        switch jiraStore.status {
        case .disabled: return []
        case .loading: return [.message("A carregar…")]
        case .ok: return [.message("Sem tasks por fazer")]
        case .notConfigured: return [.message("Configura o Jira nas Definições")]
        case .unauthorized: return [.message("Credenciais do Jira inválidas")]
        case .invalidSite: return [.message("URL do Jira inválido (usa https)")]
        case .offline: return [.message("Sem ligação ao Jira")]
        case .rateLimited: return [.message("Jira: limite de pedidos — a aguardar")]
        case .error(let code): return [.message("Jira: erro HTTP \(code)")]
        }
    }

    private func sectionHeight(rows: Int) -> CGFloat {
        rows == 0 ? 0 : IslandLayout.sectionSpacing + IslandLayout.prHeaderHeight + CGFloat(rows) * IslandLayout.prRowHeight
    }

    /// Peak session usage for the last 14 days: the first seven (dimmer) are the previous week, for comparison.
    @ViewBuilder private var historyChart: some View {
        if showHistory {
            let days = UsageHistory.lastDays(14, from: store.history)
            VStack(spacing: 2) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, entry in
                        let peak = entry.usage?.sessionPeak
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Capsule()
                                .fill(peak.map { color(forFraction: $0) } ?? Color.white.opacity(0.12))
                                .opacity(index < 7 ? 0.5 : 1)
                                .frame(height: max(3, 28 * (peak ?? 0)))
                                .frame(maxWidth: 16)
                        }
                        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                        .help("\(entry.date.formatted(.dateTime.weekday(.wide).day().month())): \(peak.map { "\(Int(($0 * 100).rounded()))%" } ?? "sem dados")")
                    }
                }
                HStack(spacing: 3) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, entry in
                        Text(entry.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 8)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: IslandLayout.historyContent, alignment: .bottom)
            .blockCard()
        }
    }

    /// Pinned apps that still exist on disk (an uninstalled app just disappears from the row).
    private var shortcuts: [DevShortcut] {
        ShortcutList.decode(shortcutsJSON).filter { FileManager.default.fileExists(atPath: $0.appPath) }
    }

    private static let dockIcon: CGFloat = 26
    private static let dockSpacing: CGFloat = 14

    /// 1 at rest, up to 1.7 right under the pointer, falling off smoothly over about two icons.
    private func dockScale(at index: Int) -> CGFloat {
        guard let x = dockX else { return 1 }
        let center = Self.dockIcon / 2 + CGFloat(index) * (Self.dockIcon + Self.dockSpacing)
        let distance = abs(x - center)
        return 1 + 0.7 * exp(-pow(distance / 36, 2))
    }

    @ViewBuilder private var shortcutsRow: some View {
        if !shortcuts.isEmpty {
            HStack(spacing: Self.dockSpacing) {
                ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    Button { ShortcutLauncher.open(shortcut) } label: {
                        Image(nsImage: AppIcons.icon(forFile: shortcut.appPath))
                            .resizable().interpolation(.high).frame(width: Self.dockIcon, height: Self.dockIcon)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    // Like the Dock: the icon under the pointer grows and its neighbours follow, anchored to the bottom.
                    .scaleEffect(dockScale(at: index), anchor: .bottom)
                    .offset(y: -(dockScale(at: index) - 1) * 4)
                    .help(shortcut.folder.map { "\(shortcut.name) · \(($0 as NSString).lastPathComponent)" } ?? shortcut.name)
                }
            }
            .coordinateSpace(name: "dock")
            .onContinuousHover(coordinateSpace: .named("dock")) { phase in
                switch phase {
                case .active(let point): withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { dockX = point.x }
                case .ended: withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dockX = nil }
                }
            }
            .frame(height: IslandLayout.shortcutsContent, alignment: .bottom)
            .blockCard()
            .fixedSize()
            .frame(maxWidth: .infinity)   // centred under the columns
        }
    }

    // MARK: Layout (columns of blocks)

    private var layout: IslandLayoutConfig { IslandLayoutConfig.decode(layoutJSON) }
    private var layoutWidth: CGFloat { CGFloat(layout.width) }
    private static let columnGap: CGFloat = 14          // either side of the divider between columns
    private static let sidePadding: CGFloat = 24

    private var columnWidth: CGFloat {
        let n = CGFloat(layout.columnCount)
        return (layoutWidth - 2 * Self.sidePadding - (n - 1) * (2 * Self.columnGap + 1)) / n
    }

    /// The newest alerts (only the few shown are decoded from the stored history).
    private var recentAlerts: [AlertEntry] { Array(AlertLog.decode(historyJSON).prefix(AlertsBlock.maxRows)) }

    /// Today's events per hour, and what changed since the briefing's start, newest first.
    private var todayCounts: [Int] { DayBriefing.hourly(AlertLog.decode(historyJSON), day: Date()) }
    private var briefingEntries: [AlertEntry] { DayBriefing.entries(AlertLog.decode(historyJSON), since: Date(timeIntervalSince1970: briefingSince)) }

    private func openHistory() { openSettingsPage(.history) }

    private func openSettingsPage(_ page: SettingsPage) {
        UserDefaults.standard.set(page.rawValue, forKey: SettingsPage.pendingKey)
        openSettings()
        NotificationCenter.default.post(name: .showSettingsPage, object: page.rawValue)
    }

    private func isVisible(_ block: IslandBlock) -> Bool {
        switch block {
        case .claude: return true
        case .pullRequests: return !prRows(for: .authored).isEmpty || !prRows(for: .review).isEmpty
        case .jira: return !jiraRows.isEmpty
        case .jiraApprovals: return !approvalRows.isEmpty
        case .focus: return showFocus
        case .history: return showHistory
        case .music: return true   // shown disabled when nothing is playing
        case .alerts: return showAlertsBlock && !recentAlerts.isEmpty
        case .briefing: return briefingActive
        case .timeline: return showTimeline
        }
    }

    private func height(of block: IslandBlock) -> CGFloat {
        func section(_ rows: Int) -> CGFloat { rows == 0 ? 0 : IslandLayout.prHeaderHeight + CGFloat(rows) * IslandLayout.prRowHeight }
        let (authored, review) = (prRows(for: .authored).count, prRows(for: .review).count)
        let gap = authored > 0 && review > 0 ? IslandLayout.sectionSpacing : 0
        switch block {
        case .claude:
            let core = gaugeIsRing ? IslandLayout.claudeRingHeight
                : IslandLayout.claudeHeight + (ClaudeBlock.showsForecast(store, enabled: showForecast) ? IslandLayout.forecastExtra : 0)
            return core + (showCost ? IslandLayout.costExtra : 0)
        case .pullRequests: return section(authored) + gap + section(review)
        case .jira: return section(jiraRows.count)
        case .jiraApprovals: return section(approvalRows.count)
        case .focus: return IslandLayout.card(IslandLayout.focusContent)
        case .history: return IslandLayout.card(IslandLayout.historyContent)
        case .music: return IslandLayout.card(musicStore.nowPlaying.map(MusicBlock.contentHeight) ?? IslandLayout.musicContent)
        case .alerts: return IslandLayout.card(AlertsBlock.contentHeight(rows: min(recentAlerts.count, AlertsBlock.maxRows)))
        case .briefing: return IslandLayout.card(BriefingBlock.contentHeight(rows: min(briefingEntries.count, BriefingBlock.maxRows)))
        case .timeline: return IslandLayout.card(TimelineBlock.contentHeight)
        }
    }

    private var visibleColumns: [[IslandBlock]] { layout.columns.map { $0.filter(isVisible) } }

    /// A list section opens with a tall header (its label sits at the bottom of it). At the top of a column that would
    /// start lower than the other columns, so the empty part of the header is trimmed there.
    private static let headerTrim: CGFloat = 12
    private func topTrim(_ block: IslandBlock, atTop: Bool) -> CGFloat {
        atTop && (block == .pullRequests || block == .jira || block == .jiraApprovals) ? Self.headerTrim : 0
    }

    private func naturalHeight(of column: [IslandBlock]) -> CGFloat {
        var total: CGFloat = 0
        for (position, block) in column.enumerated() {
            total += height(of: block) - topTrim(block, atTop: position == 0)
        }
        return total + CGFloat(max(column.count - 1, 0)) * IslandLayout.sectionSpacing
    }

    /// Half of the screen at most; a taller column scrolls inside the island.
    private var maxColumnHeight: CGFloat { screenHeight * 0.5 }

    /// The shortcuts dock sits under the columns, centred and always last, so it adds to the height on its own.
    private var dockExtra: CGFloat { shortcuts.isEmpty ? 0 : IslandLayout.card(IslandLayout.shortcutsContent) + IslandLayout.sectionSpacing }

    /// The tallest column (capped) plus the dock sets the island's height.
    private var columnsHeight: CGFloat { min(visibleColumns.map(naturalHeight(of:)).max() ?? 0, maxColumnHeight) }

    private var contentHeight: CGFloat {
        let top = metrics.height + 6, bottom: CGFloat = 10
        return top + columnsHeight + dockExtra + bottom
    }

    @ViewBuilder private var attentionDot: some View {
        if !state.expanded, !state.fullscreen, prStore.attention != .none {
            Circle()
                .fill(prStore.attention == .critical ? Color.red : Color.orange)
                .frame(width: 7, height: 7)
                .offset(x: metrics.width / 2 + CGFloat(thickness) + 9, y: metrics.height / 2 - 3.5)
                .transition(.opacity)
        }
    }

    // MARK: Mini island (alert peek)

    private var miniHeight: CGFloat {
        metrics.height + 6 + CGFloat(max(peekItems.count, 1)) * IslandLayout.peekRowHeight + 10
    }

    /// A small island under the notch that lists only the PRs that just changed.
    private var miniIsland: some View {
        let shape = IslandShape(widthProgress: peekProgress, heightProgress: peekProgress,
                                notchWidth: metrics.width, notchHeight: metrics.height,
                                collapsedRadius: notchCornerRadius, expandedRadius: 18)
        return Color.clear
            .frame(width: IslandLayout.peekWidth, height: miniHeight)
            .background(alignment: .top) { shape.fill(Color.black) }
            .overlay(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(peekItems) { change in peekRow(change) }
                }
                .padding(.horizontal, 18)
                .padding(.top, metrics.height + 6)
                .frame(width: IslandLayout.peekWidth, alignment: .top)
                .opacity(peekContent)
                .scaleEffect(0.92 + 0.08 * peekContent, anchor: .top)
            }
            .clipShape(shape)
            .overlay(alignment: .top) {
                // Same silhouette as the mini island, stroked: the pulse hugs its border.
                IslandShape(widthProgress: peekProgress, heightProgress: peekProgress,
                            notchWidth: metrics.width, notchHeight: metrics.height,
                            collapsedRadius: notchCornerRadius, expandedRadius: 18, outlineOnly: true)
                    .stroke(alertColor, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .shadow(color: alertColor.opacity(0.9), radius: 7)
                    .opacity(alertOnMini ? alertOpacity : 0)
            }
            .overlay(alignment: .top) { if newSessionOnMini { miniSessionAnimation } }
            .opacity(state.expanded ? 0 : 1)
            .allowsHitTesting(false)
    }

    /// The new-session comet and flash, drawn on the mini island's outline instead of the notch ring (which is hidden then).
    @ViewBuilder private var miniSessionAnimation: some View {
        let t = CGFloat(thickness)
        let outline = IslandShape(widthProgress: peekProgress, heightProgress: peekProgress, notchWidth: metrics.width, notchHeight: metrics.height,
                                  collapsedRadius: notchCornerRadius, expandedRadius: 18, outlineOnly: true)
        let segments: [(from: CGFloat, to: CGFloat, opacity: Double, width: CGFloat)] = [
            (0.30, 0.20, 0.20, 0), (0.20, 0.10, 0.45, 0.5), (0.10, 0.03, 0.80, 1), (0.03, 0, 1, 2),
        ]
        ZStack {
            ForEach(segments.indices, id: \.self) { i in
                let s = segments[i]
                outline.trim(from: min(max(newSessionLap - s.from, 0), 1), to: min(max(newSessionLap - s.to, 0), 1))
                    .stroke(i == segments.count - 1 ? Color.white : Brand.green, style: StrokeStyle(lineWidth: t + s.width, lineCap: .round))
                    .shadow(color: Brand.green.opacity(0.9 * s.opacity), radius: 3 + 4 * s.opacity)
                    .opacity(s.opacity)
            }
            outline.stroke(Brand.green, style: StrokeStyle(lineWidth: t + 1.5, lineCap: .round))
                .shadow(color: Brand.green.opacity(0.9), radius: 7)
                .opacity(newSessionFlash)
        }
        .frame(width: IslandLayout.peekWidth, height: miniHeight, alignment: .top)
    }

    private func peekRow(_ change: PRChange) -> some View {
        HStack(spacing: 6) {
            Circle().fill(change.tone.color).frame(width: 7, height: 7).frame(width: 14)
            Text(change.kind.origin).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.55))
            Text(change.ref).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            Text(change.title).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            tag(change.label, change.tone.color)
        }
        .frame(height: IslandLayout.peekRowHeight)
    }

    /// Blue dot that stays until the island is opened and closed; sits next to the attention dot.
    @ViewBuilder private var newsDot: some View {
        if alertDot, !state.expanded, !state.fullscreen, !prStore.unseen.isEmpty {
            Circle()
                .fill(PRChange.Tone.info.color)
                .frame(width: 7, height: 7)
                .offset(x: metrics.width / 2 + CGFloat(thickness) + 9 + (prStore.attention != .none ? 11 : 0), y: metrics.height / 2 - 3.5)
                .transition(.scale.combined(with: .opacity))
        }
    }

    /// Full ring flashing in the change's colour, drawn even when the normal border is turned off.
    private var alertRing: some View {
        let t = showBorder ? CGFloat(thickness) : 3
        return NotchRing(cornerRadius: notchCornerRadius + t / 2, inset: t / 2)
            .stroke(alertColor, style: StrokeStyle(lineWidth: t + 1.5, lineCap: .round))
            .shadow(color: alertColor.opacity(0.9), radius: 7)
            .frame(width: metrics.width + 2 * t, height: metrics.height + t)
            .opacity(state.expanded || state.fullscreen || alertOnMini ? 0 : alertOpacity)
            .allowsHitTesting(false)
    }

    private func playAlertPulse() {
        guard alertPulse, !state.expanded else { return }
        alertColor = (prStore.lastChanges.map(\.tone).max() ?? .info).color
        alertOnMini = alertBanner
        // Two quick flashes.
        for i in 0..<2 {
            let start = Double(i) * 0.85
            DispatchQueue.main.asyncAfter(deadline: .now() + start) { withAnimation(.easeOut(duration: 0.18)) { alertOpacity = 1 } }
            DispatchQueue.main.asyncAfter(deadline: .now() + start + 0.2) { withAnimation(.easeIn(duration: 0.55)) { alertOpacity = 0 } }
        }
    }

    private var anyRefreshing: Bool { store.isRefreshing || prStore.isRefreshing || jiraStore.isRefreshing }

    /// Mirror of the attention dot: that one sits right of the notch, this one left of it.
    @ViewBuilder private var syncIndicator: some View {
        if !state.expanded, syncing || anyRefreshing {
            SyncIcon()
                .offset(x: -(metrics.width / 2 + CGFloat(thickness) + 11), y: metrics.height / 2 - 5)
                .transition(.opacity)
        }
    }

    @ViewBuilder private func pullRequestSection(_ list: PRList) -> some View {
        let rows = prRows(for: list)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(list == .authored ? "Os meus PRs" : "A rever")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(height: IslandLayout.prHeaderHeight, alignment: .bottom)
                    .padding(.bottom, 2)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    switch row {
                    case .pr(let pr): prRow(pr)
                    case .message(let text):
                        Text(text).font(.caption).foregroundStyle(.secondary).frame(height: IslandLayout.prRowHeight, alignment: .leading)
                    case .more(let count):
                        expander("+\(count) mais") { setShowAll(list, true) }
                    case .less:
                        expander("mostrar menos") { setShowAll(list, false) }
                    case .overflow(let count):
                        Text("+\(count) não listados").font(.caption2).foregroundStyle(.secondary).frame(height: IslandLayout.prRowHeight, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder private func jiraSection(title: String, rows: [JiraRow], showAll: ReferenceWritableKeyPath<IslandState, Bool>, alerts: Bool) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(height: IslandLayout.prHeaderHeight, alignment: .bottom)
                    .padding(.bottom, 2)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    switch row {
                    case .task(let task): jiraRow(task, alerts: alerts)
                    case .message(let text):
                        Text(text).font(.caption).foregroundStyle(.secondary).frame(height: IslandLayout.prRowHeight, alignment: .leading)
                    case .more(let count):
                        expander("+\(count) mais") { state[keyPath: showAll] = true }
                    case .less:
                        expander("mostrar menos") { state[keyPath: showAll] = false }
                    case .overflow(let count):
                        Text("+\(count) não listados").font(.caption2).foregroundStyle(.secondary).frame(height: IslandLayout.prRowHeight, alignment: .leading)
                    }
                }
            }
        }
    }

    private func jiraRow(_ task: JiraTask, alerts: Bool) -> some View {
        let change = alerts && alertRow ? prStore.unseen.last(where: { $0.prID == "jira-" + task.key }) : nil
        return Button { NSWorkspace.shared.open(task.url) } label: {
            HStack(spacing: 8) {
                Circle().fill(task.category == .inProgress ? Color.blue : Color.gray).frame(width: 7, height: 7).frame(width: 14)
                Text(task.key).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Text(task.summary).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                if let symbol = prioritySymbol(task.priority) {
                    Image(systemName: symbol.name).font(.caption2).foregroundStyle(symbol.color).islandTip("Prioridade: " + (task.priority ?? ""))
                }
                if let change { tag(change.kind == .jiraStatus ? "novo estado" : change.label, change.tone.color) }
                if task.isSprintGoal { tag("★ sprint goal", .yellow) }
                tag(task.status, task.category == .inProgress ? .blue : .gray)
                ownerTag(name: task.assignee, isMine: task.assignee != nil && task.assignee == jiraStore.myName)
            }
            .frame(height: IslandLayout.prRowHeight)
            .background {
                if let change {
                    RoundedRectangle(cornerRadius: 5).fill(change.tone.color.opacity(0.16)).padding(.horizontal, -6)
                }
                else if task.isSprintGoal { RoundedRectangle(cornerRadius: 5).fill(Color.yellow.opacity(0.13)).padding(.horizontal, -6) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(task.isSprintGoal ? "Sprint goal · " + task.summary : task.summary)
    }

    private func prioritySymbol(_ priority: String?) -> (name: String, color: Color)? {
        switch priority?.lowercased() {
        case "highest", "blocker", "critical": return ("chevron.up.2", .red)
        case "high", "major": return ("chevron.up", .orange)
        case "low", "minor": return ("chevron.down", .teal)
        case "lowest", "trivial": return ("chevron.down.2", .teal)
        default: return nil
        }
    }

    /// A clickable "+N mais" / "mostrar menos" row.
    private func expander(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(Color(red: 0.45, green: 0.68, blue: 1.0))
                .frame(maxWidth: .infinity, minHeight: IslandLayout.prRowHeight, maxHeight: IslandLayout.prRowHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func prRow(_ pr: PullRequest) -> some View {
        let change = alertRow ? prStore.unseen.last(where: { $0.prID == pr.id }) : nil
        return Button { NSWorkspace.shared.open(pr.url) } label: {
            HStack(spacing: 8) {
                Image(systemName: ciSymbol(pr.ci)).foregroundStyle(ciColor(pr.ci)).frame(width: 14)
                    .islandTip(ciText(pr.ci))
                if pr.hasConflicts { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).islandTip("Conflitos com a branch base") }
                reviewIcon(pr)
                Text("\(pr.repository.split(separator: "/").last.map(String.init) ?? pr.repository)#\(pr.number)")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Text(pr.title).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                if let change {
                    tag(change.label, change.tone.color)
                } else if let reason = attentionReason(pr) {
                    tag(reason.text, reason.tone.color)
                }
                if pr.role == .authored, let comments = pr.unresolvedThreadCount, comments > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left.fill").font(.system(size: 8))
                        Text("\(comments)").font(.system(size: 9, weight: .semibold).monospacedDigit())
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 5).padding(.vertical, 1).background(Capsule().fill(Color.white.opacity(0.14)))
                    .islandTip("\(comments) thread\(comments == 1 ? "" : "s") por resolver")
                }
                if pr.isDraft { tag("draft", .gray) }
                ownerTag(name: pr.author, isMine: pr.isMine)
            }
            .frame(height: IslandLayout.prRowHeight)
            .background {
                if let change {
                    RoundedRectangle(cornerRadius: 5).fill(change.tone.color.opacity(0.16)).padding(.horizontal, -6)
                } else if pr.role == .reviewRequested, let reason = attentionReason(pr), reason.tone != .info {
                    RoundedRectangle(cornerRadius: 5).fill(reason.tone.color.opacity(0.12)).padding(.horizontal, -6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(pr.title)
        .opacity(PRMutes.isMuted(prID: pr.id, in: PRMutes.decode(mutesJSON)) ? 0.45 : 1)
        .contextMenu { prMenu(pr) }
    }

    @ViewBuilder private func prMenu(_ pr: PullRequest) -> some View {
        Button("Abrir no navegador") { NSWorkspace.shared.open(pr.url) }
        Button("Copiar link") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pr.url.absoluteString, forType: .string)
        }
        if pr.ci == .failing {
            Button("Abrir o CI com falha") { NSWorkspace.shared.open(pr.url.appendingPathComponent("checks")) }
        }
        Divider()
        let mutes = PRMutes.decode(mutesJSON)
        if PRMutes.isMuted(prID: pr.id, in: mutes) {
            Button("Reativar avisos") {
                let repoKey = "repo:" + pr.repository
                setMutes(PRMutes.removing(key: repoKey, from: PRMutes.removing(key: "pr:" + pr.id, from: mutes)))
            }
        } else {
            Menu("Silenciar este PR") {
                Button("1 hora") { mute(.pr(pr, until: Date().addingTimeInterval(3600))) }
                Button("1 dia") { mute(.pr(pr, until: Date().addingTimeInterval(86400))) }
                Button("Até eu reativar") { mute(.pr(pr, until: nil)) }
            }
            Menu("Silenciar o repositório") {
                Button("1 dia") { mute(.repository(pr, until: Date().addingTimeInterval(86400))) }
                Button("Até eu reativar") { mute(.repository(pr, until: nil)) }
            }
        }
    }

    private func mute(_ mute: PRMute) { setMutes(PRMutes.adding(mute, to: PRMutes.decode(mutesJSON))) }
    private func setMutes(_ list: [PRMute]) { mutesJSON = PRMutes.encode(list) }

    /// Why a PR needs attention right now, so the row says it in words and not only with an icon. In the review block
    /// this is only a label: it never feeds the attention dot or the alerts.
    private func attentionReason(_ pr: PullRequest) -> (text: String, tone: PRChange.Tone)? {
        if pr.role == .reviewRequested {
            // The verdict the user gave stays on the row until the PR is merged or closed.
            if pr.review == .changesRequested { return ("rejeitado", .critical) }
            if pr.review == .approved { return pr.teamReview == .approved ? ("aprovado", .success) : ("aprovaste", .info) }
        }
        if pr.ci == .failing { return ("CI falhou", .critical) }
        if pr.hasConflicts { return ("conflitos", .warning) }
        if pr.review == .changesRequested { return ("alterações pedidas", .warning) }
        return nil
    }

    /// "eu" on the user's own PRs and tasks, the owner's initials on the rest, so a mixed list reads at a glance.
    @ViewBuilder private func ownerTag(name: String?, isMine: Bool) -> some View {
        if showOwner, let label = Owner.label(name: name, isMine: isMine) {
            Text(label)
                .font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(isMine ? 0.95 : 0.7))
                .frame(minWidth: 16)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(Capsule().fill(isMine ? Brand.blue.opacity(0.75) : Color.white.opacity(0.14)))
                .islandTip(isMine ? "Teu" : (name ?? ""))
        }
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 5).padding(.vertical, 1).background(Capsule().fill(color.opacity(0.4)))
    }

    private func ciSymbol(_ ci: CIState) -> String {
        switch ci {
        case .passing: return "checkmark.circle.fill"
        case .failing: return "xmark.circle.fill"
        case .pending: return "clock.fill"
        case .none: return "circle.dashed"
        }
    }

    private func ciText(_ ci: CIState) -> String {
        switch ci {
        case .passing: return "CI a passar"
        case .failing: return "CI falhou"
        case .pending: return "CI a correr"
        case .none: return "Sem CI"
        }
    }

    private func ciColor(_ ci: CIState) -> Color {
        switch ci {
        case .passing: return .green
        case .failing: return .red
        case .pending: return .yellow
        case .none: return .gray
        }
    }

    @ViewBuilder private func reviewIcon(_ pr: PullRequest) -> some View {
        // My own approval on a review request is not the PR's: it is only "approved" once the approval bar is met.
        if pr.role == .reviewRequested, pr.review == .approved, pr.teamReview != .approved {
            Image(systemName: "checkmark.circle").foregroundStyle(.gray).islandTip("Aprovaste; faltam aprovações")
        } else {
            reviewIcon(pr.review)
        }
    }

    @ViewBuilder private func reviewIcon(_ review: ReviewState) -> some View {
        switch review {
        case .approved: Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).islandTip("Aprovado")
        case .changesRequested: Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange).islandTip("Alterações pedidas")
        case .reviewRequired: Image(systemName: "eye").foregroundStyle(.gray).islandTip("Aguarda review")
        case .none: EmptyView()
        }
    }

    private func color(forFraction fraction: Double) -> Color {
        switch UsageLevel.level(forFraction: fraction, amber: amber, red: red) {
        case .normal: return Color(red: 0x28 / 255, green: 0xC8 / 255, blue: 0x40 / 255)   // macOS zoom button
        case .warning: return Color(red: 0xFE / 255, green: 0xBC / 255, blue: 0x2E / 255)   // macOS minimise button
        case .critical: return Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)   // macOS close button
        }
    }

    private var ringOpacity: Double {
        if store.status == .ok { return 1 }
        return store.isEstimate ? 0.75 : 0.45
    }

    private var statusColor: Color {
        store.hasValue ? color(forFraction: store.sessionFraction) : .gray
    }

    // MARK: Collapsed ring

    @ViewBuilder private var ring: some View {
        if showBorder, !state.fullscreen {
            let t = CGFloat(thickness)
            let shape = NotchRing(cornerRadius: notchCornerRadius + t / 2, inset: t / 2)
            ZStack {
                shape.stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: t))
                if store.hasValue, store.sessionFraction > 0.001 {
                    // Dimmed while the last refresh failed, so a stale value is not mistaken for a live one.
                    shape.trim(from: 0, to: store.sessionFraction)
                        .stroke(statusColor.opacity(ringOpacity), style: StrokeStyle(lineWidth: t + 1.5 * glow, lineCap: .round))
                        .shadow(color: statusColor.opacity((0.45 + 0.5 * glow) * ringOpacity), radius: 2.5 + 5 * glow)
                } else if !store.hasValue && store.status != .loading {
                    shape.stroke(Color.gray.opacity(0.6), style: StrokeStyle(lineWidth: t, dash: [3, 4]))
                }
                focusRing(shape, thickness: t)
                if isOffline {
                    shape.stroke(Brand.red, style: StrokeStyle(lineWidth: t + 1.5, lineCap: .round))
                        .shadow(color: Brand.red.opacity(0.8), radius: 5)
                }
                newSessionComet(shape, thickness: t)
                shape.stroke(Brand.green, style: StrokeStyle(lineWidth: t + 1.5, lineCap: .round))
                    .shadow(color: Brand.green.opacity(0.9), radius: 7)
                    .opacity(newSessionFlash)
            }
            .overlay {
                RingSweep(base: shape, sweep: sweep)
                    .stroke(Color.white.opacity(0.95 * sweepOpacity), style: StrokeStyle(lineWidth: t, lineCap: .round))
                    .shadow(color: .white.opacity(0.8 * sweepOpacity), radius: 4)
            }
            .frame(width: metrics.width + 2 * t, height: metrics.height + t)
            .opacity(state.expanded || !state.peek.isEmpty ? 0 : 1)
            // Hidden at once when the island opens (the open spring would otherwise leave it fading while the shape grows);
            // it comes back softly, after the island has closed.
            .animation(state.expanded || !state.peek.isEmpty ? nil : .easeIn(duration: 0.25).delay(0.35), value: state.expanded || !state.peek.isEmpty)
            .animation(.easeInOut(duration: 0.8), value: store.sessionFraction)
            .animation(.easeInOut(duration: 0.4), value: isOffline)
        }
    }

    /// While the Pomodoro runs, its elapsed time fills the border (blue for focus, green for a break) on top of the Claude
    /// ring, which stays visible dimmed underneath. Hidden when the timer is stopped.
    @ViewBuilder private func focusRing(_ shape: NotchRing, thickness t: CGFloat) -> some View {
        if focusStore.timer.isRunning {
            let tint = focusStore.timer.phase == .focus ? Brand.blue : Brand.green
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let progress = max(focusStore.timer.progress(now: context.date, focusStore.config), 0.004)
                ZStack {
                    shape.stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: t))   // knocks the usage ring back
                    shape.stroke(tint.opacity(0.22), style: StrokeStyle(lineWidth: t))
                    shape.trim(from: 0, to: progress)
                        .stroke(tint, style: StrokeStyle(lineWidth: t + 0.5, lineCap: .round))
                        .shadow(color: tint.opacity(0.6), radius: 3)
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .transition(.opacity)
        }
    }

    /// A comet with a fading tail: head and three tail segments, each trimmed from the same ring.
    @ViewBuilder private func newSessionComet(_ shape: NotchRing, thickness t: CGFloat) -> some View {
        let segments: [(from: CGFloat, to: CGFloat, opacity: Double, width: CGFloat)] = [
            (0.30, 0.20, 0.20, 0), (0.20, 0.10, 0.45, 0.5), (0.10, 0.03, 0.80, 1), (0.03, 0, 1, 2),
        ]
        ForEach(segments.indices, id: \.self) { i in
            let s = segments[i]
            shape.trim(from: min(max(newSessionLap - s.from, 0), 1), to: min(max(newSessionLap - s.to, 0), 1))
                .stroke(i == segments.count - 1 ? Color.white : Brand.green, style: StrokeStyle(lineWidth: t + s.width, lineCap: .round))
                .shadow(color: Brand.green.opacity(0.9 * s.opacity), radius: 3 + 4 * s.opacity)
                .opacity(s.opacity)
        }
    }

    /// Two small sparkles beside the notch that pop and spin while the border lights up.
    @ViewBuilder private var newSessionSparkles: some View {
        if newSessionSparkle > 0 {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(side < 0 ? Brand.green : Color.white)
                    .shadow(color: Brand.green.opacity(0.9), radius: 4)
                    .scaleEffect(0.3 + 0.9 * newSessionSparkle)
                    .rotationEffect(.degrees(side * 90 * (1 - newSessionSparkle)))
                    .opacity(newSessionSparkle)
                    // Beside the mini island when it announces the session, beside the notch otherwise.
                    .offset(x: side * ((newSessionOnMini ? IslandLayout.peekWidth : metrics.width) / 2 + CGFloat(thickness) + 16), y: metrics.height / 2 - 6)
                    .allowsHitTesting(false)
            }
        }
    }

    /// A new Claude session has started: a comet laps the border, the border lights up as it closes, sparkles pop.
    private func playNewSessionAnimation() {
        guard showBorder, !state.expanded, !state.fullscreen else { return }
        withTransaction(Transaction(animation: nil)) { newSessionLap = 0; newSessionFlash = 0; newSessionSparkle = 0 }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 1.25)) { newSessionLap = 1.3 }
            // The border lights up as the head comes back to where it started.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                withAnimation(.easeOut(duration: 0.2)) { newSessionFlash = 1; newSessionSparkle = 1 }
                withAnimation(.easeIn(duration: 0.7).delay(0.2)) { newSessionFlash = 0 }
                withAnimation(.easeIn(duration: 0.6).delay(0.55)) { newSessionSparkle = 0 }
            }
        }
    }

    private func playUpdateAnimation() {
        guard showBorder, !state.expanded else { return }
        // Reset without animation first, otherwise the sweep would start from where the last one ended.
        withTransaction(Transaction(animation: nil)) { sweep = 0; sweepOpacity = 1 }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.95)) { sweep = 1.22 }
            withAnimation(.easeOut(duration: 0.25)) { glow = 1 }
            withAnimation(.easeIn(duration: 0.8).delay(0.25)) { glow = 0 }
            withAnimation(.easeIn(duration: 0.3).delay(0.75)) { sweepOpacity = 0 }
        }
    }

    // MARK: Island body

    // Speed and bounce come from Settings; the effect decides how width and height are staged.
    private var speed: Double { min(max(animSpeed, 0.5), 3) }
    private var openDamping: Double { 0.92 - 0.38 * min(max(animBounce, 0), 1) }
    private var effect: IslandEffect { IslandEffect(stored: effectName) }

    private struct Motion {
        var width: Animation
        var height: Animation
        var contentDelay: TimeInterval
    }

    private func motion(opening: Bool) -> Motion {
        let s = speed
        let damp = openDamping
        func spring(_ response: Double, _ damping: Double) -> Animation { .spring(response: response / s, dampingFraction: min(max(damping, 0.3), 0.97)) }
        switch effect {
        case .spring:
            return opening
                ? Motion(width: spring(0.42, damp), height: spring(0.54, damp - 0.06), contentDelay: 0.10 / s)
                : Motion(width: spring(0.34, damp + 0.22), height: spring(0.38, damp + 0.2), contentDelay: 0)
        case .genie:
            let open = Animation.timingCurve(0.3, 0.0, 0.15, 1.0, duration: 0.62 / s)
            let close = Animation.timingCurve(0.55, 0.0, 0.85, 0.35, duration: 0.42 / s)
            return Motion(width: opening ? open : close, height: opening ? open : close, contentDelay: 0.14 / s)
        case .drop:
            return opening
                ? Motion(width: spring(0.5, damp - 0.05).delay(0.14 / s), height: spring(0.5, damp - 0.12), contentDelay: 0.16 / s)
                : Motion(width: .easeIn(duration: 0.26 / s), height: .easeIn(duration: 0.3 / s).delay(0.08 / s), contentDelay: 0)
        case .dissolve:
            let a = opening ? Animation.easeOut(duration: 0.36 / s) : .easeIn(duration: 0.26 / s)
            return Motion(width: a, height: a, contentDelay: 0.08 / s)
        case .hinge:
            let a = opening ? spring(0.55, damp) : spring(0.36, damp + 0.2)
            return Motion(width: a, height: a, contentDelay: 0.14 / s)
        case .slit:
            return opening
                ? Motion(width: .easeOut(duration: 0.3 / s), height: spring(0.46, damp).delay(0.22 / s), contentDelay: 0.34 / s)
                : Motion(width: .easeIn(duration: 0.26 / s).delay(0.2 / s), height: .easeIn(duration: 0.26 / s), contentDelay: 0)
        }
    }

    /// Scale and blur the details start from (and return to) while they fade in or out.
    private var contentFrom: (x: CGFloat, y: CGFloat, blur: CGFloat) {
        switch effect {
        case .spring: return (0.84, 0.84, 8)
        case .genie: return (0.5, 0.6, 6)
        case .drop: return (0.9, 0.6, 4)
        case .slit: return (1, 1, 0)
        case .dissolve: return (1, 1, 14)
        case .hinge: return (0.92, 0.92, 0)
        }
    }

    private var island: some View {
        let from = contentFrom
        let shape = IslandShape(widthProgress: widthProgress, heightProgress: heightProgress,
                                notchWidth: metrics.width, notchHeight: metrics.height,
                                funnel: effect == .genie, collapsedRadius: notchCornerRadius)
        let hinge = effect == .hinge ? -78 * (1 - min(max(heightProgress, 0), 1)) : 0
        return Color.clear
            .frame(width: layoutWidth, height: contentHeight)
            .animation(.spring(response: 0.45 / speed, dampingFraction: min(openDamping + 0.1, 0.95)), value: contentHeight)
            .animation(.spring(response: 0.45 / speed, dampingFraction: min(openDamping + 0.1, 0.95)), value: layoutWidth)
            .background(alignment: .top) { shape.fill(Color.black) }
            .overlay(alignment: .topTrailing) { HStack(spacing: 2) { restartButton; gearButton } }
            .overlay(alignment: .top) {
                details
                    .frame(width: layoutWidth, height: contentHeight, alignment: .top)
                    .scaleEffect(x: showContent ? 1 : from.x, y: showContent ? 1 : from.y, anchor: .top)
                    .blur(radius: showContent ? 0 : from.blur)
                    .opacity(showContent ? 1 : 0)
                    .allowsHitTesting(showContent)
            }
            .clipShape(shape)
            .rotation3DEffect(.degrees(hinge), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
    }

    private var restartButton: some View {
        Button(action: { ErrorLog.relaunch() }) {
            Image(systemName: "arrow.clockwise").font(.system(size: 12)).foregroundStyle(.secondary)
                .frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Reiniciar o Dr Island")
        .padding(.top, (metrics.height - 24) / 2)
        .scaleEffect(showContent ? 1 : 0.5)
        .opacity(showContent ? 1 : 0)
        .allowsHitTesting(showContent)
    }

    private var gearButton: some View {
        Button(action: openSettings) {
            Image(systemName: "gearshape").font(.system(size: 13)).foregroundStyle(.secondary)
                .frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Definições")
        .padding(.top, (metrics.height - 24) / 2)
        .padding(.trailing, 20)
        .scaleEffect(showContent ? 1 : 0.5)
        .opacity(showContent ? 1 : 0)
        .allowsHitTesting(showContent)
    }

    @ViewBuilder private func blockView(_ block: IslandBlock) -> some View {
        switch block {
        case .claude: ClaudeBlock(store: store, costStore: costStore, showCost: showCost)
        case .pullRequests:
            VStack(alignment: .leading, spacing: IslandLayout.sectionSpacing) {
                pullRequestSection(.authored)
                pullRequestSection(.review)
            }
        case .jira: jiraSection(title: "Jira", rows: jiraRows, showAll: \.showAllJira, alerts: true)
        case .jiraApprovals: jiraSection(title: "Aprovações", rows: approvalRows, showAll: \.showAllApprovals, alerts: true)
        case .focus: FocusBlock(store: focusStore)
        case .history: historyChart
        case .music: MusicBlock(store: musicStore)
        case .alerts: AlertsBlock(entries: recentAlerts, openAll: openHistory)
        case .briefing: BriefingBlock(entries: briefingEntries, since: Date(timeIntervalSince1970: briefingSince), dismiss: { Briefing.dismiss() })
        case .timeline: TimelineBlock(counts: todayCounts, showBriefing: { Briefing.activate() }, openDetails: { openSettingsPage(.day) })
        }
    }

    private var details: some View {
        VStack(spacing: IslandLayout.sectionSpacing) {
            HStack(alignment: .top, spacing: Self.columnGap) {
                ForEach(Array(visibleColumns.enumerated()), id: \.offset) { index, column in
                    if index > 0 {
                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                    }
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: IslandLayout.sectionSpacing) {
                            ForEach(Array(column.enumerated()), id: \.element) { position, block in
                                blockView(block).padding(.top, -topTrim(block, atTop: position == 0))
                            }
                        }
                        .frame(width: columnWidth, alignment: .topLeading)
                    }
                    .frame(width: columnWidth, height: min(naturalHeight(of: column), maxColumnHeight), alignment: .top)
                    .environment(\.islandColumnWidth, columnWidth)
                }
            }
            .frame(height: columnsHeight, alignment: .top)
            shortcutsRow
        }
        .padding(.horizontal, Self.sidePadding)
        .padding(.top, metrics.height + 6)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }

    private var statusMessage: String? {
        if store.isRefreshing { return "A atualizar…" }
        if store.isEstimate && store.status == .rateLimited { return "Estimado a partir dos logs locais · API limitada\(store.retryHint)" }
        if store.isEstimate { return "Estimado a partir dos logs locais" }
        switch store.status {
        case .ok, .loading: return nil
        case .noCredentials: return "Faz login no Claude Code"
        case .unauthorized: return "Sessão expirada — abre o Claude Code"
        case .offline: return "Sem ligação — último valor"
        case .rateLimited: return "API de uso limitou os pedidos\(store.retryHint) — último valor"
        }
    }

    private func bar(fraction: Double, color: Color, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(color).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: height)
    }

    @ViewBuilder private func resetLabel(_ date: Date?, prefix: String) -> some View {
        if let date {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text("\(prefix) \(RemainingTime.string(until: date, now: context.date))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Confetti that bursts from under the notch and falls with a little gravity whenever `tick` changes.
struct ConfettiBurst: View {
    let tick: Int
    @State private var progress: CGFloat = 0

    private struct Piece: Identifiable {
        let id: Int
        let angle: Double, distance: CGFloat, spin: Double, size: CGSize, color: Color
    }

    /// Fixed, so the burst looks the same every time and needs no randomness at draw time.
    private static let pieces: [Piece] = {
        let colors = [Brand.green, Brand.amber, Brand.blue, Brand.red, Color.white, Color(red: 0.8, green: 0.5, blue: 1)]
        return (0..<36).map { i in
            let t = Double(i)
            return Piece(id: i,
                         angle: .pi * (0.08 + 0.84 * (t.truncatingRemainder(dividingBy: 12) / 11)),   // fan below the notch
                         distance: 70 + CGFloat((i * 37) % 90),
                         spin: 180 + Double((i * 53) % 360),
                         size: CGSize(width: 4 + CGFloat(i % 3) * 2, height: 7 + CGFloat(i % 2) * 3),
                         color: colors[i % colors.count])
        }
    }()

    private static let duration: TimeInterval = 2.2
    @State private var startedAt: Date?

    var body: some View {
        // Driven by the clock instead of an animated value: opacity and gravity are not linear in `progress`.
        TimelineView(.animation(paused: startedAt == nil)) { context in
            let t = startedAt.map { context.date.timeIntervalSince($0) / Self.duration } ?? 1
            ZStack {
                if t >= 0 && t < 1 {
                    let progress = CGFloat(1 - pow(1 - t, 3))   // ease-out for the burst
                    ForEach(Self.pieces) { p in
                        Rectangle()
                            .fill(p.color)
                            .frame(width: p.size.width, height: p.size.height)
                            .rotationEffect(.degrees(p.spin * t))
                            .offset(x: CGFloat(cos(p.angle)) * p.distance * 1.6 * progress,
                                    y: CGFloat(sin(p.angle)) * p.distance * 0.5 * progress + 90 * CGFloat(t * t))
                            .opacity(min(1, (1 - t) * 3))
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: tick) { _, _ in
            let now = Date()
            startedAt = now
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.1) { if startedAt == now { startedAt = nil } }
        }
    }
}
