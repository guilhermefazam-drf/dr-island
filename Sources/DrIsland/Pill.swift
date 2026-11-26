import SwiftUI
import DrIslandCore

/// A small capsule with a state ("CI ok", "In Review", "draft"): a soft fill and the text in the same colour.
struct Pill: View {
    let text: String
    let color: Color
    @Environment(\.islandMetrics) private var metrics

    init(_ text: String, _ color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: CGFloat(metrics.metaSize) - 0.5, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, metrics.rowHasMeta ? 7 : 6)
            .padding(.vertical, metrics.rowHasMeta ? 2 : 1)
            .background(Capsule().fill(color.opacity(0.18)))
    }
}
