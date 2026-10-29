import AppKit
import SwiftUI
import DrIslandCore

/// From this column width a block may spread out (controls to the edge, extra details).
let islandWideColumn: CGFloat = 340

extension View {
    /// A slightly lighter rounded panel behind the secondary blocks, so the island has structure.
    func blockCard() -> some View {
        padding(IslandLayout.cardPadding)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.055)))
    }
}
