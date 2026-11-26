import SwiftUI
import DrIslandCore

/// The four cards of the «Gestão» page: two by two when the island is wide, one under the other when it is narrow.
struct ManagementCharts: View {
    let store: ManagementStore
    let columns: Int
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        let gap = CGFloat(metrics.cardGap)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap, alignment: .top), count: max(columns, 1)), spacing: gap) {
            BurndownCard(store: store)
            FlowCard(store: store)
            BugsCard(side: store.side)
            VelocityCard(store: store)
        }
    }
}
