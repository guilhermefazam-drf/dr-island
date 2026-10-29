import SwiftUI
import DrIslandCore

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
