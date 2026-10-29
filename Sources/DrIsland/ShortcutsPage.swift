import SwiftUI
import DrIslandCore

struct ShortcutsPage: View {
    @AppStorage(SettingsKey.shortcuts) private var json = "[]"

    private var list: [DevShortcut] { ShortcutList.decode(json) }
    private func save(_ list: [DevShortcut]) { json = ShortcutList.encode(list) }

    var body: some View {
        Form {
            Section {
                if list.isEmpty {
                    Text("Ainda não adicionaste nenhum atalho.").foregroundStyle(.secondary)
                }
                ForEach(list) { shortcut in row(shortcut) }
                    .onMove { from, to in var l = list; l.move(fromOffsets: from, toOffset: to); save(l) }
                Button("Adicionar app…") { addApp() }
            } header: {
                Text("Atalhos na ilha")
            } footer: {
                Text("Um clique abre a app, ou passa-a para a frente se já estiver aberta. Com uma pasta definida, a app abre nessa pasta (por exemplo, um projeto no VS Code). Arrasta para mudar a ordem.")
            }
            let suggestions = ShortcutList.availableSuggestions(pinned: list) { FileManager.default.fileExists(atPath: $0) }
            if !suggestions.isEmpty {
                Section("Sugestões instaladas") {
                    ForEach(suggestions, id: \.self) { path in
                        HStack {
                            Image(nsImage: AppIcons.icon(forFile: path)).resizable().interpolation(.high).frame(width: 22, height: 22)
                            Text(DevShortcut(appPath: path).name)
                            Spacer()
                            Button("Adicionar") { save(ShortcutList.adding(DevShortcut(appPath: path), to: list)) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ shortcut: DevShortcut) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: AppIcons.icon(forFile: shortcut.appPath)).resizable().interpolation(.high).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(shortcut.name)
                Text(shortcut.folder ?? "Sem pasta").font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Menu {
                Button(shortcut.folder == nil ? "Escolher pasta…" : "Mudar pasta…") { chooseFolder(for: shortcut) }
                if shortcut.folder != nil {
                    Button("Tirar a pasta") { save(ShortcutList.setting(folder: nil, for: shortcut.id, in: list)) }
                }
                Divider()
                Button("Remover", role: .destructive) { save(ShortcutList.removing(id: shortcut.id, from: list)) }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).fixedSize()
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.message = "Escolhe as apps a adicionar à ilha"
        guard panel.runModal() == .OK else { return }
        save(panel.urls.reduce(list) { ShortcutList.adding(DevShortcut(appPath: $1.path), to: $0) })
    }

    private func chooseFolder(for shortcut: DevShortcut) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "Pasta que \(shortcut.name) deve abrir"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        save(ShortcutList.setting(folder: url.path, for: shortcut.id, in: list))
    }
}
