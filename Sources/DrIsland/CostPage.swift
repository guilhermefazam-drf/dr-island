import SwiftUI
import DrIslandCore

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
