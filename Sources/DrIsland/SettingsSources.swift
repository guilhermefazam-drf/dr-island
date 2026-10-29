import SwiftUI
import DrIslandCore

// MARK: - Claude

struct ClaudePage: View {
    @AppStorage(SettingsKey.claudeRefreshSeconds) private var refresh = 120.0
    @AppStorage(SettingsKey.amberThreshold) private var amber = 60.0
    @AppStorage(SettingsKey.redThreshold) private var red = 85.0
    @AppStorage(SettingsKey.claudeLocalFallback) private var localFallback = true
    @AppStorage(SettingsKey.claudeManualLimit) private var manualLimit = 0.0
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

// MARK: - Custo

struct CostPage: View {
    let costStore: CostStore
    @AppStorage(SettingsKey.modelPrices) private var pricesJSON = PriceTable.standard.encoded()
    @AppStorage(SettingsKey.costEnabled) private var enabled = true
    @AppStorage(SettingsKey.showCost) private var showInIsland = false

    var body: some View {
        Form {
            Section {
                ToggleRow("Calcular custos", detail: "Lê os logs locais do Claude Code para somar tokens e estimar o custo. Desligado, não lê nada e esta página fica vazia.", isOn: $enabled)
                ToggleRow("Mostrar na ilha", detail: "Uma linha com o consumo de hoje e dos últimos 7 dias.", isOn: $showInIsland).disabled(!enabled)
            }
            if enabled { costDetails }
        }
        .formStyle(.grouped)
        .task { await costStore.refresh() }
        .onChange(of: pricesJSON) { _, _ in Task { await costStore.refresh() } }
        .onChange(of: enabled) { _, _ in Task { await costStore.refresh() } }
    }

    @ViewBuilder private var costDetails: some View {
            Section("Consumo") {
                costRow("Hoje", costStore.snapshot.today)
                costRow("Últimos 7 dias", costStore.snapshot.week)
                costRow("Últimos 14 dias", costStore.snapshot.fortnight)
            }
            let families = ModelFamily.allCases.filter { costStore.snapshot.fortnight.byFamily[$0] != nil }
            if !families.isEmpty {
                Section("Por modelo · 14 dias") {
                    ForEach(families, id: \.self) { family in
                        if let line = costStore.snapshot.fortnight.byFamily[family] {
                            LabeledContent(family.title) {
                                Text("\(UsageCost.compactTokens(line.tokens)) tok · \(UsageCost.dollars(line.cost))").monospacedDigit()
                            }
                        }
                    }
                }
            }
            Section {
                ForEach([ModelFamily.opus, .sonnet, .haiku], id: \.self) { family in priceRow(family) }
                Button("Repor preços") { pricesJSON = PriceTable.standard.encoded() }
            } header: {
                Text("Preços (dólares por milhão de tokens)")
            } footer: {
                Text("O custo é o equivalente à API, calculado a partir dos logs locais do Claude Code. Quem usa subscrição não paga isto: serve como medida de consumo. A escrita em cache conta 1,25× e a leitura 0,1× o preço de entrada. Confirma os preços em anthropic.com/pricing.")
            }
    }

    private func costRow(_ title: String, _ summary: CostSummary) -> some View {
        LabeledContent(title) {
            Text("\(UsageCost.compactTokens(summary.total.tokens)) tok · ≈ \(UsageCost.dollars(summary.total.cost))").monospacedDigit()
        }
    }

