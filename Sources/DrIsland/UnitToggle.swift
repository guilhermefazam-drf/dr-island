import SwiftUI
import DrIslandCore

/// Pontos | Tasks. Without a story-points field only «Tasks» can be chosen.
struct UnitToggle: View {
    let store: ManagementStore
    private static let units: [(unit: MetricUnit, title: String)] = [(.points, "Pontos"), (.tasks, "Tasks")]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.units, id: \.unit) { item in
                let isSelected = store.effectiveUnit == item.unit
                Button { store.unit = item.unit } label: {
                    Text(item.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(isSelected ? Brand.blue : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(item.unit == .points && !store.hasPointsField)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }
}
