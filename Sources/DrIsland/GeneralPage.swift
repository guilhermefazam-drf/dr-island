import ServiceManagement
import SwiftUI
import DrIslandCore

struct GeneralPage: View {
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
