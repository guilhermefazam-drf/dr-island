import SwiftUI
import DrIslandCore

/// One of Bento's big numbers: the source and its name, the number with its unit, one line of detail and a small
/// gauge. At Compacto only the tile and the number remain, on one line.
struct KPITile: View {
    enum Gauge {
        case none
        case bar(Double, Color)
        /// Proportional segments (e.g. the user's PRs and those to review).
        case stack([(Double, Color)])
        /// Rounds of the focus timer.
        case dots(total: Int, done: Int, Color)
    }

    /// A second, smaller figure on the right of the number (e.g. the Claude week next to the session).
    struct Aside {
        let label: String
        let value: String
        var color: Color?
    }

    struct Model: Identifiable {
        let id: BentoLayout.KPI
        let title: String
        let icon: String
        let source: IslandBlock
        let value: String
        var unit: String?
        var detail: String
        var gauge: Gauge = .none
        var valueColor: Color?
        var aside: Aside?
        var tip: String?
        var action: (() -> Void)?
    }

    let model: Model
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    nonisolated private static let valueSize: CGFloat = 26

    /// The tile's content height (inside the card's padding).
    nonisolated static func contentHeight(_ m: IslandMetrics) -> CGFloat {
        m.rowHasMeta ? CGFloat(m.tile) + 8 + valueSize + 4 + 14 + 8 + 5 : CGFloat(m.tile)
    }

    var body: some View {
        Group {
            if metrics.rowHasMeta { regular } else { compact }
        }
        .frame(height: Self.contentHeight(metrics), alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blockCard()
        .contentShape(Rectangle())
        .onTapGesture { model.action?() }
        .islandTip(model.tip ?? "")
        .accessibilityElement(children: .combine)
    }

    private var regular: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                SourceTile(icon: model.icon, source: model.source)
                Text(model.title).font(.system(size: CGFloat(metrics.metaSize), weight: .semibold))
                    .foregroundStyle(Color(palette.textSecondary)).lineLimit(1)
            }
            .frame(height: CGFloat(metrics.tile))
            Spacer().frame(height: 8)
            HStack(alignment: .bottom, spacing: 8) {
                number(size: Self.valueSize)
                Spacer(minLength: 0)
                if let aside = model.aside {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(aside.label).font(.system(size: CGFloat(metrics.metaSize) - 1, weight: .medium))
                            .foregroundStyle(Color(palette.textSecondary))
                        Text(aside.value).font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(aside.color ?? Color(palette.text))
                    }
                    .lineLimit(1)
                }
            }
            .frame(height: Self.valueSize, alignment: .bottomLeading)
            Spacer().frame(height: 4)
            Text(model.detail).font(.system(size: CGFloat(metrics.metaSize)))
                .foregroundStyle(Color(palette.textSecondary)).lineLimit(1).truncationMode(.tail)
                .frame(height: 14)
            Spacer().frame(height: 8)
            gauge.frame(height: 5)
        }
    }

    private var compact: some View {
        HStack(spacing: 8) {
            SourceTile(icon: model.icon, source: model.source)
            number(size: CGFloat(metrics.titleSize) + 3)
            Spacer(minLength: 0)
            if let aside = model.aside {
                (Text(aside.label.lowercased() + " ").foregroundStyle(Color(palette.textSecondary))
                    + Text(aside.value).fontWeight(.semibold).foregroundStyle(aside.color ?? Color(palette.text)))
                    .font(.system(size: CGFloat(metrics.metaSize)).monospacedDigit())
                    .lineLimit(1)
            }
        }
    }

    private func number(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(model.value)
                .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(model.valueColor ?? Color(palette.text))
                .contentTransition(.numericText())
            if let unit = model.unit {
                Text(unit).font(.system(size: max(size * 0.42, 10), weight: .semibold))
                    .foregroundStyle(Color(palette.textSecondary))
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder private var gauge: some View {
        switch model.gauge {
        case .none:
            Color.clear
        case .bar(let fraction, let color):
            UsageBar(fraction: fraction, color: color, height: 5)
        case .stack(let parts):
            let total = max(parts.reduce(0) { $0 + $1.0 }, 1)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        Capsule().fill(part.1).frame(width: max((geo.size.width - 2 * CGFloat(parts.count - 1)) * part.0 / total, 0))
                    }
                }
            }
        case .dots(let total, let done, let color):
            HStack(spacing: 4) {
                ForEach(0..<max(total, 0), id: \.self) { i in
                    Circle().fill(i < done ? color : Color(palette.text).opacity(0.15)).frame(width: 5, height: 5)
                }
            }
        }
    }
}
