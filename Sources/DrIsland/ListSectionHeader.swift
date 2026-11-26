import SwiftUI
import DrIslandCore

/// A list's title over its rows, as used by the PR and Jira cards.
struct ListSectionHeader: View {
    let title: String
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        Text(title)
            .font(.caption).foregroundStyle(Color(palette.textSecondary))
            .frame(height: CGFloat(metrics.listHeader), alignment: .bottom)
            .padding(.bottom, 2)
    }
}
