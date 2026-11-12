import SwiftUI

/// The four cards of the «Gestão» page: two by two when the island is wide, one under the other when it is narrow.
struct ManagementCharts: View {
    let store: ManagementStore
    let columns: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: IslandLayout.managementCardGap, alignment: .top), count: max(columns, 1)),
                  spacing: IslandLayout.managementCardGap) {
            BurndownCard(store: store)
            FlowCard(store: store)
            BugsCard(side: store.side)
            VelocityCard(store: store)
        }
    }
}
