import SwiftUI
import DrIslandCore

/// The streams of the manager as tabs; they slide sideways when there are more than fit.
struct StreamChips: View {
    let store: ManagementStore
    @Environment(\.islandPalette) private var palette

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(store.boards) { board in
                    StreamChip(board: board, isSelected: board.id == store.selectedBoard) { store.select(board: board.id) }
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(palette.surfaceRaised)))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
