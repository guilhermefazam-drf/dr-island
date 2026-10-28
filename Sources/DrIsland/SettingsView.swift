import ServiceManagement
import SwiftUI
import DrIslandCore

/// The settings window: a sidebar with the pages grouped by what they are about, and the page on the right.
struct SettingsView: View {
    let costStore: CostStore
    @State private var page: SettingsPage = {
        let pending = UserDefaults.standard.string(forKey: SettingsPage.pendingKey).flatMap(SettingsPage.init(rawValue:))
        UserDefaults.standard.removeObject(forKey: SettingsPage.pendingKey)
        return pending ?? .general
    }()

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                ForEach(SettingsPage.Group.allCases) { group in
                    Section(group.title) {
                        ForEach(SettingsPage.allCases.filter { $0.group == group }) { page in
                            Label(page.title, systemImage: page.icon).tag(page)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
            .safeAreaInset(edge: .bottom) {
                Text("Dr Island \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.caption2).foregroundStyle(.tertiary).padding(.vertical, 8)
            }
        } detail: {
            detail.navigationTitle(page.title)
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 480, idealHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .showSettingsPage)) { note in
            if let raw = note.object as? String, let target = SettingsPage(rawValue: raw) { page = target }
        }
    }

    @ViewBuilder private var detail: some View {
        switch page {
        case .general: GeneralPage()
        case .appearance: AppearancePage()
        case .content: ContentPage()
        case .layout: LayoutPage()
        case .claude: ClaudePage()
        case .cost: CostPage(costStore: costStore)
        case .github: GitHubPage()
        case .jira: JiraPage()
        case .shortcuts: ShortcutsPage()
        case .alerts: AlertsPage()
        case .events: EventsPage()
        case .day: DayPage()
        case .history: HistoryPage()
        case .log: LogPage()
        case .focus: FocusPage()
        case .about: AboutPage()
        }
    }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, appearance, content, layout, claude, cost, github, jira, shortcuts, focus, alerts, events, day, history, log, about

    var id: String { rawValue }
    /// UserDefaults key that asks the next settings window to open on a given page.
    static let pendingKey = "settingsPagePending"

    enum Group: String, CaseIterable, Identifiable {
        case island, sources, tools, interaction, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .island: return "Ilha"
            case .sources: return "Fontes"
            case .tools: return "Ferramentas"
            case .interaction: return "Interação"
            case .about: return "Dr Island"
            }
        }
    }

    var group: Group {
        switch self {
        case .general, .appearance, .content, .layout: return .island
        case .claude, .cost, .github, .jira: return .sources
        case .shortcuts, .focus: return .tools
        case .alerts, .events, .day, .history: return .interaction
        case .log: return .about
        case .about: return .about
        }
    }

    var title: String {
        switch self {
        case .general: return "Geral"
        case .appearance: return "Aparência"
        case .content: return "Conteúdo"
        case .layout: return "Layout"
        case .claude: return "Claude"
        case .cost: return "Custo"
        case .github: return "GitHub"
        case .jira: return "Jira"
        case .shortcuts: return "Atalhos"
        case .focus: return "Foco"
        case .alerts: return "Avisos"
        case .events: return "O que avisar"
        case .day: return "Dia"
        case .history: return "Histórico"
        case .log: return "Registo de erros"
        case .about: return "Acerca"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .content: return "rectangle.3.group"
        case .layout: return "rectangle.split.3x1"
        case .claude: return "gauge.with.dots.needle.50percent"
        case .cost: return "dollarsign.circle"
        case .github: return "arrow.triangle.pull"
        case .jira: return "checklist"
        case .shortcuts: return "square.grid.2x2"
        case .focus: return "timer"
        case .alerts: return "bell.badge"
        case .events: return "list.bullet.rectangle"
        case .day: return "chart.xyaxis.line"
        case .history: return "clock.arrow.circlepath"
        case .log: return "exclamationmark.triangle"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Shared rows

/// A switch with its explanation under the title, so every option reads the same way.
struct ToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    init(_ title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title; self.detail = detail; self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}

/// Title and current value on one line, the slider under them.
struct SliderRow: View {
    let title: String
    let value: String
    @Binding var number: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $number, in: range, step: step)
        }
    }
}

