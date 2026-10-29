import AppKit
import Combine
import SwiftUI
import DrIslandCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = UsageStore()
    private let prStore = PullRequestStore()
    private let jiraStore = JiraStore()
    private let musicStore = MusicStore()
    private let costStore = CostStore()
    private let focusStore = FocusStore()
    private var island: IslandController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var nap: NSObjectProtocol?
    private let hotKey = HotKeyManager()
    private var cancellables = Set<AnyCancellable>()
    private var summaryItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        ErrorLog.install()
        Settings.migrateLegacyDefaults()
        Settings.registerDefaults()
        // The island is a transparent, click-through panel, so macOS may treat the app as hidden and throttle its timers.
        nap = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Atualizar uso do Claude, PRs e Jira")
        setupMainMenu()
        setupStatusItem()
        let island = IslandController(store: store, prStore: prStore, jiraStore: jiraStore, musicStore: musicStore, costStore: costStore, focusStore: focusStore) { [weak self] in self?.openSettings() }
        island.start()
        self.island = island
        NotificationCenter.default.addObserver(forName: .newSessionTest, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.simulateNewSession() }
        }
        NotificationCenter.default.addObserver(forName: .prConfettiTest, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.prStore.simulateAlert(kind: .approved) }
        }
        NotificationCenter.default.addObserver(forName: .prAlertTest, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.prStore.simulateAlert() }
        }
        store.onNewSession = { [weak self] in
            guard let self else { return }
            let defaults = UserDefaults.standard
            guard defaults.bool(forKey: SettingsKey.claudeNewSessionNotice) else { return }
            // The mini island opens right away and the comet laps its outline (the notch ring is hidden while it is up).
            let delay = defaults.bool(forKey: SettingsKey.claudeNewSessionAnimation) ? 0.15 : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated { self.prStore.showTransient([PRChange(prID: "claude-session", ref: "Claude", title: "Nova sessão", kind: .claudeSession)]) }
            }
        }
        jiraStore.onAlert = { [weak self] changes in self?.prStore.register(changes) }
        hotKey.start()
        // Right after launch the network path often flaps while the Mac is still connecting: show the logo instead of
        // "Offline"/"Online" in the mini island. The red border still marks a connection that stays down.
        let launchedAt = Date()
        let isLaunching = { Date().timeIntervalSince(launchedAt) < 15 }
        NetworkMonitor.shared.onReconnect = { [weak self] in
            self?.refresh()
            guard !isLaunching() else { return }
            self?.prStore.showTransient([PRChange(prID: "network", ref: "Rede", title: "Online", kind: .online)])
        }
        NetworkMonitor.shared.onDisconnect = { [weak self] in
            guard !isLaunching() else { return }
            self?.prStore.showTransient([PRChange(prID: "network", ref: "Rede", title: "Offline", kind: .offline)])
        }
        if Brand.logo != nil {
            // Give the panels a moment to be on screen before the mini island opens.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                MainActor.assumeIsolated { self?.prStore.showTransient([PRChange(prID: "splash", ref: "", title: "", kind: .splash)]) }
            }
        }
        if let path = ProcessInfo.processInfo.environment["DR_ISLAND_SNAPSHOT"] {
            // Development aid: also draw the menu bar button (the island snapshot is written by IslandController).
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let button = self?.statusItem?.button, let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds) else { return }
                button.cacheDisplay(in: button.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path + ".menubar.png"))
            }
        }
        store.start()
        prStore.start()
        jiraStore.start()
        musicStore.start()
        costStore.start()
        focusStore.start()
    }

    /// An accessory app has no visible menu bar, but without an Edit menu the standard
    /// ⌘X/⌘C/⌘V/⌘A shortcuts never reach text fields (so pasting the Jira token would fail).
    private func setupMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Sair do Dr Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Editar")
        edit.addItem(withTitle: "Anular", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Refazer", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Colar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Selecionar tudo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "Dr Island")
        let menu = NSMenu()
        // Summary lines (kept current in menuNeedsUpdate): the whole island, for people who run without it.
        for _ in 0..<4 {
            let line = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            line.isEnabled = false
            summaryItems.append(line)
            menu.addItem(line)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Atualizar agora", action: #selector(refresh), keyEquivalent: "r").target = self
        let mute = menu.addItem(withTitle: "Silenciar avisos", action: #selector(toggleMute(_:)), keyEquivalent: "")
        mute.target = self
        mute.tag = Self.muteTag
        menu.delegate = self
        menu.addItem(withTitle: "Acerca do Dr Island", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Histórico de avisos…", action: #selector(openHistory), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Definições…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Registo de erros…", action: #selector(openLog), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reiniciar Dr Island", action: #selector(restart), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair do Dr Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        // The percentage next to the icon follows the usage and the setting.
        observeStatusTitle()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).sink { [weak self] _ in self?.updateStatusTitle() }.store(in: &cancellables)
        updateStatusTitle()
        // While the focus timer runs, the menu bar shows the time left (it needs a tick every second).
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.updateStatusTitle() } }
    }

    /// Redraws the title whenever a store value it reads changes. Observation fires once per registration (before the
    /// change lands), so each round re-registers on the next main-actor turn and reads the new value.
    private func observeStatusTitle() {
        withObservationTracking { updateStatusTitle() } onChange: { [weak self] in
            Task { @MainActor in self?.observeStatusTitle() }
        }
    }

    /// The text next to the menu bar icon: the focus timer while it runs, else the session percentage (if enabled).
    private func updateStatusTitle() {
        if focusStore.timer.isRunning {
            let seconds = Int(focusStore.timer.remaining(now: Date(), focusStore.config).rounded(.up))
            let symbol = focusStore.timer.phase == .focus ? "●" : "☕︎"
            setStatusText("\(symbol) \(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))")
            return
        }
        let show = UserDefaults.standard.bool(forKey: SettingsKey.menuBarText) && store.hasValue
        setStatusText(show ? "\(Int((store.sessionFraction * 100).rounded()))%" : "")
    }

    /// Icon plus text, laid out by the system (variable width, monospaced digits so a ticking timer does not jitter).
    private func setStatusText(_ text: String) {
        guard let button = statusItem?.button, button.title != text else { return }
        button.imagePosition = text.isEmpty ? .imageOnly : .imageLeft
        button.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .baselineOffset: 0,
        ])
    }

    private func refreshSummary() {
        func percent(_ f: Double) -> String { "\(store.isEstimate ? "≈" : "")\(Int((f * 100).rounded()))%" }
        var lines: [String] = []
        if store.hasValue {
            let reset = store.sessionResetsAt.map { " · reinicia em \(RemainingTime.string(until: $0))" } ?? ""
            lines.append("Sessão: \(percent(store.sessionFraction))\(reset)")
            lines.append(store.weeklyFraction.map { "Semana: \(percent($0))" } ?? "Semana: —")
        } else {
            lines += ["Sessão: sem dados", "Semana: —"]
        }
        lines.append(Settings.githubEnabled
            ? "PRs: \(prStore.snapshot.authored.count) meus · \(prStore.snapshot.reviewRequested.count) a rever"
            : "PRs: desligado")
        lines.append(Settings.jiraEnabled ? "Jira: \(jiraStore.tasks.count) tasks" + (Settings.jiraApproverEnabled ? ", \(jiraStore.approvals.count) a aprovar" : "") : "Jira: desligado")
        for (item, text) in zip(summaryItems, lines) { item.title = text }
    }

    private static let muteTag = 101

    /// The checkmark follows the setting, which can also be changed from the settings window.
    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshSummary()
        menu.item(withTag: Self.muteTag)?.state = UserDefaults.standard.bool(forKey: SettingsKey.quietMuted) ? .on : .off
    }

    @objc private func toggleMute(_ item: NSMenuItem) {
        let muted = !UserDefaults.standard.bool(forKey: SettingsKey.quietMuted)
        UserDefaults.standard.set(muted, forKey: SettingsKey.quietMuted)
        item.state = muted ? .on : .off
    }

    @objc private func openHistory() {
        UserDefaults.standard.set(SettingsPage.history.rawValue, forKey: SettingsPage.pendingKey)   // read when the window is created
        openSettings()
        NotificationCenter.default.post(name: .showSettingsPage, object: SettingsPage.history.rawValue)   // and when it already exists
    }

    @objc private func openLog() {
        UserDefaults.standard.set(SettingsPage.log.rawValue, forKey: SettingsPage.pendingKey)
        openSettings()
        NotificationCenter.default.post(name: .showSettingsPage, object: SettingsPage.log.rawValue)
    }

    @objc private func restart() { ErrorLog.relaunch() }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Central de controlo do dia de trabalho no notch: Claude, PRs, Jira, música e atalhos.\nDoutor Finanças"),
        ])
    }

    @objc private func refresh() { store.refreshNow(); prStore.refreshNow(); jiraStore.refreshNow() }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(costStore: costStore)))
            window.title = "Definições do Dr Island"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 780, height: 600))
            window.minSize = NSSize(width: 720, height: 480)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
