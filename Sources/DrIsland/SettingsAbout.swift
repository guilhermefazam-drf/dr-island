import SwiftUI

/// What the project is, what it reads and where the data goes: the context a new teammate needs.
struct AboutPage: View {
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Dr Island").font(.title2.weight(.semibold))
                        Text("Versão \(version) · Doutor Finanças").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("A central de controlo do dia de trabalho da equipa de desenvolvimento, num «Dynamic Island» no notch do MacBook. Em vez de abrires o Claude, o GitHub e o Jira para ver como vai o dia, passas o rato no notch e vês tudo num sítio, com avisos quando algo muda.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("O que mostra") {
                about("gauge.with.dots.needle.50percent", "Claude", "Uso da sessão (5 h) e da semana, previsão de quando acaba, custo estimado e histórico diário. A borda do notch enche à medida que gastas o limite.")
                about("arrow.triangle.pull", "Pull requests", "Os teus PRs (CI, review, conflitos) e os que estão à espera do teu review, no GitHub.")
                about("checklist", "Jira", "As tasks que te estão atribuídas, com o estado, e as que esperam a tua aprovação.")
                about("music.note", "Música", "O que está a tocar (Spotify, Música, Brave, Safari…) com anterior, play/pausa e seguinte.")
                about("square.grid.2x2", "Atalhos", "As apps de desenvolvimento que escolheres (VS Code, IntelliJ, Claude…), a um clique, opcionalmente abertas num projeto.")
                about("bell.badge", "Avisos", "Quando um PR, uma task ou o limite do Claude muda, escolhes como saber: pulso na borda, ponto, mini ilha, notificação ou som.")
            }
            Section("Como funciona") {
                bullet("Claude: lê o token do Claude Code no Keychain e consulta o endpoint de uso da Anthropic (não documentado, pode mudar). Se a API limitar os pedidos, estima a partir dos logs locais do Claude Code.")
                bullet("Custo: calculado nos logs locais em ~/.claude/projects, com os preços que definires (equivalente à API).")
                bullet("GitHub: através do `gh`, já autenticado no teu Mac. A app não guarda nenhum token do GitHub.")
                bullet("Jira: API da Atlassian com um API token teu, guardado no Keychain.")
                bullet("Música: AppleScript para o Spotify e a Música; o resto vem do «Em reprodução» do sistema, lido por um pequeno helper.")
                bullet("Avisos: a app guarda uma cópia local do último estado dos PRs e das tasks e compara com a leitura seguinte.")
            }
            Section("Privacidade") {
                bullet("Tudo corre no teu Mac. Não há servidor da app nem telemetria.")
                bullet("As únicas ligações são à Anthropic (uso), ao GitHub (via `gh`), ao teu site do Jira e às capas de álbum do Spotify.")
                bullet("Os tokens nunca são registados. O token do Jira fica no Keychain; as restantes definições, nas preferências da app.")
            }
            Section("Feito com") {
                Text("Swift e SwiftUI, sem dependências externas, e desenvolvido com o Claude. O código está em Sources/DrIsland (a app) e Sources/DrIslandCore (a lógica, com testes).")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private func about(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(.init(text)).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}
