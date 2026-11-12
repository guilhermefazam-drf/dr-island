import SwiftUI

/// What the bars and the line of the velocity chart mean.
struct VelocityLegend: View {
    private static let items: [(title: String, color: Color)] = [("Planeado", Color.gray.opacity(0.6)), ("Concluído", Brand.blue), ("Média", Brand.green)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Self.items, id: \.title) { item in
                HStack(spacing: 4) {
                    Rectangle().fill(item.color).frame(width: 8, height: 8).clipShape(RoundedRectangle(cornerRadius: 2))
                    Text(item.title).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}
