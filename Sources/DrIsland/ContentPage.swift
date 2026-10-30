import ServiceManagement
import SwiftUI
import DrIslandCore

/// What the expanded island shows. Blocks that are empty (no shortcuts, nothing playing) never take space.
struct ContentPage: View {
    @AppStorage(SettingsKey.claudeGauge) private var gauge = "bar"
    @AppStorage(SettingsKey.showWeekly) private var showWeekly = true
    @AppStorage(SettingsKey.showForecast) private var forecast = true
    @AppStorage(SettingsKey.showCost) private var showCost = false
    @AppStorage(SettingsKey.costEnabled) private var costEnabled = true
    @AppStorage(SettingsKey.showHistory) private var showHistory = false
    @AppStorage(SettingsKey.showMusic) private var showMusic = true
    @AppStorage(SettingsKey.showAlertsBlock) private var showAlerts = true
    @AppStorage(SettingsKey.showTimeline) private var showTimeline = true
    @AppStorage(SettingsKey.showSprint) private var showSprint = true
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
                ToggleRow("Sprint", detail: "No topo do card Jira: nome, datas e uma barra com o tempo decorrido da sprint ativa. Só aparece com o Jira ligado e uma sprint ativa.", isOn: $showSprint)
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
