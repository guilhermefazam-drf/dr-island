import SwiftUI
import DrIslandCore

struct EventsPage: View {
    @AppStorage(SettingsKey.alertComments) private var comments = true
    @AppStorage(SettingsKey.alertMerged) private var merged = true
    @AppStorage(SettingsKey.alertOnClose) private var onClose = false
    @AppStorage(SettingsKey.alertJira) private var jira = true
    @AppStorage(SettingsKey.prMutes) private var mutesJSON = "[]"

    var body: some View {
        Form {
            Section {
                ToggleRow("Novos comentários e menções", detail: "Nos teus PRs, e em PRs de outros onde és mencionado.", isOn: $comments)
                ToggleRow("PR teu com merge", isOn: $merged)
                ToggleRow("PRs que saem da lista", detail: "Fechados sem merge, ou um review pedido que desaparece.", isOn: $onClose)
            } header: {
                Text("Pull requests")
            } footer: {
                Text("Review pedido, CI, aprovações, alterações pedidas e conflitos avisam sempre.")
            }
            Section {
                ToggleRow("Tasks novas, mudanças de estado, comentários e mudanças de aprovadores", isOn: $jira)
            } header: { Text("Jira") }
            Section {
                let mutes = PRMutes.active(PRMutes.decode(mutesJSON))
                if mutes.isEmpty {
                    Text("Nenhum. Clica com o botão direito num PR na ilha para o silenciar.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(mutes) { mute in
                    HStack {
                        Image(systemName: mute.key.hasPrefix("repo:") ? "folder" : "arrow.triangle.pull").foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(mute.label)
                            Text(mute.until.map { "até \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "até reativares")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reativar") { mutesJSON = PRMutes.encode(PRMutes.removing(key: mute.key, from: mutes)) }
                    }
                }
            } header: { Text("PRs e repositórios silenciados") }
        }
        .formStyle(.grouped)
    }
}
