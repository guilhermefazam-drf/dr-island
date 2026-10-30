import AppKit
import SwiftUI
import DrIslandCore

/// From this column width a block may spread out (controls to the edge, extra details).
let islandWideColumn: CGFloat = 340

extension View {
    /// A slightly lighter rounded panel behind the secondary blocks, so the island has structure.
    /// `active`: the card of the running sprint, tinted in the brand blue with a thin outline to set it apart.
    func blockCard(active: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return padding(IslandLayout.cardPadding)
            .background(shape.fill(active ? Brand.blue.opacity(0.14) : Color.white.opacity(0.055)))
            .overlay { if active { shape.strokeBorder(Brand.blue.opacity(0.35), lineWidth: 1) } }
    }
}
