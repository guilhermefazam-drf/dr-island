import SwiftUI

/// From this column width a block may spread out (controls to the edge, extra details).
let islandWideColumn: CGFloat = 340

extension View {
    /// Puts the view on an island card (`BlockCardStyle`); `active` tints it with the accent.
    func blockCard(active: Bool = false) -> some View {
        modifier(BlockCardStyle(active: active))
    }
}
