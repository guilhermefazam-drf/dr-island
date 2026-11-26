import SwiftUI
import DrIslandCore

struct HistoryPage: View {
    let sync: HistorySyncStore
    @AppStorage(SettingsKey.alertHistory) private var json = "[]"
    @AppStorage(SettingsKey.historySyncMode) private var modeRaw = HistorySyncMode.gist.rawValue
    @AppStorage(SettingsKey.settingsSyncEnabled) private var settingsSync = true
    @State private var source: AlertEntry.Source?
    @State private var confirmClear = false
    @State private var confirmLocal = false
    @State private var oneDriveFound = !OneDriveBackup.roots().isEmpty

    private var mode: HistorySyncMode { HistorySyncMode(rawValue: modeRaw) ?? .gist }

    /// Choosing "só neste Mac" asks first: it means no backup.
    private var modeBinding: Binding<HistorySyncMode> {
        Binding(get: { mode }, set: { new in
            guard new != mode, new != .oneDrive || oneDriveFound else { return }
            if new == .local { confirmLocal = true } else { modeRaw = new.rawValue; sync.syncNow() }
        })
    }

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
            backupSection
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
            Button("Apagar", role: .destructive) {
                // The clear date travels with the backup, so the other Macs and the backup drop these entries too.
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: SettingsKey.historyClearedAt)
                json = "[]"
                NotificationCenter.default.post(name: .alertHistoryChanged, object: nil)
            }
        } message: {
            Text(mode == .local ? "Não há cópia de segurança: não dá para recuperar." : "Também é apagado da cópia de segurança (\(mode.title)) e dos outros Macs.")
        }
        .confirmationDialog("Guardar o histórico só neste Mac?", isPresented: $confirmLocal) {
            Button("Guardar só neste Mac", role: .destructive) { modeRaw = HistorySyncMode.local.rawValue; sync.syncNow() }
        } message: {
            Text("Os avisos ficam guardados só neste Mac, sem cópia de segurança: se mudares de Mac ou reinstalares a app, perdes o histórico. A cópia que já existe no gist ou no OneDrive não é apagada.")
        }
        .onAppear { oneDriveFound = !OneDriveBackup.roots().isEmpty }
    }

    @ViewBuilder private var backupSection: some View {
        Section {
            Picker("Guardar em", selection: modeBinding) {
                Text(HistorySyncMode.gist.title).tag(HistorySyncMode.gist)
                Text(oneDriveFound ? HistorySyncMode.oneDrive.title : "OneDrive (não encontrado)").tag(HistorySyncMode.oneDrive)
                Text(HistorySyncMode.local.title).tag(HistorySyncMode.local)
            }
            if mode != .local {
                HStack {
                    statusLabel
                    Spacer()
                    if let location = sync.location {
                        Button(mode == .gist ? "Abrir gist" : "Mostrar pasta") { NSWorkspace.shared.open(location) }
                    }
                    Button("Sincronizar agora") { sync.syncNow() }.disabled(sync.status == .syncing)
                }
            }
            if mode == .gist {
                ToggleRow("Guardar também as definições",
                          detail: "Tema, layout, avisos, atalhos, Claude, GitHub e Jira (sem o token, que fica só na Keychain). Não vão o caminho do gh, os ecrãs nem o ajuste do notch. Ganha a alteração mais recente; um Mac que nunca sincronizou adota as do gist.",
                          isOn: $settingsSync)
                    .onChange(of: settingsSync) { _, on in if on { sync.syncNow() } }
                if settingsSync { settingsStatusLabel }
            }
        } header: {
            Text("Cópia de segurança")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        switch mode {
        case .gist:
            return "Um gist secreto na tua conta do GitHub, através do gh. Secreto quer dizer não listado: não aparece no teu perfil nem em pesquisas, mas quem tiver o link consegue abri-lo. Os outros Macs com a mesma conta juntam-se ao mesmo histórico."
        case .oneDrive:
            return "Um ficheiro por Mac na pasta «\(OneDriveBackup.folderName)» do teu OneDrive, sincronizada pela app da Microsoft. Os outros Macs com o mesmo OneDrive juntam-se ao mesmo histórico."
        case .local:
            return "Sem cópia de segurança: o histórico fica só neste Mac."
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch sync.status {
        case .idle, .off: Text("Ainda não sincronizado").foregroundStyle(.secondary)
        case .syncing: HStack(spacing: 6) { ProgressView().controlSize(.small); Text("A sincronizar…") }.foregroundStyle(.secondary)
        case .ok(let date): Label("Sincronizado às \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle").foregroundStyle(.secondary)
        case .failed(let message):
            Label(message + " O histórico continua guardado neste Mac.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        }
    }

    @ViewBuilder private var settingsStatusLabel: some View {
        switch sync.settingsStatus {
        case .idle, .off: Text("Definições ainda não sincronizadas").font(.caption).foregroundStyle(.secondary)
        case .syncing: Text("A sincronizar as definições…").font(.caption).foregroundStyle(.secondary)
        case .ok(let date):
            Label("Definições sincronizadas às \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.secondary)
        case .failed(let message):
            Label(message + " As definições continuam guardadas neste Mac.", systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.orange)
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
