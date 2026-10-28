import SwiftUI
import DrIslandCore

/// Where each block of the island goes: the number of columns, a preset, and each block's column and order.
struct LayoutPage: View {
    @AppStorage(SettingsKey.islandLayout) private var json = IslandLayoutConfig.vertical.encoded()

    private var layout: IslandLayoutConfig { IslandLayoutConfig.decode(json) }
    private func save(_ layout: IslandLayoutConfig) { json = layout.encoded() }

    var body: some View {
        Form {
            Section {
                Picker("Colunas", selection: Binding(get: { layout.columnCount }, set: { save(layout.resized(to: $0)) })) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Largura das colunas")
                    Slider(value: Binding(get: { layout.extraColumnWidth }, set: { save(layout.withExtraColumnWidth($0)) }),
                           in: -60...IslandLayoutConfig.maxExtraColumnWidth, step: 5)
                    Text("\(Int(layout.width)) pt").monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                }
                HStack {
                    Button("Vertical") { save(IslandLayoutConfig.vertical.withExtraColumnWidth(layout.extraColumnWidth)) }
                    Button("Duas colunas") { save(IslandLayoutConfig.twoColumns.withExtraColumnWidth(layout.extraColumnWidth)) }
                    Button("Três colunas") { save(IslandLayoutConfig.threeColumns.withExtraColumnWidth(layout.extraColumnWidth)) }
                    Spacer()
                }
            } header: {
                Text("Disposição")
            } footer: {
                Text("A ilha tem sempre colunas do mesmo tamanho, centradas no notch. Por defeito 1 coluna mede 400 pt, 2 medem 660 e 3 medem 870; o seletor acima alarga ou estreita todas as colunas (a largura total aparece à direita). A altura é a da coluna mais alta. Blocos sem conteúdo (sem atalhos) ou desligados em «Conteúdo» não ocupam espaço.")
            }
            ForEach(Array(layout.columns.enumerated()), id: \.offset) { index, column in
                Section(layout.columnCount == 1 ? "Blocos, de cima para baixo" : "Coluna \(index + 1)") {
                    if column.isEmpty {
                        Text("Vazia. Move blocos para aqui com o menu de cada bloco.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(column, id: \.self) { block in row(block, in: column) }
                }
            }
            Section {
                Button("Repor layout vertical") { save(IslandLayoutConfig.vertical.withExtraColumnWidth(layout.extraColumnWidth)) }
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ block: IslandBlock, in column: [IslandBlock]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: block.icon).frame(width: 22).foregroundStyle(.tint)
            Text(block.title)
            Spacer()
            if layout.columnCount > 1 {
                Menu("Mover para") {
                    ForEach(0..<layout.columnCount, id: \.self) { target in
                        Button("Coluna \(target + 1)") { save(layout.moving(block, toColumn: target)) }
                            .disabled(target == layout.column(of: block))
                    }
                }
                .menuStyle(.borderlessButton).fixedSize()
            }
            Button { save(layout.shifting(block, by: -1)) } label: { Image(systemName: "chevron.up") }
                .disabled(column.first == block).buttonStyle(.borderless)
            Button { save(layout.shifting(block, by: 1)) } label: { Image(systemName: "chevron.down") }
                .disabled(column.last == block).buttonStyle(.borderless)
        }
    }
}
