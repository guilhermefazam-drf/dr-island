import ServiceManagement
import SwiftUI
import DrIslandCore

struct AppearancePage: View {
    @AppStorage(SettingsKey.showBorder) private var showBorder = true
    @AppStorage(SettingsKey.borderThickness) private var thickness = 3.0
    @AppStorage(SettingsKey.notchWidthAdjust) private var widthAdjust = 0.0
    @AppStorage(SettingsKey.notchHeightAdjust) private var heightAdjust = 0.0
    @AppStorage(SettingsKey.animSpeed) private var animSpeed = Settings.defaultAnimSpeed
    @AppStorage(SettingsKey.animBounce) private var animBounce = Settings.defaultAnimBounce
    @AppStorage(SettingsKey.animCollapseDelay) private var collapseDelay = Settings.defaultCollapseDelay
    @AppStorage(SettingsKey.animEffect) private var effectName = IslandEffect.default.rawValue

    private var detected: String {
        guard let screen = IslandController.targetScreen() else { return "Sem ecrã" }
        let m = IslandController.detectedMetrics(for: screen)
        let size = "\(Int(m.width.rounded()))×\(Int(m.height.rounded())) pt"
        return m.hasNotch ? "\(screen.localizedName): notch \(size)" : "\(screen.localizedName): sem notch (pílula \(size))"
    }

    var body: some View {
        Form {
            Section("Borda") {
                ToggleRow("Borda à volta do notch", detail: "Enche à medida que gastas o limite da sessão.", isOn: $showBorder)
                SliderRow(title: "Espessura", value: "\(Int(thickness)) pt", number: $thickness, range: 1...8, step: 1)
                    .disabled(!showBorder)
            }
            Section {
                Picker("Efeito", selection: $effectName) {
                    ForEach(IslandEffect.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Text(IslandEffect(stored: effectName).summary).font(.caption).foregroundStyle(.secondary)
                SliderRow(title: "Velocidade", value: "\(animSpeed.formatted(.number.precision(.fractionLength(1))))×", number: $animSpeed, range: 0.5...3, step: 0.1)
                SliderRow(title: "Elasticidade", value: "\(Int((animBounce * 100).rounded()))%", number: $animBounce, range: 0...1, step: 0.05)
                SliderRow(title: "Atraso ao fechar", value: "\(collapseDelay.formatted(.number.precision(.fractionLength(2)))) s", number: $collapseDelay, range: 0...1, step: 0.05)
                HStack {
                    Button("Pré-visualizar") { NotificationCenter.default.post(name: .islandPreviewEffect, object: nil) }
                    Button("Repor") {
                        animSpeed = Settings.defaultAnimSpeed
                        animBounce = Settings.defaultAnimBounce
                        collapseDelay = Settings.defaultCollapseDelay
                        effectName = IslandEffect.default.rawValue
                    }
                }
            } header: { Text("Animação de abrir e fechar") }
            Section("Notch") {
                LabeledContent("Detetado", value: detected)
                SliderRow(title: "Ajuste de largura", value: "\(widthAdjust.formatted(.number.precision(.fractionLength(1)))) pt", number: $widthAdjust, range: -20...20, step: 0.5)
                SliderRow(title: "Ajuste de altura", value: "\(heightAdjust.formatted(.number.precision(.fractionLength(1)))) pt", number: $heightAdjust, range: -10...10, step: 0.5)
                Button("Repor medida detetada") { widthAdjust = 0; heightAdjust = 0 }
            }
        }
        .formStyle(.grouped)
        .onChange(of: effectName) { _, _ in
            NotificationCenter.default.post(name: .islandPreviewEffect, object: nil)
        }
    }
}
