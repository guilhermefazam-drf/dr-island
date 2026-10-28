import AppKit
import SwiftUI
import DrIslandCore

/// Transparent, click-through panel pinned to the top centre of the target screen.
/// It always has the expanded size so the SwiftUI spring animation needs no window resizing;
/// mouse events pass through to the apps below except while the island is expanded.
final class IslandPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        level = .statusBar   // after isFloatingPanel, which resets the level to .floating
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    /// The frame the controller wants; AppKit/SwiftUI must never change it (the island animates inside it).
    var lockedFrame: CGRect?

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(lockedFrame ?? frameRect, display: flag)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // The notch lives inside the menu bar area, which AppKit would otherwise push windows out of.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

extension CGRect {
    func isClose(to other: CGRect, tolerance: CGFloat = 1) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}

extension NSScreen {
    /// Survives reboots and re-plugging, unlike the numeric display id.
    var stableID: String {
        guard let id = displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let str = CFUUIDCreateString(nil, uuid) as String? else { return localizedName }
        return str
    }

    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}

/// One island: its own panel, expansion state and hover logic, bound to a single screen.
@MainActor
final class IslandInstance {
    private let store: UsageStore
    private let prStore: PullRequestStore
    private let jiraStore: JiraStore
    private let musicStore: MusicStore
    private let costStore: CostStore
    private let focusStore: FocusStore
    private let openSettings: () -> Void
    private let state = IslandState()
    private var panel: IslandPanel?
    private(set) var metrics = NotchMetrics(width: 184, height: 32, hasNotch: true)
    private var screenFrame = CGRect.zero
    private var displayID: CGDirectDisplayID?
    private var fullscreenTimer: Timer?
    private var spaceObserver: Any?
    private var collapseWork: DispatchWorkItem?
    /// True while the settings preview holds the island open; hover logic stays out of the way.
    private var previewing = false
    private var peekWork: DispatchWorkItem?
    /// Opened by the global shortcut: stays open until the shortcut is pressed again (or Escape), however the pointer moves.
    private var pinned = false
    private var expandedAt: Date?
    /// The morning briefing opened the island and holds it until it is read, dismissed or 30 s pass.
    private var briefingPinned = false
    private var briefingWork: DispatchWorkItem?

    init(store: UsageStore, prStore: PullRequestStore, jiraStore: JiraStore, musicStore: MusicStore, costStore: CostStore, focusStore: FocusStore, openSettings: @escaping () -> Void) {
        self.store = store
        self.prStore = prStore
        self.jiraStore = jiraStore
        self.musicStore = musicStore
        self.costStore = costStore
        self.focusStore = focusStore
        self.openSettings = openSettings
    }

    /// Panel size: always the maximum, so content height changes never resize the window.
    private var panelSize: CGSize { IslandLayout.panelSize(metrics) }
    /// What is actually visible while expanded (for hover hit-testing).
    private var visibleExpandedSize: CGSize { CGSize(width: state.visibleWidth, height: max(state.visibleHeight, metrics.height)) }

    /// Creates or repositions the panel; does nothing when neither the screen frame nor the metrics changed.
    func update(screen: NSScreen, metrics newMetrics: NotchMetrics) {
        let unchanged = screenFrame == screen.frame && metrics == newMetrics
        // AppKit moves windows itself when a display is unplugged; the panel's real frame has to match too, not just our inputs.
        // AppKit rounds the panel's origin to whole points on some displays (a notch shift of 0.5 pt ends up as 0), so the frame
        // is compared with a tolerance: an exact match rebuilt the whole view on every settings change and cut its animations short.
        if let panel, unchanged, let locked = panel.lockedFrame, panel.frame.isClose(to: locked) { return }
        metrics = newMetrics
        screenFrame = screen.frame
        displayID = screen.displayID
        let frame = NotchGeometry.topCenteredFrame(screenFrame: screen.frame, size: panelSize, centerOffset: metrics.centerOffset)

        let view = IslandView(metrics: metrics, expandedSize: panelSize, state: state, store: store, prStore: prStore, jiraStore: jiraStore, musicStore: musicStore, costStore: costStore, focusStore: focusStore, openSettings: openSettings, screenHeight: screen.frame.height)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        host.frame = CGRect(origin: .zero, size: frame.size)

        if panel == nil { panel = IslandPanel(frame: frame) }
        panel?.contentView = host
        panel?.lockedFrame = frame
        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()
        startFullscreenWatch()
    }

