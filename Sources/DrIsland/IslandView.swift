import SwiftUI
import DrIslandCore

struct IslandView: View {
    let metrics: NotchMetrics
    let expandedSize: CGSize
    let state: IslandState
    let store: UsageStore
    let prStore: PullRequestStore
    let jiraStore: JiraStore
    let musicStore: MusicStore
    let costStore: CostStore
    let focusStore: FocusStore
    var openSettings: () -> Void
    /// Height of the screen this island is on: the columns never grow past half of it, they scroll instead.
    var screenHeight: CGFloat = 900

    @State private var showContent = false
    /// The tooltip being shown (see `islandTip`).
    @State private var tips = IslandTipCenter()
    /// macOS «Reduzir movimento»: the island fades instead of growing or springing, and the decorative motion (comet,
    /// sweep, sparkles, confetti, dock magnification) is skipped. Pure opacity effects stay.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    /// Only below 1 with Reduce Motion, where the mini island fades instead of growing out of the notch.
    @State private var peekOpacity: Double = 1
    @State private var peekItems: [PRChange] = []   // kept while the mini island folds back, so it does not go blank
    @State private var confettiTick = 0
    @AppStorage(SettingsKey.alertConfetti) private var alertConfetti = true
    /// The pulse follows the mini island when that alert is on, otherwise the notch ring.
    @State private var alertOnMini = false
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
    @AppStorage(SettingsKey.showSprint) private var showSprint = true
    @AppStorage(SettingsKey.showOutOfSprint) private var showOutOfSprint = true
    @AppStorage(SettingsKey.jiraBacklogEnabled) private var showBacklog = true
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

