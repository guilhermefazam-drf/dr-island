import SwiftUI
import DrIslandCore

// MARK: - Atalhos

struct ShortcutsPage: View {
    @AppStorage(SettingsKey.shortcuts) private var json = "[]"

    private var list: [DevShortcut] { ShortcutList.decode(json) }
    private func save(_ list: [DevShortcut]) { json = ShortcutList.encode(list) }

    var body: some View {
        Form {
            Section {
                if list.isEmpty {
                    Text("Ainda não adicionaste nenhum atalho.").foregroundStyle(.secondary)
                }
                ForEach(list) { shortcut in row(shortcut) }
                    .onMove { from, to in var l = list; l.move(fromOffsets: from, toOffset: to); save(l) }
                Button("Adicionar app…") { addApp() }
            } header: {
                Text("Atalhos na ilha")
            } footer: {
                Text("Um clique abre a app, ou passa-a para a frente se já estiver aberta. Com uma pasta definida, a app abre nessa pasta (por exemplo, um projeto no VS Code). Arrasta para mudar a ordem.")
            }
            let suggestions = ShortcutList.availableSuggestions(pinned: list) { FileManager.default.fileExists(atPath: $0) }
            if !suggestions.isEmpty {
                Section("Sugestões instaladas") {
                    ForEach(suggestions, id: \.self) { path in
                        HStack {
                            Image(nsImage: AppIcons.icon(forFile: path)).resizable().interpolation(.high).frame(width: 22, height: 22)
                            Text(DevShortcut(appPath: path).name)
                            Spacer()
                            Button("Adicionar") { save(ShortcutList.adding(DevShortcut(appPath: path), to: list)) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ shortcut: DevShortcut) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: AppIcons.icon(forFile: shortcut.appPath)).resizable().interpolation(.high).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(shortcut.name)
                Text(shortcut.folder ?? "Sem pasta").font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Menu {
                Button(shortcut.folder == nil ? "Escolher pasta…" : "Mudar pasta…") { chooseFolder(for: shortcut) }
                if shortcut.folder != nil {
                    Button("Tirar a pasta") { save(ShortcutList.setting(folder: nil, for: shortcut.id, in: list)) }
                }
                Divider()
                Button("Remover", role: .destructive) { save(ShortcutList.removing(id: shortcut.id, from: list)) }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).fixedSize()
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.message = "Escolhe as apps a adicionar à ilha"
        guard panel.runModal() == .OK else { return }
        save(panel.urls.reduce(list) { ShortcutList.adding(DevShortcut(appPath: $1.path), to: $0) })
    }

    private func chooseFolder(for shortcut: DevShortcut) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "Pasta que \(shortcut.name) deve abrir"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        save(ShortcutList.setting(folder: url.path, for: shortcut.id, in: list))
    }
}

// MARK: - Avisos (como)

struct AlertsPage: View {
    @AppStorage(SettingsKey.alertPulse) private var pulse = true
    @AppStorage(SettingsKey.alertDot) private var dot = true
    @AppStorage(SettingsKey.alertRow) private var row = true
    @AppStorage(SettingsKey.alertBanner) private var banner = false
    @AppStorage(SettingsKey.alertConfetti) private var confetti = true
    @AppStorage(SettingsKey.alertNotification) private var notification = false
    @AppStorage(SettingsKey.alertSound) private var sound = false
    @AppStorage(SettingsKey.quietEnabled) private var quietEnabled = false
    @AppStorage(SettingsKey.quietStart) private var quietStart = 22 * 60
    @AppStorage(SettingsKey.quietEnd) private var quietEnd = 8 * 60
    @AppStorage(SettingsKey.quietFocus) private var quietFocus = true
    @AppStorage(SettingsKey.quietMuted) private var muted = false

    var body: some View {
        Form {
            Section {
                ToggleRow("Pulso na borda", detail: "A borda pisca duas vezes na cor da alteração: vermelho = falhou, laranja = atenção, azul = novidade, verde = bom.", isOn: $pulse)
                ToggleRow("Ponto de novidade", detail: "Um ponto ao lado do notch até abrires a ilha e a fechares.", isOn: $dot)
                ToggleRow("Destacar a linha", detail: "O item que mudou fica com fundo colorido e uma etiqueta («CI falhou», «novo review»…).", isOn: $row)
                ToggleRow("Mini ilha", detail: "Desce do notch uns segundos, só com o que mudou. Se estiver ligada, o pulso desenha-se na borda dela.", isOn: $banner)
                ToggleRow("Confetti", detail: "Uma festa sobre a mini ilha quando um PR é aprovado ou merged. Só aparece com a mini ilha ligada.", isOn: $confetti)
                ToggleRow("Notificação do macOS", detail: "Pede permissão na primeira vez.", isOn: $notification)
                ToggleRow("Som", detail: "Um som curto, diferente para falhas, sucessos e novidades.", isOn: $sound)
            } header: {
                Text("Como avisar")
            } footer: {
                Text("Podes ativar vários ao mesmo tempo. O que conta como alteração escolhe-se em «O que avisar».")
            }
            Section {
                Button("Testar avisos") { NotificationCenter.default.post(name: .prAlertTest, object: nil) }
                Button("Testar confetti") { NotificationCenter.default.post(name: .prConfettiTest, object: nil) }
            }
            Section {
                ToggleRow("Silenciar agora", detail: "Desliga o som e as notificações até o desmarcares (também no menu da barra). O resto dos avisos continua.", isOn: $muted)
                ToggleRow("Horário silencioso", detail: "Sem som nem notificações dentro deste horário.", isOn: $quietEnabled)
                if quietEnabled {
                    DatePicker("Das", selection: minutes($quietStart), displayedComponents: .hourAndMinute)
                    DatePicker("Às", selection: minutes($quietEnd), displayedComponents: .hourAndMinute)
                }
                ToggleRow("Respeitar o Focus do macOS", detail: "Sem som enquanto um Focus estiver ligado. O macOS só deixa ler isto se a app tiver «Acesso total ao disco»; as notificações do sistema já respeitam o Focus.", isOn: $quietFocus)
            } header: { Text("Não incomodar") }
        }
        .formStyle(.grouped)
        .onChange(of: notification) { _, on in if on { PRAlerts.requestNotificationPermission() } }
    }

    /// Minutes since midnight <-> the `Date` a time picker needs.
    private func minutes(_ binding: Binding<Int>) -> Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: binding.wrappedValue / 60, minute: binding.wrappedValue % 60, second: 0, of: Date()) ?? Date() },
                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); binding.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0) })
    }
}

