import SwiftUI

/// A clickable "+N mais" / "mostrar menos" row.
struct ListExpander: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(linkBlue)
                .frame(maxWidth: .infinity, minHeight: IslandLayout.prRowHeight, maxHeight: IslandLayout.prRowHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
