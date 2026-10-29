import AppKit
import SwiftUI
import DrIslandCore

/// Keeps one `IslandInstance` per screen in sync with the connected displays and the settings.
@MainActor
final class IslandController {
    private let store: UsageStore
    private let prStore: PullRequestStore
    private let jiraStore: JiraStore
    private let musicStore: MusicStore
    private let costStore: CostStore
    private let focusStore: FocusStore
    private let openSettings: () -> Void
    private var instances: [CGDirectDisplayID: IslandInstance] = [:]
    private var monitors: [Any] = []
    private var briefingTimer: Timer?

    init(store: UsageStore, prStore: PullRequestStore, jiraStore: JiraStore, musicStore: MusicStore, costStore: CostStore, focusStore: FocusStore, openSettings: @escaping () -> Void) {
        self.store = store
        self.prStore = prStore
        self.jiraStore = jiraStore
        self.musicStore = musicStore
        self.costStore = costStore
        self.focusStore = focusStore
        self.openSettings = openSettings
    }

    func start() {
        sync()
        if let path = ProcessInfo.processInfo.environment["DR_ISLAND_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.instances.values.first?.writeSnapshot(to: path) }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sync()
                // The system keeps settling the display layout (and moving windows) for a moment after the notification.
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(0.6))
                    self?.sync()
                }
            }
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.instances.values.forEach { $0.collapseIfHoverDisabled(); $0.releaseBriefingIfDismissed() }
                self?.sync()
            }
        }
        NotificationCenter.default.addObserver(forName: .islandPreviewEffect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.instances.values.forEach { $0.preview() } }
        }
        NotificationCenter.default.addObserver(forName: .prChangesDetected, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard Settings.alertBanner else { return }
                self?.instances.values.forEach { $0.peek(self?.prStore.lastChanges ?? []) }
            }
        }
        // The morning briefing: checked a little after launch and after a wake (the stores need a moment to catch up), then every 5 min.
        checkBriefing(after: 45)
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkBriefing(after: 60) }
            }
        }
        briefingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.openBriefingIfDue() }
        }
        NotificationCenter.default.addObserver(forName: .islandHotKey, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // The screen under the pointer, so the shortcut opens the island you are looking at.
                let point = NSEvent.mouseLocation
                let target = self.instances.values.first { $0.containsMouse(point) } ?? self.instances.values.first
                target?.toggleFromHotKey()
            }
        }
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                let point = NSEvent.mouseLocation
                self?.instances.values.forEach { $0.mouseMoved(at: point) }
            }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: handler) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { event in handler(event); return event }) { monitors.append(local) }
    }

    /// The stores need a moment to catch up after launch or a wake before the briefing has anything to say.
    private func checkBriefing(after seconds: Double) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            self?.openBriefingIfDue()
        }
    }

    private func openBriefingIfDue() {
        guard Briefing.shouldOpenByItself() else { return }
        let point = NSEvent.mouseLocation
        guard let target = instances.values.first(where: { $0.containsMouse(point) }) ?? instances.values.first else { return }
        let summary = Briefing.summaryText()
        Briefing.openedByItself()
        // The mini island announces it; the full block waits for the next time the island is opened.
        target.peek([PRChange(prID: "briefing", ref: "Resumo", title: summary, kind: .briefing)])
    }

    // MARK: Screens

    /// The notch screen (or the main one), used when "all screens" is off and by the settings preview.
    static func targetScreen() -> NSScreen? {
        if !Settings.targetScreenIsMain, let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) { return notched }
        return NSScreen.screens.first
    }

    /// Detected notch size for `screen`, straight from the system (no per-model table), before user fine-tuning.
    static func detectedMetrics(for screen: NSScreen) -> NotchMetrics {
        NotchGeometry.metrics(
            screenWidth: screen.frame.width,
            safeAreaTop: screen.safeAreaInsets.top,
            auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxRightWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
        )
    }

    static let notchPadding: CGFloat = 0.5
    /// The extra pixel belongs on the left: the widened shape landed on the right only, so the whole notch moves 1 px left.
    static let notchShift: CGFloat = -0.5

    /// Fine-tuning only applies to real notches; the pill on other screens keeps its fixed size.
    private func currentMetrics(for screen: NSScreen) -> NotchMetrics {
        var m = Self.detectedMetrics(for: screen)
        guard m.hasNotch else { return m }
        let defaults = UserDefaults.standard
        // The width from the menu bar areas is one physical pixel (0.5 pt at 2x) short of the black cut-out, which left
        // the border partly hidden behind it; the user's own adjustment comes on top.
        m.width = max(40, m.width + Self.notchPadding + defaults.double(forKey: SettingsKey.notchWidthAdjust))
        m.centerOffset += Self.notchShift
        m.height = max(16, m.height + defaults.double(forKey: SettingsKey.notchHeightAdjust))
        return m
    }

    private func islandScreens() -> [NSScreen] {
        guard Settings.showIsland else { return [] }
        if Settings.showOnAllScreens {
            let off = Settings.disabledScreens
            return NSScreen.screens.filter { !off.contains($0.stableID) }
        }
        return Self.targetScreen().map { [$0] } ?? []
    }

    private func sync() {
        var seen = Set<CGDirectDisplayID>()
        for screen in islandScreens() {
            guard let id = screen.displayID else { continue }
            seen.insert(id)
            let instance = instances[id] ?? IslandInstance(store: store, prStore: prStore, jiraStore: jiraStore, musicStore: musicStore, costStore: costStore, focusStore: focusStore, openSettings: openSettings)
            instances[id] = instance
            instance.update(screen: screen, metrics: currentMetrics(for: screen))
        }
        for (id, instance) in instances where !seen.contains(id) {
            instance.close()
            instances[id] = nil
        }
    }
}