// MARK: - Avisos (o quê)

struct EventsPage: View {
    @AppStorage(SettingsKey.alertComments) private var comments = true
    @AppStorage(SettingsKey.alertMerged) private var merged = true
    @AppStorage(SettingsKey.alertOnClose) private var onClose = false
    @AppStorage(SettingsKey.alertJira) private var jira = true
    @AppStorage(SettingsKey.prMutes) private var mutesJSON = "[]"

    var body: some View {
        Form {
            Section {
                ToggleRow("Novos comentários e menções", detail: "Nos teus PRs, e em PRs de outros onde és mencionado.", isOn: $comments)
                ToggleRow("PR teu com merge", isOn: $merged)
                ToggleRow("PRs que saem da lista", detail: "Fechados sem merge, ou um review pedido que desaparece.", isOn: $onClose)
            } header: {
                Text("Pull requests")
            } footer: {
                Text("Review pedido, CI, aprovações, alterações pedidas e conflitos avisam sempre.")
            }
            Section {
                ToggleRow("Tasks novas, mudanças de estado, comentários e mudanças de aprovadores", isOn: $jira)
            } header: { Text("Jira") }
            Section {
                let mutes = PRMutes.active(PRMutes.decode(mutesJSON))
                if mutes.isEmpty {
                    Text("Nenhum. Clica com o botão direito num PR na ilha para o silenciar.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(mutes) { mute in
                    HStack {
                        Image(systemName: mute.key.hasPrefix("repo:") ? "folder" : "arrow.triangle.pull").foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(mute.label)
                            Text(mute.until.map { "até \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "até reativares")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reativar") { mutesJSON = PRMutes.encode(PRMutes.removing(key: mute.key, from: mutes)) }
                    }
                }
            } header: { Text("PRs e repositórios silenciados") }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Foco

struct FocusPage: View {
    @AppStorage(SettingsKey.showFocus) private var showFocus = false
    @AppStorage(SettingsKey.focusMinutes) private var focus = 25
    @AppStorage(SettingsKey.focusShortBreak) private var shortBreak = 5
    @AppStorage(SettingsKey.focusLongBreak) private var longBreak = 15
    @AppStorage(SettingsKey.focusRounds) private var rounds = 4
    @AppStorage(SettingsKey.focusAutoStart) private var autoStart = false

    var body: some View {
        Form {
            Section {
                ToggleRow("Mostrar o temporizador na ilha", detail: "Um bloco com o tempo, uma barra de progresso e os botões de começar, saltar e recomeçar. Com o temporizador a correr, o ícone da barra de menu mostra o tempo que falta.", isOn: $showFocus)
            }
            Section("Durações") {
                Stepper("Foco: \(focus) min", value: $focus, in: 5...120, step: 5)
                Stepper("Pausa curta: \(shortBreak) min", value: $shortBreak, in: 1...30)
                Stepper("Pausa longa: \(longBreak) min", value: $longBreak, in: 5...60, step: 5)
                Stepper("Pausa longa a cada \(rounds) rondas", value: $rounds, in: 2...8)
            }
            Section {
                ToggleRow("Começar a fase seguinte sozinho", detail: "Sem isto, o temporizador pára no fim de cada fase e espera por ti.", isOn: $autoStart)
            } footer: {
                Text("No fim de cada fase avisas-te pelos canais escolhidos em «Avisos» (pulso, mini ilha, som, notificação), respeitando o «Não incomodar».")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Histórico de avisos

struct HistoryPage: View {
    @AppStorage(SettingsKey.alertHistory) private var json = "[]"
    @State private var source: AlertEntry.Source?
    @State private var confirmClear = false

    private var entries: [AlertEntry] {
        AlertLog.decode(json).filter { source == nil || $0.source == source }
    }

    var body: some View {
        Form {
            Section {
                Picker("Mostrar", selection: $source) {
                    Text("Tudo").tag(AlertEntry.Source?.none)
                    ForEach(AlertEntry.Source.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Guarda os avisos dos últimos 30 dias (até 300), mesmo os que chegaram com o som e as notificações desligados ou durante o «Não incomodar».")
            }
            let groups = AlertLog.groupedByDay(entries)
            if groups.isEmpty {
                Section { Text("Ainda não há avisos.").foregroundStyle(.secondary) }
            }
            ForEach(groups, id: \.day) { group in
                Section(dayTitle(group.day)) {
                    ForEach(group.entries) { entry in row(entry) }
                }
            }
            if !AlertLog.decode(json).isEmpty {
                Section {
                    Button("Limpar histórico…", role: .destructive) { confirmClear = true }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Apagar todo o histórico de avisos?", isPresented: $confirmClear) {
            Button("Apagar", role: .destructive) { json = "[]" }
        }
    }

    private func row(_ entry: AlertEntry) -> some View {
        let url = entry.destination
        return HStack(spacing: 10) {
            Circle().fill(entry.tone.color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayMessage)
                Text("\(entry.source.title) · \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let url { Button("Abrir") { NSWorkspace.shared.open(url) } }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Hoje" }
        if Calendar.current.isDateInYesterday(day) { return "Ontem" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