/// A "Testar" button with its progress and result; a result starting with "OK" is shown as a success.
struct TestRow: View {
    let title: String
    let running: Bool
    let result: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(title, action: action).disabled(running)
            if running { ProgressView().controlSize(.small) }
            if let result {
                Label(result, systemImage: result.hasPrefix("OK") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(result.hasPrefix("OK") ? Color.green : Color.orange)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Ilha

/// One switch per connected display.
private struct ScreenToggles: View {
    @AppStorage(SettingsKey.disabledScreens) private var disabled = ""
    @State private var screens = NSScreen.screens

    var body: some View {
        ForEach(screens, id: \.stableID) { screen in
            let id = screen.stableID
            ToggleRow(screen.localizedName, detail: screen.safeAreaInsets.top > 0 ? "Com notch" : "Sem notch (pílula)", isOn: Binding(
                get: { !disabled.split(separator: ",").contains(Substring(id)) },
                set: { on in
                    var set = Set(disabled.split(separator: ",").map(String.init))
                    if on { set.remove(id) } else { set.insert(id) }
                    disabled = set.sorted().joined(separator: ",")
                }))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }
}

private struct GeneralPage: View {
    @AppStorage(SettingsKey.showIsland) private var showIsland = true
    @AppStorage(SettingsKey.expandOnHover) private var expandOnHover = true
    @AppStorage(SettingsKey.hotKey) private var hotKey = HotKeyOption.default.rawValue
    @AppStorage(SettingsKey.showOnAllScreens) private var showOnAllScreens = true
    @AppStorage(SettingsKey.targetScreen) private var targetScreen = "notch"
    @AppStorage(SettingsKey.menuBarText) private var menuBarText = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("Ilha") {
                ToggleRow("Mostrar a ilha", detail: "Desliga se preferires usar só a barra de menu (útil em Macs sem notch).", isOn: $showIsland)
                ToggleRow("Abrir ao passar o rato no notch", isOn: $expandOnHover)
                Picker("Atalho de teclado", selection: $hotKey) {
                    ForEach(HotKeyOption.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Text("Abre e fecha a ilha no ecrã onde está o rato.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Ecrãs") {
                ToggleRow("Mostrar em todos os ecrãs", detail: "Os ecrãs sem notch mostram uma pílula.", isOn: $showOnAllScreens)
                if showOnAllScreens { ScreenToggles() }
                Picker("Ecrã da ilha", selection: $targetScreen) {
                    Text("Com notch (automático)").tag("notch")
                    Text("Principal").tag("main")
                }
                .disabled(showOnAllScreens)
            }
            Section("Barra de menu") {
                ToggleRow("Percentagem ao lado do ícone", detail: "Mostra o uso da sessão do Claude na barra de menu. O menu do ícone tem sempre o resumo.", isOn: $menuBarText)
            }
            Section("Sistema") {
                ToggleRow("Abrir no login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            launchError = nil
                        } catch {
                            launchError = "Não foi possível alterar: \(error.localizedDescription)"
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let launchError { Text(launchError).font(.caption).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppearancePage: View {
    @AppStorage(SettingsKey.showBorder) private var showBorder = true
    @AppStorage(SettingsKey.borderThickness) private var thickness = 3.0
    @AppStorage(SettingsKey.notchWidthAdjust) private var widthAdjust = 0.0
    @AppStorage(SettingsKey.notchHeightAdjust) private var heightAdjust = 0.0
    @AppStorage(SettingsKey.animSpeed) private var animSpeed = Settings.defaultAnimSpeed
    @AppStorage(SettingsKey.animBounce) private var animBounce = Settings.defaultAnimBounce
    @AppStorage(SettingsKey.animCollapseDelay) private var collapseDelay = Settings.defaultCollapseDelay
    @AppStorage(SettingsKey.animEffect) private var effectName = IslandEffect.default.rawValue

    private var detected: String {
        guard let screen = IslandController.targetScreen() else { return "Sem ecrã" }
        let m = IslandController.detectedMetrics(for: screen)
        let size = "\(Int(m.width.rounded()))×\(Int(m.height.rounded())) pt"
        return m.hasNotch ? "\(screen.localizedName): notch \(size)" : "\(screen.localizedName): sem notch (pílula \(size))"
    }

    var body: some View {
        Form {
            Section("Borda") {
                ToggleRow("Borda à volta do notch", detail: "Enche à medida que gastas o limite da sessão.", isOn: $showBorder)
                SliderRow(title: "Espessura", value: "\(Int(thickness)) pt", number: $thickness, range: 1...8, step: 1)
                    .disabled(!showBorder)
            }
            Section {
                Picker("Efeito", selection: $effectName) {
                    ForEach(IslandEffect.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Text(IslandEffect(stored: effectName).summary).font(.caption).foregroundStyle(.secondary)
                SliderRow(title: "Velocidade", value: "\(animSpeed.formatted(.number.precision(.fractionLength(1))))×", number: $animSpeed, range: 0.5...3, step: 0.1)
                SliderRow(title: "Elasticidade", value: "\(Int((animBounce * 100).rounded()))%", number: $animBounce, range: 0...1, step: 0.05)
                SliderRow(title: "Atraso ao fechar", value: "\(collapseDelay.formatted(.number.precision(.fractionLength(2)))) s", number: $collapseDelay, range: 0...1, step: 0.05)
                HStack {
                    Button("Pré-visualizar") { NotificationCenter.default.post(name: .islandPreviewEffect, object: nil) }
                    Button("Repor") {
                        animSpeed = Settings.defaultAnimSpeed
                        animBounce = Settings.defaultAnimBounce
                        collapseDelay = Settings.defaultCollapseDelay
                        effectName = IslandEffect.default.rawValue
                    }
                }
            } header: { Text("Animação de abrir e fechar") }
            Section("Notch") {
                LabeledContent("Detetado", value: detected)
                SliderRow(title: "Ajuste de largura", value: "\(widthAdjust.formatted(.number.precision(.fractionLength(1)))) pt", number: $widthAdjust, range: -20...20, step: 0.5)
                SliderRow(title: "Ajuste de altura", value: "\(heightAdjust.formatted(.number.precision(.fractionLength(1)))) pt", number: $heightAdjust, range: -10...10, step: 0.5)
                Button("Repor medida detetada") { widthAdjust = 0; heightAdjust = 0 }
            }
        }
        .formStyle(.grouped)
        .onChange(of: effectName) { _, _ in
            NotificationCenter.default.post(name: .islandPreviewEffect, object: nil)
        }
    }
}

/// What the expanded island shows. Blocks that are empty (no shortcuts, nothing playing) never take space.
private struct ContentPage: View {
    @AppStorage(SettingsKey.claudeGauge) private var gauge = "bar"
    @AppStorage(SettingsKey.showWeekly) private var showWeekly = true
    @AppStorage(SettingsKey.showForecast) private var forecast = true
    @AppStorage(SettingsKey.showCost) private var showCost = false
    @AppStorage(SettingsKey.costEnabled) private var costEnabled = true
    @AppStorage(SettingsKey.showHistory) private var showHistory = false
    @AppStorage(SettingsKey.showMusic) private var showMusic = true
    @AppStorage(SettingsKey.showAlertsBlock) private var showAlerts = true
    @AppStorage(SettingsKey.showTimeline) private var showTimeline = true
    @AppStorage(SettingsKey.showOwner) private var showOwner = true
    @AppStorage(SettingsKey.briefingAuto) private var briefingAuto = true

    var body: some View {
        Form {
            Section("Claude") {
                Picker("Medidor da sessão", selection: $gauge) {
                    Text("Barra").tag("bar")
                    Text("Anel").tag("ring")
                }
                .pickerStyle(.segmented)
                ToggleRow("Limite semanal", isOn: $showWeekly)
                ToggleRow("Previsão de esgotamento", detail: "«Ao ritmo atual, esgota às HH:mm», só quando isso acontece antes de a sessão reiniciar.", isOn: $forecast)
                ToggleRow("Tokens e custo de hoje", detail: costEnabled ? "Uma linha com o consumo de hoje e dos últimos 7 dias." : "Os custos estão desligados na página Custo.", isOn: $showCost).disabled(!costEnabled)
                ToggleRow("Histórico diário", detail: "Gráfico do pico de uso nos últimos 14 dias; os 7 mais antigos, mais claros, são a semana anterior.", isOn: $showHistory)
            }
            Section("Avisos") {
                ToggleRow("Avisos recentes", detail: "Os últimos avisos de PRs e Jira com a hora, na ilha. Só aparece quando há avisos; o histórico completo está na página Histórico.", isOn: $showAlerts)
                ToggleRow("Dono nas linhas", detail: "Uma marca antes de cada PR e task: «eu» nas tuas, as iniciais do autor ou do responsável nas dos outros.", isOn: $showOwner)
                ToggleRow("Linha do tempo", detail: "Um gráfico de linha com os eventos de hoje por hora, com os botões «resumo» e «detalhes» (página Dia). Só mostra o que a ilha já regista (PRs e Jira).", isOn: $showTimeline)
                ToggleRow("Resumo do dia automático", detail: "De manhã, uma vez por dia, a ilha abre sozinha a dizer o que mudou desde a última vez que a viste. Também podes pedi-lo no botão «resumo» da linha do tempo.", isOn: $briefingAuto)
            }
            Section("Extras") {
                ToggleRow("Leitor de música", detail: "O que está a tocar (Spotify, Música, Brave, Safari…) com os botões de controlo. Só aparece quando há uma faixa. Para o Spotify e a Música, o macOS pede permissão de Automação; para controlar o Brave, o Safari e outras apps (pausar, saltar), pede permissão de Acessibilidade na primeira vez que clicares num botão.", isOn: $showMusic)
                Text("Os atalhos de apps escolhem-se na página Atalhos; os PRs e as tasks, nas páginas GitHub e Jira.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
