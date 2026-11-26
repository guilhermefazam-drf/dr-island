import SwiftUI
import DrIslandCore

/// One whole split into its status groups, each block as wide as its share, with its amount inside when it fits.
struct FlowSegmentBar: View {
    let groups: [FlowGroup]
    let height: CGFloat
    @Environment(\.islandPalette) private var palette

    var body: some View {
        let shown = groups.filter { $0.amount > 0 }
        let total = max(shown.map(\.amount).reduce(0, +), 1)
        GeometryReader { geo in
            let room = geo.size.width - 2 * CGFloat(max(shown.count - 1, 0))
            HStack(spacing: 2) {
                ForEach(shown) { group in
                    let width = max(room * group.amount / total, 6)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(group.color(palette))
                        if width >= 24 {
                            Text(ManagementKPIs.format(group.amount))
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(group.ink(palette))
                                .padding(.leading, 7)
                        }
                    }
                    .frame(width: width)
                    .islandTip("\(group.name): \(ManagementKPIs.format(group.amount))")
                }
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(shown.map { "\($0.name) \(ManagementKPIs.format($0.amount))" }.joined(separator: ", "))
    }
}
