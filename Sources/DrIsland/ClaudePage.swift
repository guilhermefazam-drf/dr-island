import SwiftUI
import DrIslandCore

struct ClaudePage: View {
    @AppStorage(SettingsKey.claudeRefreshSeconds) private var refresh = 120.0
    @AppStorage(SettingsKey.amberThreshold) private var amber = 60.0
    @AppStorage(SettingsKey.redThreshold) private var red = 85.0
    @AppStorage(SettingsKey.claudeLocalFallback) private var localFallback = true
    @AppStorage(SettingsKey.claudeManualLimit) private var manualLimit = 0.0
    @AppStorage(SettingsKey.workStart) private var workStart = WeeklyPace.defaultWorkStartMinute
    @State private var testing = false
    @State private var testResult: String?
    @AppStorage(SettingsKey.claudeUpdateAnimation) private var updateAnimation = true
    @AppStorage(SettingsKey.claudeNewSessionAnimation) private var newSessionAnimation = true
    @AppStorage(SettingsKey.claudeNewSessionNotice) private var newSessionNotice = true
    @State private var calibrationPercent = ""
    @State private var calibrationResult: String?

    var body: some View {
        Form {
            Section("Leitura") {
                SliderRow(title: "Atualizar a cada", value: "\(Int(refresh)) s", number: $refresh, range: 60...600, step: 30)
                Text("O endpoint de uso limita os pedidos: não é consultado mais de uma vez a cada 20 s, mesmo com «Atualizar agora».")
                    .font(.caption).foregroundStyle(.secondary)
                TestRow(title: "Testar ligação", running: testing, result: testResult) { Task { await test() } }
            }
            Section {
                ToggleRow("Ao atualizar o uso", detail: "Um brilho percorre a borda sempre que chega uma leitura nova do Claude.", isOn: $updateAnimation)
                ToggleRow("Ao começar uma sessão nova", detail: "Um cometa percorre a borda e ela acende-se quando começa uma sessão nova do Claude.", isOn: $newSessionAnimation)
                ToggleRow("Aviso no mini island", detail: "Mostra «Nova sessão» no mini island quando a sessão começa. Não fica no histórico nem conta como aviso por ver.", isOn: $newSessionNotice)
                Button("Testar animação de nova sessão") { NotificationCenter.default.post(name: .newSessionTest, object: nil) }
            } header: {
                Text("Animações da borda")
            } footer: {
                Text("Só se veem com a borda ligada, a ilha fechada e sem uma app em ecrã inteiro. O teste respeita os toggles acima.")
            }
            Section("Cores da barra") {
                SliderRow(title: "Âmbar a partir de", value: "\(Int(amber))%", number: $amber, range: 10...100, step: 5)
                SliderRow(title: "Vermelho a partir de", value: "\(Int(max(red, amber)))%", number: $red, range: 10...100, step: 5)
            }
            Section {
                DatePicker("Começo do dia", selection: minutes($workStart), displayedComponents: .hourAndMinute)
            } header: {
                Text("Horário de trabalho")
            } footer: {
                Text("A barra «Semana» reparte-se pelos 5 dias úteis; o limite de hoje vai sendo libertado ao longo de 8 horas de trabalho a partir desta hora, descontando 1 hora de almoço a meio (das 09:00: 09–13 e 14–18). Antes do início conta só o que já passou; depois do fim, o dia inteiro.")
            }
            Section {
                ToggleRow("Estimar com os logs locais do Claude Code", detail: "Usado enquanto a API limita os pedidos ou está sem ligação. Vem marcado com ≈.", isOn: $localFallback)
                if localFallback {
                    LabeledContent("Limite da sessão (tokens)") {
                        TextField("", value: $manualLimit, format: .number, prompt: Text("0 = automático"))
                            .multilineTextAlignment(.trailing).frame(maxWidth: 140)
                    }
                    HStack {
                        TextField("% real agora", text: $calibrationPercent, prompt: Text("% do /usage")).frame(width: 120)
                        Button("Calibrar") { Task { await calibrate() } }
                            .disabled(Double(calibrationPercent.replacingOccurrences(of: ",", with: ".")) == nil)
                        if let calibrationResult { Text(calibrationResult).font(.caption).foregroundStyle(.secondary) }
                        Spacer(minLength: 0)
                    }
                    Text("Automático: aprende com a última leitura real da API e, sem ela, usa a maior sessão dos últimos 14 dias. Para afinar, escreve a percentagem que vês no /usage do Claude Code e clica em Calibrar.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("Quando a API limita") }
        }
        .formStyle(.grouped)
    }

    private func minutes(_ binding: Binding<Int>) -> Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: binding.wrappedValue / 60, minute: binding.wrappedValue % 60, second: 0, of: Date()) ?? Date() },
                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); binding.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0) })
    }

    /// Sets the 100% reference from the real percentage the user reads in Claude Code's /usage.
    private func calibrate() async {
        guard let percent = Double(calibrationPercent.replacingOccurrences(of: ",", with: ".")) else { return }
        let now = Date()
        let tokens = LocalUsageEstimator.estimate(blocks: await LocalUsageScanner.scan(now: now), now: now).sessionTokens
        if let limit = LocalUsageEstimator.calibratedLimit(realPercent: percent, localTokens: tokens) {
            Settings.usageCalibrationLimit = limit
            manualLimit = 0
            calibrationResult = "Calibrado: 100% ≈ \(Int(limit).formatted()) tokens"
            calibrationPercent = ""
        } else {
            calibrationResult = "Precisa de ≥3% e de atividade nesta sessão."
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            let usage = try await UsageClient().fetch()
            testResult = "OK — sessão a \(Int(((usage.session?.fraction ?? 0) * 100).rounded()))%"
        } catch UsageError.noCredentials {
            testResult = "Sem credenciais: faz login no Claude Code."
        } catch UsageError.unauthorized {
            testResult = "Token expirado: abre o Claude Code para renovar."
        } catch {
            testResult = "Falhou: \(error)"
        }
    }
}
