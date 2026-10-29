import AppKit
import SwiftUI
import DrIslandCore

/// The sprint's elapsed time as a thin bar, small enough to sit in a card's title row. The details (dates, %, time
/// left) are in the tooltip, which `tooltip` builds.
struct SprintBar: View {
    let sprint: SprintInfo
    let amber: Color
    let red: Color

    static let width: CGFloat = 72

    private static let dayFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    static func tooltip(_ sprint: SprintInfo, now: Date = Date()) -> String {
        let percent = Int((sprint.progress(now: now) * 100).rounded())
        return """
        \(sprint.name)
        \(dayFormat.string(from: sprint.start)) → \(dayFormat.string(from: sprint.end))
        \(percent)% decorrido · faltam \(SprintInfo.remainingLabel(sprint.remaining(now: now)))
        """
    }

    var body: some View {
        // Minute resolution is enough: nothing here shows seconds.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let progress = sprint.progress(now: context.date)
            let tint = color(sprint.level(now: context.date))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(tint).frame(width: max(Self.width * progress, progress > 0 ? 5 : 0))
            }
            .frame(width: Self.width, height: 6)
            // A 6 pt bar is hard to hover: the hit area (and so the tooltip) is a taller strip around it.
            .frame(width: Self.width + 8, height: IslandLayout.cardTitle - 4)   // as tall as the title row
            .contentShape(Rectangle())
            .islandTip(Self.tooltip(sprint, now: context.date))
        }
    }

    private func color(_ level: SprintInfo.Level) -> Color {
        switch level {
        case .normal: return Brand.blue
        case .warning: return amber
        case .critical: return red
        }
    }
}
