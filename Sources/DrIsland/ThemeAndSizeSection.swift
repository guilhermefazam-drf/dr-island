import SwiftUI
import DrIslandCore

/// «Aparência» › «Tema e tamanho»: the island's colour theme, its size (Normal / Compacto) and the shortcut that switches it.
struct ThemeAndSizeSection: View {
    @AppStorage(SettingsKey.islandTheme) private var themeName = IslandTheme.grafite.rawValue
    @AppStorage(SettingsKey.islandDensity) private var density = IslandDensity.regular.rawValue
    @AppStorage(SettingsKey.islandStyle) private var style = IslandStyle.camadas.rawValue
    @AppStorage(SettingsKey.densityHotKey) private var densityHotKey = HotKeyOption.off.rawValue
    @AppStorage(SettingsKey.hotKey) private var hotKey = HotKeyOption.default.rawValue

    var body: some View {
        Section("Tema e tamanho") {
            LabeledContent("Tema") {
                HStack(spacing: 12) {
                    ForEach(IslandTheme.allCases, id: \.rawValue) { theme in
                        Button { themeName = theme.rawValue } label: {
                            VStack(spacing: 4) {
                                ThemeThumbnail(theme: theme, selected: IslandTheme(stored: themeName) == theme)
                                Text(theme.title).font(.caption)
                                    .foregroundStyle(IslandTheme(stored: themeName) == theme ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Picker("Estilo", selection: $style) {
                ForEach(IslandStyle.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Text(IslandStyle(stored: style) == .bento
                 ? "Bento: números grandes em cima (Claude, PRs, sprint, foco), as listas por baixo, os avisos numa faixa e a música no dock."
                 : "Camadas: os teus blocos nas colunas que escolheste em «Layout».")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Tamanho", selection: $density) {
                ForEach(IslandDensity.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Text("O Compacto tem cards mais pequenos e linhas de uma só linha.").font(.caption).foregroundStyle(.secondary)
            Picker("Atalho para alternar o tamanho", selection: $densityHotKey) {
                ForEach(HotKeyOption.allCases, id: \.rawValue) { option in
                    Text(option.title).tag(option.rawValue)
                        .selectionDisabled(option != .off && option.rawValue == hotKey)
                }
            }
        }
    }
}
