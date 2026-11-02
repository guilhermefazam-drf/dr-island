import SwiftUI
import DrIslandCore

/// The chart, its legend and the summary tags of the bugs card.
struct BugsBody: View {
    let result: BugResult

    var body: some View {
        BugsChart(weeks: result.weeks).frame(height: IslandLayout.managementChart)
        HStack(spacing: 10) {
            ForEach(Self.legend, id: \.title) { item in
                HStack(spacing: 4) {
                    Rectangle().fill(item.color).frame(width: 8, height: 8).clipShape(RoundedRectangle(cornerRadius: 2))
                    Text(item.title).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityHidden(true)
        .frame(height: 14)
        HStack(spacing: 6) {
            RowTag("\(result.openIsCapped ? "\(result.openNow)+" : "\(result.openNow)") abertos", result.openNow > 0 ? Brand.red : .gray)
            RowTag("\(created) criados · \(resolved) resolvidos", .gray)
            if let days = result.medianDaysToResolve {
                RowTag("mediana \(days.formatted(.number.precision(.fractionLength(0...1)))) d", Brand.blue)
            }
            Spacer(minLength: 0)
        }
        .frame(height: IslandLayout.managementSummary)
    }

    private static let legend: [(title: String, color: Color)] = [("Criados", Brand.red), ("Resolvidos", Brand.green)]
    private var created: Int { result.weeks.map(\.created).reduce(0, +) }
    private var resolved: Int { result.weeks.map(\.resolved).reduce(0, +) }
}
