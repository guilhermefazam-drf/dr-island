import SwiftUI

/// The streams of the manager as a row of chips; it slides sideways when there are more than fit.
struct StreamChips: View {
    let store: ManagementStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(store.boards) { board in
                    StreamChip(board: board, isSelected: board.id == store.selectedBoard) { store.select(board: board.id) }
                }
            }
        }
    }
}
