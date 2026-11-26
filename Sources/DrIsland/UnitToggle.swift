import SwiftUI
import DrIslandCore

/// Pontos | Tasks, in the same tabs as the cards. Without a story-points field only «Tasks» can be chosen.
struct UnitToggle: View {
    let store: ManagementStore
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics
    private static let units: [(unit: MetricUnit, title: String)] = [(.points, "Pontos"), (.tasks, "Tasks")]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.units, id: \.unit) { item in
                let isSelected = store.effectiveUnit == item.unit
                Button { store.unit = item.unit } label: {
                    Text(item.title)
                        .font(.system(size: CGFloat(metrics.metaSize), weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(Color(isSelected ? palette.text : palette.textSecondary))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(palette.surface))
                                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(item.unit == .points && !store.hasPointsField)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(palette.surfaceRaised)))
    }
}