    private let network = NetworkMonitor.shared
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
            IslandTipLayer(tips: tips, state: state, expandedSize: expandedSize)
        }
        .frame(width: expandedSize.width, height: expandedSize.height, alignment: .top)
        .coordinateSpace(.named(islandRootSpace))
        .environment(tips)
        .animation(.easeOut(duration: 0.2), value: state.expanded)
        .animation(.easeInOut(duration: 0.2), value: syncing)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: prStore.unseen.isEmpty)
        .onChange(of: anyRefreshing) { _, refreshing in
            guard refreshing else { return }
            syncing = true
            Task { try? await Task.sleep(for: .seconds(1)); syncing = false }
        }
        .onChange(of: state.peek) { _, items in
            if items.isEmpty {
                newSessionOnMini = false
                if reduceMotion {
                    withAnimation(.easeIn(duration: 0.2)) { peekContent = 0; peekOpacity = 0 } completion: {
                        if state.peek.isEmpty { peekProgress = 0 }
                    }
                    return
                }
                withAnimation(.easeIn(duration: 0.12 / speed)) { peekContent = 0 }
                withAnimation(.spring(response: 0.34 / speed, dampingFraction: 0.9)) { peekProgress = 0 }
            } else {
                peekItems = items
                if reduceMotion {
                    // Already full size, so it only fades in.
                    withTransaction(Transaction(animation: nil)) { peekProgress = 1 }
                    withAnimation(.easeOut(duration: 0.2)) { peekContent = 1; peekOpacity = 1 }
                    return
                }
                peekOpacity = 1
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
        .onChange(of: prKeys, initial: true) { _, keys in jiraStore.watchPRKeys(keys) }
        .onChange(of: layoutWidth, initial: true) { _, width in state.visibleWidth = width }
        .onChange(of: state.expanded) { _, expanded in
            if !expanded { tips.tip = nil }
            let motion = motion(opening: expanded)
            withAnimation(motion.width) { widthProgress = expanded ? 1 : 0 }
            withAnimation(motion.height) { heightProgress = expanded ? 1 : 0 }
            if expanded {
                // The content "arrives" slightly after the bubble starts growing, then settles with a spring.
                Task {
                    try? await Task.sleep(for: .seconds(motion.contentDelay))
                    guard state.expanded else { return }
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.46 / speed, dampingFraction: min(openDamping + 0.1, 0.95))) { showContent = true }
                }
            } else {
                withAnimation(.easeIn(duration: 0.12 / speed)) { showContent = false }
                // Closing after being opened means the user has seen what changed.
                if !state.isPreview { prStore.markSeen() }
            }
        }
    }

    // MARK: Pull requests

    /// With an active sprint on show, a PR is "fora da sprint" when its title names no Jira task of that sprint (or
    /// names none at all). While the sprint of its keys is still being looked up it stays where it is.
    private var splitsPRsBySprint: Bool { showSprint && showOutOfSprint && jiraStore.sprint != nil }

    private func isOutOfSprint(_ pr: PullRequest) -> Bool {
        guard splitsPRsBySprint else { return false }
        let keys = JiraKeys.extract(from: pr.title)
        if keys.isEmpty { return true }
        guard keys.allSatisfy({ jiraStore.prSprint[$0] != nil }) else { return false }
        return !keys.contains { jiraStore.prSprint[$0] == true }
    }

    private var prKeys: Set<String> {
        Set((prStore.snapshot.authored + (includeReviews ? prStore.snapshot.reviewRequested : [])).flatMap { JiraKeys.extract(from: $0.title) })
    }

    private func prRows(for list: PRList) -> [PRRow] {
        if list == .review && !includeReviews { return [] }
        if list == .outOfSprint {
            // Each PR once, so its row id is unique in the section.
            var seen = Set<String>()
            let items = (prStore.snapshot.authored + (includeReviews ? prStore.snapshot.reviewRequested : []))
                .filter { isOutOfSprint($0) && seen.insert($0.id).inserted }
            let expanded = state.showAllPROutOfSprint
            let limit = expanded ? IslandLayout.expandedRowLimit : IslandLayout.maxPullRequestRows
            var rows = items.prefix(limit).map(PRRow.pr)
            if items.count > limit { rows.append(expanded ? .overflow(items.count - limit) : .more(items.count - limit)) }
            if expanded && items.count > IslandLayout.maxPullRequestRows { rows.append(.less) }
            return rows
        }
        let all = list == .authored ? prStore.snapshot.authored : prStore.snapshot.reviewRequested
        let items = all.filter { !isOutOfSprint($0) }
        if items.isEmpty && !all.isEmpty { return [] }   // all of them are in the "Fora da Sprint" section
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

    /// The unseen changes that tag their PR or task row (none with row alerts off).
    private var rowChanges: [PRChange] { alertRow ? prStore.unseen : [] }

    private func setShowAll(_ list: PRList, _ value: Bool) {
        switch list {
        case .authored: state.showAllPRs = value
        case .review: state.showAllReviews = value
        case .outOfSprint: state.showAllPROutOfSprint = value
        }
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

    private var backlogGroups: [BacklogBlock.Group] {
        jiraStore.backlog.map { group in
            BacklogBlock.Group(id: group.id, title: "\(group.title) · \(group.tasks.count)",
                               rows: jiraTaskRows(group.tasks, expanded: state.expandedBacklog.contains(group.id)))
        }
    }

    private var backlogMessage: String? {
        guard jiraStore.backlog.isEmpty else { return nil }
        guard jiraStore.status == .ok else { return jiraRows(for: [], expanded: false).first.flatMap { if case .message(let text) = $0 { text } else { nil } } }
        if jiraStore.backlogFailed { return "Jira: JQL do backlog inválido" }
        if Settings.jiraBacklogJQL(guessedProject: Backlog.guessProject(from: jiraStore.tasks.map(\.key))) == nil { return "Indica o projeto do backlog nas Definições" }
        return "Backlog vazio"
    }

    private func setShowAllBacklog(_ id: String, _ value: Bool) {
        if value { state.expandedBacklog.insert(id) } else { state.expandedBacklog.remove(id) }
    }

    /// With an active sprint on show, the tasks that are not in it go to their own card.
    private var splitsOutOfSprint: Bool { showSprint && jiraStore.sprint != nil }
    private var outOfSprintTasks: [JiraTask] { splitsOutOfSprint ? jiraStore.tasks.filter { $0.inActiveSprint == false } : [] }

    private var jiraRows: [JiraRow] {
        jiraRows(for: splitsOutOfSprint ? jiraStore.tasks.filter { $0.inActiveSprint != false } : jiraStore.tasks, expanded: state.showAllJira)
    }

    /// Empty with the "Fora da Sprint" setting off (those tasks are then hidden, not moved back into the list).
    private var outOfSprintRows: [JiraRow] {
        let tasks = showOutOfSprint ? outOfSprintTasks : []
        return tasks.isEmpty ? [] : jiraTaskRows(JiraOrder.sorted(tasks), expanded: state.showAllOutOfSprint)
    }

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

    /// Pinned apps that still exist on disk (an uninstalled app just disappears from the row).
    private var shortcuts: [DevShortcut] {
        ShortcutList.decode(shortcutsJSON).filter { FileManager.default.fileExists(atPath: $0.appPath) }
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
        case .pullRequests: return !prRows(for: .authored).isEmpty || !prRows(for: .review).isEmpty || !prRows(for: .outOfSprint).isEmpty
        case .jira: return !jiraRows.isEmpty || !outOfSprintRows.isEmpty || !approvalRows.isEmpty || (showSprint && jiraStore.sprint != nil)
        case .backlog: return showBacklog && jiraStore.status != .disabled
        case .focus: return showFocus
        case .history: return showHistory
        case .music: return true   // shown disabled when nothing is playing
        case .alerts: return showAlertsBlock && !recentAlerts.isEmpty
        case .briefing: return briefingActive
        case .timeline: return showTimeline
        }
    }

    private func height(of block: IslandBlock) -> CGFloat {
        func section(_ rows: Int) -> CGFloat { rows == 0 ? 0 : IslandLayout.cardListHeader + 2 + CGFloat(rows) * IslandLayout.prRowHeight }
        let (authored, review) = (prRows(for: .authored).count, prRows(for: .review).count)
        switch block {
        case .claude:
            let core = gaugeIsRing ? IslandLayout.claudeRingHeight
                : IslandLayout.claudeHeight + (ClaudeBlock.showsForecast(store, enabled: showForecast) ? IslandLayout.forecastExtra : 0)
            return core + (showCost ? IslandLayout.costExtra : 0)
        case .pullRequests:
            let parts = [section(authored), section(review), section(prRows(for: .outOfSprint).count)].filter { $0 > 0 }
            return IslandLayout.card(IslandLayout.cardTitle + parts.reduce(0, +) + CGFloat(max(parts.count - 1, 0)) * IslandLayout.listRule)
        case .jira:
            let parts = [section(jiraRows.count), section(outOfSprintRows.count), section(approvalRows.count)].filter { $0 > 0 }
            return IslandLayout.card(IslandLayout.cardTitle + parts.reduce(0, +) + CGFloat(max(parts.count - 1, 0)) * IslandLayout.listRule)
        case .backlog: return IslandLayout.card(BacklogBlock.contentHeight(groups: backlogGroups, message: backlogMessage, truncated: jiraStore.backlogTruncated))
        case .focus: return IslandLayout.card(IslandLayout.focusContent)
        case .history: return IslandLayout.card(IslandLayout.historyContent)
        case .music: return IslandLayout.card(musicStore.nowPlaying.map(MusicBlock.contentHeight) ?? IslandLayout.musicContent)
        case .alerts: return IslandLayout.card(AlertsBlock.contentHeight(rows: min(recentAlerts.count, AlertsBlock.maxRows)))
        case .briefing: return IslandLayout.card(BriefingBlock.contentHeight(rows: min(briefingEntries.count, BriefingBlock.maxRows)))
        case .timeline: return IslandLayout.card(TimelineBlock.contentHeight)
        }
    }

    private var visibleColumns: [[IslandBlock]] { layout.columns.map { $0.filter(isVisible) } }

    private func naturalHeight(of column: [IslandBlock]) -> CGFloat {
        var total: CGFloat = 0
        for block in column { total += height(of: block) }
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
        let rows = peekItems.reduce(0) { $0 + ($1.kind == .splash ? IslandLayout.splashRowHeight : IslandLayout.peekRowHeight) }
        return metrics.height + 6 + max(rows, IslandLayout.peekRowHeight) + 10
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
                .scaleEffect(reduceMotion ? 1 : 0.92 + 0.08 * peekContent, anchor: .top)
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
            .opacity(state.expanded ? 0 : peekOpacity)
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

    @ViewBuilder private func peekRow(_ change: PRChange) -> some View {
        if change.kind == .splash { splashRow } else { alertRow(change) }
    }

    /// The Doutor Finanças logo, centred, for the launch splash.
    @ViewBuilder private var splashRow: some View {
        if let logo = Brand.logo {
            Image(nsImage: logo).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                .frame(height: 28)
                .frame(maxWidth: .infinity)
                .frame(height: IslandLayout.splashRowHeight)
        }
    }

    private func alertRow(_ change: PRChange) -> some View {
        HStack(spacing: 6) {
            Circle().fill(change.tone.color).frame(width: 7, height: 7).frame(width: 14)
            Text(change.kind.origin).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.55))
            Text(change.ref).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            Text(change.title).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            RowTag(change.label, change.tone.color)
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
        flashAlert(times: 2)
    }

    /// Quick flashes, each starting once the previous one has faded.
    private func flashAlert(times: Int, after delay: Double = 0) {
        guard times > 0 else { return }
        withAnimation(.easeOut(duration: 0.18).delay(delay)) { alertOpacity = 1 } completion: {
            withAnimation(.easeIn(duration: 0.55).delay(0.02)) { alertOpacity = 0 } completion: {
                flashAlert(times: times - 1, after: 0.1)
            }
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

    /// The thin rule between two parts of a Git / Jira card.
    private func color(forFraction fraction: Double) -> Color {
        Brand.color(forFraction: fraction, amber: amber, red: red)
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
        if reduceMotion {
            // No comet or sparkles: the border only lights up.
            withAnimation(.easeOut(duration: 0.2)) { newSessionFlash = 1 } completion: {
                withAnimation(.easeIn(duration: 0.7)) { newSessionFlash = 0 }
            }
            return
        }
        // On the next turn, so the reset above lands before the lap starts.
        Task {
            withAnimation(.easeInOut(duration: 1.25)) { newSessionLap = 1.3 }
            // The border lights up as the head comes back to where it started.
            try? await Task.sleep(for: .seconds(0.95))
            withAnimation(.easeOut(duration: 0.2)) { newSessionFlash = 1; newSessionSparkle = 1 }
            withAnimation(.easeIn(duration: 0.7).delay(0.2)) { newSessionFlash = 0 }
            withAnimation(.easeIn(duration: 0.6).delay(0.55)) { newSessionSparkle = 0 }
        }
    }

    private func playUpdateAnimation() {
        guard showBorder, !state.expanded else { return }
        // Reset without animation first, otherwise the sweep would start from where the last one ended.
        withTransaction(Transaction(animation: nil)) { sweep = 0; sweepOpacity = reduceMotion ? 0 : 1 }
        if reduceMotion {
            // No sweep along the border: only the glow pulses.
            withAnimation(.easeOut(duration: 0.25)) { glow = 1 } completion: {
                withAnimation(.easeIn(duration: 0.8)) { glow = 0 }
            }
            return
        }
        // On the next turn, so the reset above lands before the sweep starts.
        Task {
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
        if reduceMotion {
            // A short, even resize: no overshoot, no staging, no delay before the content fades in.
            let a = Animation.easeInOut(duration: 0.2)
            return Motion(width: a, height: a, contentDelay: 0)
        }
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

    /// How the open island follows its content growing or shrinking (a section expanded, a block added).
    private var resizeAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45 / speed, dampingFraction: min(openDamping + 0.1, 0.95))
    }

    /// Scale and blur the details start from (and return to) while they fade in or out.
    private var contentFrom: (x: CGFloat, y: CGFloat, blur: CGFloat) {
        if reduceMotion { return (1, 1, 0) }
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
                                funnel: effect == .genie && !reduceMotion, collapsedRadius: notchCornerRadius)
        let hinge = effect == .hinge && !reduceMotion ? -78 * (1 - min(max(heightProgress, 0), 1)) : 0
        return Color.clear
            .frame(width: layoutWidth, height: contentHeight)
            .animation(resizeAnimation, value: contentHeight)
            .animation(resizeAnimation, value: layoutWidth)
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
        .islandTip("Reiniciar o Dr Island")
        .padding(.top, (metrics.height - 24) / 2)
        .scaleEffect(showContent || reduceMotion ? 1 : 0.5)
        .opacity(showContent ? 1 : 0)
        .allowsHitTesting(showContent)
    }

    private var gearButton: some View {
        Button(action: openSettings) {
            Image(systemName: "gearshape").font(.system(size: 13)).foregroundStyle(.secondary)
                .frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .islandTip("Definições")
        .padding(.top, (metrics.height - 24) / 2)
        .padding(.trailing, 20)
        .scaleEffect(showContent || reduceMotion ? 1 : 0.5)
        .opacity(showContent ? 1 : 0)
        .allowsHitTesting(showContent)
    }

    @ViewBuilder private func blockView(_ block: IslandBlock) -> some View {
        switch block {
        case .claude: ClaudeBlock(store: store, costStore: costStore, showCost: showCost)
        case .pullRequests:
            VStack(alignment: .leading, spacing: 0) {
                CardTitle(title: "Git", icon: "arrow.triangle.pull")
                PullRequestSection(list: .authored, rows: prRows(for: .authored), changes: rowChanges) { setShowAll(.authored, $0) }
                if !prRows(for: .authored).isEmpty && !prRows(for: .review).isEmpty { ListRule() }
                PullRequestSection(list: .review, rows: prRows(for: .review), changes: rowChanges) { setShowAll(.review, $0) }
                if !(prRows(for: .authored).isEmpty && prRows(for: .review).isEmpty) && !prRows(for: .outOfSprint).isEmpty { ListRule() }
                PullRequestSection(list: .outOfSprint, rows: prRows(for: .outOfSprint), changes: rowChanges) { setShowAll(.outOfSprint, $0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .blockCard()
        case .jira:
            VStack(alignment: .leading, spacing: 0) {
                CardTitle(title: jiraStore.sprint.flatMap { showSprint ? "Jira - SPRINT - \($0.name)" : nil } ?? "Jira", icon: "checklist",
                          sprint: showSprint ? jiraStore.sprint : nil)
                JiraSection(title: "As minhas tasks", rows: jiraRows, changes: rowChanges, myName: jiraStore.myName) { state.showAllJira = $0 }
                if !jiraRows.isEmpty && !approvalRows.isEmpty { ListRule() }
                JiraSection(title: "Aprovações", rows: approvalRows, changes: rowChanges, myName: jiraStore.myName) { state.showAllApprovals = $0 }
                if !(jiraRows.isEmpty && approvalRows.isEmpty) && !outOfSprintRows.isEmpty { ListRule() }
                JiraSection(title: "Fora da Sprint", rows: outOfSprintRows, changes: rowChanges, myName: jiraStore.myName) { state.showAllOutOfSprint = $0 }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .blockCard()
        case .backlog:
            BacklogBlock(groups: backlogGroups, message: backlogMessage, truncated: jiraStore.backlogTruncated,
                         changes: rowChanges, myName: jiraStore.myName, showAll: setShowAllBacklog)
        case .focus: FocusBlock(store: focusStore)
        case .history: if showHistory { UsageHistoryChart(history: store.history, amber: amber, red: red) }
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
                            ForEach(column, id: \.self) { block in
                                blockView(block)
                            }
                        }
                        .frame(width: columnWidth, alignment: .topLeading)
                    }
                    .frame(width: columnWidth, height: min(naturalHeight(of: column), maxColumnHeight), alignment: .top)
                    .environment(\.islandColumnWidth, columnWidth)
                }
            }
            .frame(height: columnsHeight, alignment: .top)
            if !shortcuts.isEmpty { ShortcutsDock(shortcuts: shortcuts) }
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
