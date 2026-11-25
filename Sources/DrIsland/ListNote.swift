import SwiftUI
import DrIslandCore

/// A row that only says something: "A carregar…", "Sem PRs abertos", "+3 não listados".
struct ListNote: View {
    let text: String
    var small = false
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        Text(text).font(small ? .caption2 : .caption).foregroundStyle(Color(palette.textSecondary))
            .frame(height: CGFloat(metrics.rowHeight), alignment: .leading)
    }
}
