import SwiftUI
import DrIslandCore

/// One row of a PR or task list: state icons, a monospaced key, the title and, at Normal density, a line of details
/// under it; tags and the owner at the right end. `tint` paints the row (an unseen change, a review that needs you).
struct ListRow<Leading: View, Trailing: View>: View {
    let key: String?
    let title: String
    var meta: String?
    var tint: Color?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics
    @Environment(\.listKeyCharacters) private var keyCharacters

    init(key: String?, title: String, meta: String? = nil, tint: Color? = nil,
         @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.key = key
        self.title = title
        self.meta = meta
        self.tint = tint
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            leading
            if let key {
                Text(key)
                    .font(.system(size: CGFloat(metrics.metaSize), weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(palette.textTertiary))
                    .lineLimit(1)
                    .fixedSize()
                    // One width for every key in the card, so the titles start in the same column.
                    .frame(width: keyCharacters.map { max(ListKeyColumn.width(characters: $0, metrics: metrics), 1) }, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: CGFloat(metrics.bodySize)))
                    .foregroundStyle(Color(palette.text))
                    .lineLimit(1).truncationMode(.tail)
                if metrics.rowHasMeta, let meta, !meta.isEmpty {
                    Text(meta)
                        .font(.system(size: CGFloat(metrics.metaSize)))
                        .foregroundStyle(Color(palette.textTertiary))
                        .lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer(minLength: 4)
            trailing
        }
        .frame(height: CGFloat(metrics.rowHeight))
        .background {
            if let tint { RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint).padding(.horizontal, -6) }
        }
        .contentShape(Rectangle())
    }
}
