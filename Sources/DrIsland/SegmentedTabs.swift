import SwiftUI
import DrIslandCore

/// Small tabs inside a card header ("Meus 3 | A rever 4"). A tab with unseen changes shows a dot in the change's colour.
struct SegmentedTabs: View {
    struct Tab: Identifiable {
        let id: String
        let title: String
        let count: Int
        var badge: Color?
    }

    let tabs: [Tab]
    @Binding var selection: String
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                let selected = tab.id == selection
                Button { selection = tab.id } label: {
                    HStack(spacing: 4) {
                        Text("\(tab.title) \(tab.count)").monospacedDigit()
                        if let badge = tab.badge, !selected { Circle().fill(badge).frame(width: 6, height: 6) }
                    }
                    .font(.system(size: CGFloat(metrics.metaSize), weight: selected ? .semibold : .medium))
                    .foregroundStyle(Color(selected ? palette.text : palette.textSecondary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(palette.surface))
                                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(palette.surfaceRaised)))
    }
}
