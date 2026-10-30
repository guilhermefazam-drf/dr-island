import SwiftUI
import Charts
import DrIslandCore

/// The «Gestão» window: pick a board and a sprint, read its burndown. Jira is read-only.
struct ManagementView: View {
    let store: ManagementStore

    var body: some View {
        // `burndown` recomputes on every read (it uses `Date()`): read it once per render.
        let burndown = store.burndown
        let snapshot = store.snapshot
        let boardMismatch = snapshot.map { $0.sprint.boardID != store.selectedBoard } ?? false
        VStack(alignment: .leading, spacing: 12) {
            header
            if let snapshot, let burndown, !boardMismatch {
                Text(snapshot.sprint.name).font(.title3.weight(.semibold))
                summary(burndown)
                if burndown.showsMissingPointsWarning { missingPoints(burndown, total: snapshot.issues.count) }
                if burndown.points.isEmpty || burndown.plannedScope == 0 && burndown.points.allSatisfy({ $0.scope == 0 }) {
                    placeholder("Sem tasks nesta sprint")
                } else {
                    BurndownChart(result: burndown, unit: store.unit)
                }
                if case .error(let message) = store.status { errorLine(message) }
            } else {
                stateBody
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 480, alignment: .topLeading)
        .onAppear(perform: forceTasksWithoutPoints)
        .onChange(of: store.status) { _, _ in forceTasksWithoutPoints() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Picker("Board", selection: Binding(get: { store.selectedBoard ?? -1 }, set: { if $0 >= 0 { store.select(board: $0) } })) {
                if store.selectedBoard == nil { Text("—").tag(-1) }
                ForEach(store.boards) { Text($0.name).tag($0.id) }
            }
            .frame(maxWidth: 260)
            Picker("Sprint", selection: Binding(get: { store.selectedSprint ?? -1 }, set: { if $0 >= 0 { store.select(sprint: $0) } })) {
                if store.selectedSprint == nil { Text("—").tag(-1) }
                ForEach(store.sprints, id: \.id) { Text($0.name).tag($0.id) }
            }
            .frame(maxWidth: 300)
            Picker("Unidade", selection: Binding(get: { store.hasPointsField ? store.unit : .tasks }, set: { store.unit = $0 })) {
                if store.hasPointsField { Text("Pontos").tag(MetricUnit.points) }
                Text("Tasks").tag(MetricUnit.tasks)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
            .disabled(!store.hasPointsField)
            Spacer()
            if store.status == .loading { ProgressView().controlSize(.small); Text("A carregar…").font(.caption).foregroundStyle(.secondary) }
        }
        .labelsHidden()
    }

    // MARK: - Body states

    @ViewBuilder private var stateBody: some View {
        switch store.status {
        case .idle, .loading:
            placeholder("A carregar…")
        case .error(let message):
            placeholder(message)
        case .ok:
            if store.boards.isEmpty { placeholder("Sem boards") }
            else if store.sprints.isEmpty { placeholder("Sem sprints neste board") }
            else { placeholder("A carregar…") }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorLine(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(Brand.amber)
    }

    // MARK: - Summary

    private func summary(_ r: BurndownResult) -> some View {
        HStack(spacing: 16) {
            Text("\(Int((r.doneShare * 100).rounded()))% concluído")
            Text("\(r.flaggedOpen) bloqueadas")
            Text(r.isOverdue ? "fora de prazo" : r.daysLeft == 1 ? "acaba em 1 dia" : "acaba em \(r.daysLeft) dias")
                .foregroundStyle(r.isOverdue ? Brand.red : .primary)
        }
        .font(.callout)
    }

    private func missingPoints(_ r: BurndownResult, total: Int) -> some View {
        let missing = Int((r.missingPointsShare * Double(total)).rounded())
        return HStack {
            Label("\(missing) de \(total) tasks sem pontos", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Brand.amber)
            Button("Ver em tasks") { store.unit = .tasks }
        }
        .font(.caption)
    }

    private func forceTasksWithoutPoints() {
        if store.status != .loading, store.status != .idle, !store.hasPointsField, store.unit != .tasks { store.unit = .tasks }
    }
}

/// Remaining work, ideal line, scope and today's marker.
private struct BurndownChart: View {
    let result: BurndownResult
    let unit: MetricUnit

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let first = result.points.first?.date, last = result.points.last?.date
        Chart {
            ForEach(result.points, id: \.date) { p in
                LineMark(x: .value("Dia", p.date), y: .value("Âmbito", p.scope), series: .value("Série", "Âmbito"))
                    .foregroundStyle(.gray.opacity(0.6)).interpolationMethod(.stepEnd)
                LineMark(x: .value("Dia", p.date), y: .value("Ideal", p.ideal), series: .value("Série", "Ideal"))
                    .foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                LineMark(x: .value("Dia", p.date), y: .value("Por fazer", p.remaining), series: .value("Série", "Por fazer"))
                    .foregroundStyle(Brand.blue).lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Dia", p.date), y: .value("Por fazer", p.remaining)).foregroundStyle(Brand.blue).symbolSize(18)
            }
            if let first, let last, today >= first, today <= last {
                RuleMark(x: .value("Hoje", today)).foregroundStyle(Brand.amber.opacity(0.7))
                    .annotation(position: .top, alignment: .leading) { Text("hoje").font(.caption2).foregroundStyle(Brand.amber) }
            }
        }
        .chartYAxisLabel(unit == .points ? "Pontos" : "Tasks")
        .chartForegroundStyleScale(["Por fazer": Brand.blue, "Ideal": Color.secondary, "Âmbito": Color.gray.opacity(0.6)])
        .chartYScale(domain: .automatic(includesZero: true))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
