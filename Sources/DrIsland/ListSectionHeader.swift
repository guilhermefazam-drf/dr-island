import SwiftUI

/// A list's title over its rows, as used by the PR and Jira cards.
struct ListSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption).foregroundStyle(.secondary)
            .frame(height: IslandLayout.cardListHeader, alignment: .bottom)
            .padding(.bottom, 2)
    }
}
