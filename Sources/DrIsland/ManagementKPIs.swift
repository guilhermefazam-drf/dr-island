import SwiftUI
import DrIslandCore

/// The «Gestão» page's big numbers, in Bento's tiles: done, working days left, pace against the ideal and what is
/// blocked. One row of four on a wide island, a 2 × 2 grid on a narrow one; a dash while the sprint is loading.
struct ManagementKPIs: View {
    let store: ManagementStore
    let columns: Int
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    nonisolated static func height(columns: Int, metrics m: IslandMetrics) -> CGFloat {
        let tile = CGFloat(m.card(Double(KPITile.contentHeight(m))))
        let rows: CGFloat = columns >= 2 ? 1 : 2
        return rows * tile + (rows - 1) * CGFloat(m.cardGap)
    }

    var body: some View {
        let models = self.models
        let perRow = columns >= 2 ? 4 : 2
        let gap = CGFloat(metrics.cardGap)
        VStack(spacing: gap) {
            ForEach(0..<(models.count + perRow - 1) / perRow, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(models[(row * perRow)..<min((row + 1) * perRow, models.count)]) { KPITile(model: $0) }
                }
            }
        }
        .frame(height: Self.height(columns: columns, metrics: metrics))
    }

    private var models: [KPITile.Model] {
        let now = Date()
        let snapshot = store.snapshot.flatMap { $0.sprint.boardID == store.selectedBoard ? $0 : nil }
        let burndown = snapshot.flatMap { _ in store.burndown }
        let sprint = snapshot?.sprint
        let pace = burndown.flatMap {
            SprintPace.compute($0, start: sprint?.start, end: sprint?.end, closed: sprint?.state == "closed", now: now, calendar: .current)
        }
        let flow = snapshot.map { FlowMetrics.compute($0, unit: store.effectiveUnit, now: now) }
        let unit = store.effectiveUnit == .points ? "pts" : "tasks"
        let dash = "—"

        let done = KPITile.Model(
            id: "done", title: "Concluído", icon: "checkmark.circle", source: .sprint,
            value: pace.map { "\(Int(($0.doneShare * 100).rounded()))" } ?? dash, unit: pace == nil ? nil : "%",
            detail: pace.map { "\(Self.format($0.done)) de \(Self.format($0.scope)) \(unit)" } ?? ManagementStateMessage.text(for: store),
            gauge: .bar(pace?.doneShare ?? 0, Color(palette.green)), titleInCompact: true)

        let ended = sprint?.state == "closed" || (sprint?.end.map { Calendar.current.startOfDay(for: now) > Calendar.current.startOfDay(for: $0) } ?? false)
        let left = KPITile.Model(
            id: "left", title: "Faltam", icon: "clock", source: .sprint,
            value: pace.map { "\($0.workdaysLeft)" } ?? dash,
            unit: pace.map { $0.workdaysLeft == 1 ? "dia útil" : "dias úteis" },
            detail: ended ? "sprint terminada" : (sprint?.end.map { "acaba a " + $0.formatted(.dateTime.day().month(.twoDigits)) } ?? dash),
            gauge: .bar(pace?.elapsedShare ?? 0, Color(palette.accent)), titleInCompact: true)

        let behind = pace.map { $0.behind.rounded() } ?? 0
        let paceModel = KPITile.Model(
            id: "pace", title: "Ritmo", icon: "chart.line.uptrend.xyaxis", source: .sprint,
            value: pace == nil ? dash : (behind == 0 ? "em dia" : Self.format(abs(behind))),
            unit: pace == nil || behind == 0 ? nil : "\(unit) \(behind > 0 ? "atrás" : "à frente")",
            detail: pace.map { pace in
                guard let left = pace.forecastLeft else { return "sprint terminada" }
                return left < 0.5 ? "previsão: acaba a tempo" : "previsão: sobram ~\(Self.format(left.rounded())) \(unit)"
            } ?? dash,
            valueColor: pace == nil || behind == 0 ? nil : Color(behind > 0 ? palette.amber : palette.green),
            titleInCompact: true, tip: "Diferença entre o que falta e a linha ideal de hoje")

        let flagged = flow?.flaggedOpen ?? 0
        let firstFlagged = flow?.stuck.first { $0.isFlagged }
        let blocked = KPITile.Model(
            id: "blocked", title: "Bloqueadas", icon: "flag", source: .sprint,
            value: flow == nil ? dash : "\(flagged)",
            detail: firstFlagged.map { "\($0.key) · há \(Int($0.days.rounded())) d" } ?? (flow == nil ? dash : "nenhuma"),
            valueColor: flagged > 0 ? Color(palette.red) : nil, titleInCompact: true)

        return [done, left, paceModel, blocked]
    }

    static func format(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
}
