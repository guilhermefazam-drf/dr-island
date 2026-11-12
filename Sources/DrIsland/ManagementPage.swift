import SwiftUI

/// The island's second page: the manager's charts for the sprint, the project's bugs and the board's velocity. Jira is read-only.
struct ManagementPage: View {
    let store: ManagementStore
    let columns: Int
    /// The room the cards get; they scroll when they do not fit.
    let gridHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ManagementHeader(store: store)
            ScrollView(.vertical, showsIndicators: false) {
                ManagementCharts(store: store, columns: columns)
            }
            .frame(height: gridHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
