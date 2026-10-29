import SwiftUI
import DrIslandCore

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
