import SwiftUI
import DrIslandCore

/// The island's second page: the sprint's numbers on top, then the manager's charts for the sprint, the project's bugs
/// and the board's velocity. Jira is read-only.
struct ManagementPage: View {
    let store: ManagementStore
    let columns: Int
    /// The room the cards get; they scroll when they do not fit.
    let gridHeight: CGFloat
    @Environment(\.islandMetrics) private var metrics

    /// Everything above the cards: the strip, the numbers and the gaps under each.
    nonisolated static func topHeight(columns: Int, metrics m: IslandMetrics) -> CGFloat {
        IslandLayout.managementHeader + CGFloat(m.cardGap) + ManagementKPIs.height(columns: columns, metrics: m) + CGFloat(m.cardGap)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(metrics.cardGap)) {
            ManagementHeader(store: store)
            ManagementKPIs(store: store, columns: columns)
            ScrollView(.vertical, showsIndicators: false) {
                ManagementCharts(store: store, columns: columns)
            }
            .frame(height: gridHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
