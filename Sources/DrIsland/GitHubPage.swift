import SwiftUI
import DrIslandCore

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
