import SwiftUI
import DrIslandCore

struct JiraPage: View {
    @AppStorage(SettingsKey.jiraEnabled) private var enabled = false
    @AppStorage(SettingsKey.jiraSite) private var site = ""
    @AppStorage(SettingsKey.jiraEmail) private var email = ""
    @AppStorage(SettingsKey.jiraJQL) private var jql = JiraConfig.defaultJQL
    @AppStorage(SettingsKey.jiraApproverEnabled) private var approverEnabled = true
    @AppStorage(SettingsKey.jiraApproverJQL) private var approverJQL = JiraConfig.defaultApproverJQL
    @AppStorage(SettingsKey.jiraMaxTasks) private var maxTasks = 20
    @AppStorage(SettingsKey.showSprint) private var showSprint = true
    @AppStorage(SettingsKey.jiraSprintBoards) private var sprintBoards = ""
    @State private var boards: [JiraBoard] = []
    @State private var boardsMessage: String?
    @State private var loadingBoards = false
    @AppStorage(SettingsKey.jiraRefreshSeconds) private var refresh = 180.0
    @AppStorage(SettingsKey.jiraBacklogEnabled) private var backlogEnabled = true
    @AppStorage(SettingsKey.jiraBacklogProject) private var backlogProject = ""
    @AppStorage(SettingsKey.jiraBacklogJQL) private var backlogJQL = ""
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
                ToggleRow("Mostrar a sprint", detail: "Um card com as sprints ativas: nome, barra de tempo e as tuas tasks até ao fim. Com várias streams, uma secção por sprint.", isOn: $showSprint)
                ForEach(boards) { board in
                    Toggle(board.name, isOn: Binding(
                        get: { BoardParser.parseIDs(sprintBoards).contains(board.id) },
                        set: { on in
                            var ids = BoardParser.parseIDs(sprintBoards)
                            if on { ids.insert(board.id) } else { ids.remove(board.id) }
                            sprintBoards = BoardParser.format(ids)
                        }))
                }
                HStack(spacing: 10) {
                    Button(boards.isEmpty ? "Escolher streams (boards)" : "Atualizar a lista de streams") { Task { await loadBoards() } }.disabled(loadingBoards)
                    if loadingBoards { ProgressView().controlSize(.small) }
                }
                Text(boardsMessage ?? defaultBoardsHint).font(.caption).foregroundStyle(.secondary)
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
            Section("Backlog") {
                ToggleRow("Mostrar o backlog da equipa", detail: "Um card próprio, como a vista Backlog do Jira: uma lista por cada sprint futura e, no fim, as tasks sem sprint. Lê até 100 tasks.", isOn: $backlogEnabled)
                TextField("Projeto", text: $backlogProject, prompt: Text("vazio = o das tuas tasks (ex.: TEP)"))
                TextField("JQL", text: $backlogJQL, prompt: Text("vazio = backlog do projeto"), axis: .vertical).lineLimit(2...4)
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

    private var defaultBoardsHint: String {
        sprintBoards.isEmpty ? "Sem nenhuma escolhida, mostra as sprints ativas das streams onde tens (ou tiveste) tasks."
            : "A mostrar as sprints ativas de \(BoardParser.parseIDs(sprintBoards).count) stream(s)."
    }

    private func loadBoards() async {
        loadingBoards = true
        defer { loadingBoards = false }
        let token = await Task.detached { SecretStore.read(account: Settings.jiraTokenAccount) ?? "" }.value
        do {
            boards = try await JiraClient().fetchBoards(Settings.jiraConfig(token: token))
            boardsMessage = boards.isEmpty ? "Nenhum board scrum encontrado." : nil
        } catch {
            boardsMessage = "Não foi possível ler os boards: \(error)"
        }
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