    private func priceRow(_ family: ModelFamily) -> some View {
        let table = PriceTable.decode(pricesJSON)
        func binding(_ keyPath: WritableKeyPath<ModelPrice, Double>) -> Binding<Double> {
            Binding(get: { table.price(for: family)[keyPath: keyPath] },
                    set: { var t = PriceTable.decode(pricesJSON); var p = t.price(for: family); p[keyPath: keyPath] = max(0, $0); t.prices[family] = p; pricesJSON = t.encoded() })
        }
        return HStack {
            Text(family.title)
            Spacer()
            Text("entrada").font(.caption).foregroundStyle(.secondary)
            TextField("", value: binding(\.input), format: .number).frame(width: 56).multilineTextAlignment(.trailing)
            Text("saída").font(.caption).foregroundStyle(.secondary)
            TextField("", value: binding(\.output), format: .number).frame(width: 56).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - GitHub

struct GitHubPage: View {
    @AppStorage(SettingsKey.githubEnabled) private var enabled = true
    @AppStorage(SettingsKey.githubGhPath) private var ghPath = ""
    @AppStorage(SettingsKey.githubIncludeReviewRequests) private var includeReviews = true
    @AppStorage(SettingsKey.githubScope) private var scope = ""
    @AppStorage(SettingsKey.githubRefreshSeconds) private var refresh = 120.0
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        Form {
            Section {
                ToggleRow("Mostrar pull requests", isOn: $enabled)
                ToggleRow("Bloco «A rever»", detail: "PRs onde te pediram review.", isOn: $includeReviews)
                    .disabled(!enabled)
            }
            Section("Ligação") {
                TextField("Caminho do gh", text: $ghPath, prompt: Text(GitHubClient.locateGh() ?? "não encontrado"))
                TextField("Filtro", text: $scope, prompt: Text("org ou org/repo, separados por vírgulas (vazio = tudo)"))
                SliderRow(title: "Atualizar a cada", value: "\(Int(refresh)) s", number: $refresh, range: 60...600, step: 30)
                TestRow(title: "Testar ligação", running: testing, result: testResult) { Task { await test() } }
            }
            .disabled(!enabled)
        }
        .formStyle(.grouped)
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            let snap = try await GitHubClient().fetch(Settings.githubOptions)
            testResult = "OK — \(snap.authored.count) meus, \(snap.reviewRequested.count) a pedir review"
        } catch GitHubError.notInstalled {
            testResult = "gh não encontrado. Instala com: brew install gh"
        } catch GitHubError.notAuthenticated {
            testResult = "Sem sessão. Corre no terminal: gh auth login"
        } catch GitHubError.failed(let message) {
            testResult = "Falhou: \(message)"
        } catch {
            testResult = "Falhou: \(error)"
        }
    }
}

// MARK: - Jira

struct JiraPage: View {
    @AppStorage(SettingsKey.jiraEnabled) private var enabled = false
    @AppStorage(SettingsKey.jiraSite) private var site = ""
    @AppStorage(SettingsKey.jiraEmail) private var email = ""
    @AppStorage(SettingsKey.jiraJQL) private var jql = JiraConfig.defaultJQL
    @AppStorage(SettingsKey.jiraApproverEnabled) private var approverEnabled = true
    @AppStorage(SettingsKey.jiraApproverJQL) private var approverJQL = JiraConfig.defaultApproverJQL
    @AppStorage(SettingsKey.jiraMaxTasks) private var maxTasks = 20
    @AppStorage(SettingsKey.showSprint) private var showSprint = true
    @AppStorage(SettingsKey.showOutOfSprint) private var showOutOfSprint = true
    @AppStorage(SettingsKey.jiraRefreshSeconds) private var refresh = 180.0
    @State private var tokenInput = ""
    @State private var hasToken = SecretStore.exists(account: Settings.jiraTokenAccount)
    @State private var tokenMessage: String?
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        Form {
            Section {
                ToggleRow("Mostrar tasks do Jira", isOn: $enabled)
            }
            Section("Conta") {
                TextField("Site", text: $site, prompt: Text("empresa.atlassian.net"))
                TextField("Email", text: $email, prompt: Text("nome@empresa.pt"))
                LabeledContent("API token") {
                    HStack {
                        SecureField("", text: $tokenInput, prompt: Text(hasToken ? "guardado no Keychain" : "cola o token aqui"))
                            .onSubmit(saveToken)
                        Button("Guardar", action: saveToken).disabled(tokenInput.isEmpty)
                        if hasToken { Button("Remover", role: .destructive, action: removeToken) }
                    }
                }
                if let tokenMessage { Text(tokenMessage).font(.caption).foregroundStyle(.secondary) }
                Link("Criar um API token na Atlassian", destination: URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!)
                    .font(.caption)
                TestRow(title: "Testar ligação", running: testing, result: testResult) { Task { await test() } }
            }
            .disabled(!enabled)
            Section("Sprint") {
                ToggleRow("Mostrar a sprint", detail: "No topo do card Jira: nome, datas e uma barra com o tempo decorrido da sprint ativa. Só aparece com o Jira ligado e uma sprint ativa.", isOn: $showSprint)
                ToggleRow("Mostrar «Fora da Sprint»", detail: "No fim dos cards Jira e Git: as tuas tasks e os PRs que não estão na sprint ativa (um PR conta como da sprint quando o título tem a chave de uma task dela, p. ex. TEP-123). Desligado, as tasks fora da sprint não aparecem e os PRs ficam todos juntos. Precisa de «Mostrar a sprint» ligado.", isOn: $showOutOfSprint).disabled(!showSprint)
            }
            .disabled(!enabled)
            Section("Tasks") {
                TextField("JQL", text: $jql, axis: .vertical).lineLimit(2...4)
                Stepper("Máximo de tasks: \(maxTasks)", value: $maxTasks, in: 1...20)
                SliderRow(title: "Atualizar a cada", value: "\(Int(refresh)) s", number: $refresh, range: 60...900, step: 30)
            }
            .disabled(!enabled)
            Section("Aprovações") {
                ToggleRow("Mostrar tasks em que sou approver", detail: "Uma secção no card Jira, com as tasks que esperam a tua aprovação.", isOn: $approverEnabled)
                TextField("JQL", text: $approverJQL, axis: .vertical).lineLimit(2...4)
            }
            .disabled(!enabled)
        }
        .formStyle(.grouped)
    }

    private func saveToken() {
        let value = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        do {
            try SecretStore.write(value, account: Settings.jiraTokenAccount)
            tokenInput = ""
            hasToken = true
            tokenMessage = "Token guardado no Keychain."
            NotificationCenter.default.post(name: .jiraTokenChanged, object: nil)
        } catch {
            tokenMessage = "Não foi possível guardar no Keychain: \(error)"
        }
    }

    private func removeToken() {
        SecretStore.delete(account: Settings.jiraTokenAccount)
        hasToken = false
        tokenMessage = "Token removido."
        NotificationCenter.default.post(name: .jiraTokenChanged, object: nil)
    }

    private func test() async {
        testing = true
        defer { testing = false }
        // Prefer what is typed in the field so the user can test before saving.
        let typed = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored = typed.isEmpty ? await Task.detached { SecretStore.read(account: Settings.jiraTokenAccount) ?? "" }.value : typed
        let config = Settings.jiraConfig(token: stored)
        do {
            let name = try await JiraClient().myself(config)
            testResult = "OK — ligado como \(name)"
        } catch JiraError.notConfigured {
            testResult = "Preenche o site, o email e o token."
        } catch JiraError.invalidSite {
            testResult = "URL inválido (tem de ser https, ex.: empresa.atlassian.net)."
        } catch JiraError.unauthorized {
            testResult = "Email ou token inválidos."
        } catch JiraError.network {
            testResult = "Sem ligação ao Jira."
        } catch {
            testResult = "Falhou: \(error)"
        }
    }
}
