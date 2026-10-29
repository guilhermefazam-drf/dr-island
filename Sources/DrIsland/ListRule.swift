import SwiftUI

/// The thin line between two lists of a card.
struct ListRule: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.vertical, (IslandLayout.listRule - 1) / 2)
    }
}
