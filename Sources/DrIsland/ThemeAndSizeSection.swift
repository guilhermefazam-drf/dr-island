import SwiftUI
import DrIslandCore

/// «Aparência» › «Tema e tamanho»: the island's size (Normal / Compacto) and the shortcut that switches it.
struct ThemeAndSizeSection: View {
    @AppStorage(SettingsKey.islandDensity) private var density = IslandDensity.regular.rawValue
    @AppStorage(SettingsKey.densityHotKey) private var densityHotKey = HotKeyOption.off.rawValue
    @AppStorage(SettingsKey.hotKey) private var hotKey = HotKeyOption.default.rawValue

    var body: some View {
        Section("Tema e tamanho") {
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
