import AppKit
import SwiftUI
import DrIslandCore

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
        Task { [weak self] in await self?.playPreview() }
    }

    private func playPreview() async {
        if state.expanded {
            setExpanded(false, reason: "pre-visualizacao")
            try? await Task.sleep(for: .seconds(0.9))
        }
        setExpanded(true, reason: "pre-visualizacao")
        panel?.ignoresMouseEvents = true
        try? await Task.sleep(for: .seconds(1.8))
        previewing = false
        setExpanded(false, reason: "pre-visualizacao")
        try? await Task.sleep(for: .seconds(1))
        state.isPreview = false
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
                    self.state.showAllOutOfSprint = false
                    self.state.showAllPROutOfSprint = false
                }
            }
        }
    }
}