    /// Hides the border and dots while an app is in full screen. The Space change is reported as it starts, but the
    /// system only marks the Space as full screen once the transition ends, so a fast poll (a cheap query) catches that moment.
    private func startFullscreenWatch() {
        refreshFullscreen()
        guard fullscreenTimer == nil else { return }
        fullscreenTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFullscreen() }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFullscreen() }
        }
    }

    private func refreshFullscreen() {
        let now = displayID.map(FullscreenDetector.isFullscreen(displayID:)) ?? false
        if state.fullscreen != now { state.fullscreen = now }
    }

    func close() {
        fullscreenTimer?.invalidate()
        fullscreenTimer = nil
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        cancelCollapse()
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
    }

    /// Development aid: opens the island and writes what the panel renders to a PNG (no screen-recording permission needed).
    func writeSnapshot(to path: String) {
        if ProcessInfo.processInfo.environment["DR_ISLAND_COLLAPSED"] == nil {
            setExpanded(true, reason: "snapshot")
            pinned = true   // the real pointer must not close it before the snapshot
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            MainActor.assumeIsolated {
                guard let view = self?.panel?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
        }
    }

    func containsMouse(_ point: CGPoint) -> Bool { screenFrame.contains(point) }

    func toggleFromHotKey() {
        guard !previewing else { return }
        if state.expanded {
            pinned = false
            setExpanded(false, reason: "atalho")
        } else {
            setExpanded(true, reason: "atalho")
            pinned = true
        }
    }

    /// Opens the island on the day briefing, holds it for a while, then lets it close by itself.
    func showBriefing() {
        guard !previewing, panel != nil else { return }
        setExpanded(true, reason: "briefing")
        pinned = true
        briefingPinned = true
        briefingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.briefingPinned else { return }
                self.briefingPinned = false
                if !self.expandedRect.contains(NSEvent.mouseLocation) { self.pinned = false; self.setExpanded(false, reason: "briefing-fim") }
            }
        }
        briefingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }

    /// Once the briefing is dismissed the island goes back to the usual hover rules.
    func releaseBriefingIfDismissed() {
        guard briefingPinned, !Briefing.isActive else { return }
        briefingPinned = false
        briefingWork?.cancel()
        pinned = false
    }

    func collapseIfHoverDisabled() {
        if !Settings.expandOnHover, state.expanded, !previewing { setExpanded(false, reason: "hover-desligado") }
    }

    /// Plays the current show/hide effect: closes first if open, then opens, holds and closes again.
    func preview() {
        guard !previewing else { return }
        previewing = true
        state.isPreview = true
        panel?.ignoresMouseEvents = true
        let open = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.setExpanded(true, reason: "pre-visualizacao")
                self.panel?.ignoresMouseEvents = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.previewing = false
                        self.setExpanded(false, reason: "pre-visualizacao")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in MainActor.assumeIsolated { self?.state.isPreview = false } }
                    }
                }
            }
        }
        if state.expanded {
            setExpanded(false, reason: "pre-visualizacao")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: open)
        } else {
            open()
        }
    }

    /// Shows a mini island with only what changed for a few seconds. The panel stays click-through and the
    /// full island still opens on hover, which replaces the mini one.
    func peek(_ changes: [PRChange]) {
        guard !previewing, !state.expanded, panel != nil, !changes.isEmpty else { return }
        // Alerts that arrive while the mini island is still up (the GitHub and Jira readings land seconds apart) are added
        // to it: replacing it made the first one vanish before it could be read.
        let incoming = Set(changes.map(\.id))
        state.peek = Array((state.peek.filter { !incoming.contains($0.id) } + changes).suffix(IslandLayout.maxPeekRows))
        peekWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.state.peek = [] } }
        peekWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5 + 0.5 * Double(state.peek.count - 1), execute: work)
    }

    // MARK: Hover

    private var hotRect: CGRect {
        let frame = NotchGeometry.topCenteredFrame(screenFrame: screenFrame, size: CGSize(width: metrics.width + 12, height: metrics.height + 6), centerOffset: metrics.centerOffset)
        return frame.offsetBy(dx: 0, dy: 6)   // extends above the screen edge so the very top row counts
    }

    private var expandedRect: CGRect {
        NotchGeometry.topCenteredFrame(screenFrame: screenFrame, size: visibleExpandedSize, centerOffset: metrics.centerOffset).insetBy(dx: -4, dy: -4)
    }

    func mouseMoved(at point: CGPoint) {
        guard Settings.expandOnHover, !previewing else { return }
        // The panel is always max size, so only catch clicks over the visible island; everywhere else passes through.
        panel?.ignoresMouseEvents = !(state.expanded && expandedRect.contains(point))
        if state.expanded {
            if pinned || expandedRect.contains(point) || hotRect.contains(point) { cancelCollapse() } else { scheduleCollapse() }
        } else if hotRect.contains(point) {
            setExpanded(true, reason: "hover")
        }
    }

    /// One line per open/close in errors.log, so a island that stays open leaves the reason behind.
    private func logTransition(_ expanded: Bool, reason: String) {
        let point = NSEvent.mouseLocation
        var text = "\(expanded ? "abre" : "fecha") motivo=\(reason) rato=(\(Int(point.x)),\(Int(point.y))) pinned=\(pinned) briefingPinned=\(briefingPinned)"
        text += " dentro=\(expandedRect.contains(point)) quente=\(hotRect.contains(point)) fechoAgendado=\(collapseWork != nil)"
        text += " visivel=\(Int(visibleExpandedSize.width))x\(Int(visibleExpandedSize.height))"
        if expanded { expandedAt = Date() } else if let at = expandedAt { text += " aberta=\(String(format: "%.1f", Date().timeIntervalSince(at)))s"; expandedAt = nil }
        ErrorLog.record("Ilha", text)
    }

    private func scheduleCollapse() {
        guard collapseWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.collapseWork = nil
                let point = NSEvent.mouseLocation
                if !self.expandedRect.contains(point), !self.hotRect.contains(point) { self.setExpanded(false, reason: "rato-fora") }
            }
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Settings.collapseDelay, execute: work)
    }

    private func cancelCollapse() {
        collapseWork?.cancel()
        collapseWork = nil
    }

    private func setExpanded(_ expanded: Bool, reason: String) {
        guard state.expanded != expanded else { return }
        logTransition(expanded, reason: reason)
        if !expanded { pinned = false; briefingPinned = false; Briefing.markSeen() }
        cancelCollapse()
        if expanded { peekWork?.cancel(); state.peek = [] }
        state.expanded = expanded
        panel?.ignoresMouseEvents = !expanded
        if !expanded {
            // Let the closing animation finish before the lists fold back to their short form.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, !self.state.expanded else { return }
                    self.state.showAllPRs = false
                    self.state.showAllReviews = false
                    self.state.showAllJira = false
                    self.state.showAllApprovals = false
                }
            }
        }
    }
}

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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { MainActor.assumeIsolated { self?.sync() } }
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
        let check: () -> Void = { [weak self] in MainActor.assumeIsolated { self?.openBriefingIfDue() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: check)
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: check)
            }
        }
        briefingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in check() }
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
