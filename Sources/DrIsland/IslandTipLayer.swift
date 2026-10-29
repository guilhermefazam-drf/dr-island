import AppKit
import SwiftUI

/// The bubble sits under the hovered view (above it near the bottom) and is kept inside the visible island, so it is
/// never cut at the edges.
struct IslandTipLayer: View {
    let tips: IslandTipCenter
    let state: IslandState
    let expandedSize: CGSize
    @State private var size: CGSize = .zero

    var body: some View {
        if let tip = tips.tip, state.expanded {
            let left = (expandedSize.width - state.visibleWidth) / 2 + 6
            let right = (expandedSize.width + state.visibleWidth) / 2 - 6 - size.width
            let x = min(max(tip.anchor.midX - size.width / 2, left), max(right, left))
            let below = tip.anchor.maxY + 6
            let y = below + size.height > state.visibleHeight - 4 ? max(tip.anchor.minY - size.height - 6, 4) : below
            Color.clear
                .frame(width: expandedSize.width, height: expandedSize.height)
                .overlay(alignment: .topLeading) {
                    Text(tip.text)
                        .font(.caption2).foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(width: Self.textWidth(tip.text), alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(white: 0.17)))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                        .opacity(size == .zero ? 0 : 1)
                        .offset(x: x, y: y)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    /// The bubble is as wide as its longest line (up to 240 pt, then it wraps), so a short tip is a small bubble.
    private static func textWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 10)
        let longest = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return min(ceil(longest) + 4, 224)
    }
}
