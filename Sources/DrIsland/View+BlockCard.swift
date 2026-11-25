import AppKit
import SwiftUI
import DrIslandCore

/// From this column width a block may spread out (controls to the edge, extra details).
let islandWideColumn: CGFloat = 340

extension View {
    /// A slightly lighter rounded panel behind the secondary blocks, so the island has structure.
    /// `active`: the card of the running sprint, tinted in the brand blue with a thin outline to set it apart.
    func blockCard(active: Bool = false) -> some View {
        modifier(BlockCard(active: active))
    }
}

private struct BlockCard: ViewModifier {
    let active: Bool
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        content
            .padding(CGFloat(metrics.cardPadding))
            .background(shape.fill(active ? Color(palette.accent).opacity(0.14) : Color(palette.surface)))
            .overlay { if active { shape.strokeBorder(Color(palette.accent).opacity(0.35), lineWidth: 1) } }
    }
}
