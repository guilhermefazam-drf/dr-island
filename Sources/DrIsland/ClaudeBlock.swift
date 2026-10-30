import AppKit
import SwiftUI
import DrIslandCore

struct ClaudeBlock: View {
    @Environment(\.islandColumnWidth) private var columnWidth
    let store: UsageStore
    let costStore: CostStore
    let showCost: Bool
    @AppStorage(SettingsKey.showWeekly) private var showWeekly = true
    @AppStorage(SettingsKey.showForecast) private var showForecast = true
    @AppStorage(SettingsKey.amberThreshold) private var amber = 60.0
    @AppStorage(SettingsKey.redThreshold) private var red = 85.0
    @AppStorage(SettingsKey.workStart) private var workStart = WeeklyPace.defaultWorkStartMinute
    @AppStorage(SettingsKey.claudeGauge) private var gauge = "bar"

    /// Whether the "esgota às" chip is shown (it adds a row, so the island's height depends on it).
    static func showsForecast(_ store: UsageStore, enabled: Bool) -> Bool {
        enabled && !store.isEstimate && store.sessionExhaustsAt != nil
    }

    private func color(_ fraction: Double) -> Color {
        switch UsageLevel.level(forFraction: fraction, amber: amber, red: red) {
        case .normal: return Brand.green
        case .warning: return Brand.amber
        case .critical: return Brand.red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Claude").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                statusChip
            }
            if gauge == "ring" { ringBody } else { barBody }
            if showCost { costTiles }
        }
    }

    /// The session as a ring with the percentage inside; the details sit beside it.
    private var ringBody: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 9)
                Circle().trim(from: 0, to: min(max(store.sessionFraction, 0), 1))
                    .stroke(color(store.sessionFraction), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: store.sessionFraction)
                Text("\(store.isEstimate ? "≈" : "")\(Int((store.sessionFraction * 100).rounded()))%")
                    .font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(color(store.sessionFraction))
                    .contentTransition(.numericText())
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 7) {
                Text("Sessão · 5 h").font(.caption2).foregroundStyle(.secondary)
                resetLabel(store.sessionResetsAt, prefix: "reinicia em")
                if Self.showsForecast(store, enabled: showForecast), let eta = store.sessionExhaustsAt {
                    Label("esgota às \(eta.formatted(date: .omitted, time: .shortened))", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.medium)).foregroundStyle(Brand.amber)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Brand.amber.opacity(0.16)))
                }
                if showWeekly, let weekly = store.weeklyFraction {
                    HStack(spacing: 6) {
                        Text("Semana").font(.caption2).foregroundStyle(.secondary)
                        weeklyBar(weekly)
                        Text("\(Int((weekly * 100).rounded()))%").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        if columnWidth >= islandWideColumn { resetLabel(store.weeklyResetsAt, prefix: "·") }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 84)
    }

    private var barBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(store.isEstimate ? "≈" : "")\(Int((store.sessionFraction * 100).rounded()))%")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(color(store.sessionFraction))
                    .contentTransition(.numericText())
                Spacer()
                resetLabel(store.sessionResetsAt, prefix: "reinicia em")
            }
            UsageBar(fraction: store.sessionFraction, color: color(store.sessionFraction), height: 8,
                     ticks: [min(amber, 100) / 100, min(max(red, amber), 100) / 100])
            if Self.showsForecast(store, enabled: showForecast), let eta = store.sessionExhaustsAt {
                Label("Ao ritmo atual, esgota às \(eta.formatted(date: .omitted, time: .shortened))", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.medium)).foregroundStyle(Brand.amber)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Brand.amber.opacity(0.16)))
            }
            if showWeekly, let weekly = store.weeklyFraction {
                HStack(spacing: 8) {
                    Text("Semana").font(.caption2).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                    weeklyBar(weekly)
                    Text("\(Int((weekly * 100).rounded()))%").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                    resetLabel(store.weeklyResetsAt, prefix: "·")
                }
            }
        }
    }

    /// The week split into its 5 workdays; the colour follows the same limits as the session, measured against
    /// what may be used by the end of today (the white marker), so it warns when today's share is running out.
    private func weeklyBar(_ weekly: Double) -> some View {
        let allowance = store.weeklyResetsAt.map { WeeklyPace.allowance(resetsAt: $0, workStartMinute: workStart) }
        let pace = WeeklyPace.fraction(weekly: weekly, resetsAt: store.weeklyResetsAt, workStartMinute: workStart)
        let step = 1 / Double(WeeklyPace.workdays)
        return UsageBar(fraction: weekly, color: color(pace), height: 5,
                        ticks: (1..<WeeklyPace.workdays).map { Double($0) * step }, marker: allowance)
            .islandTip(allowance.map { "Limite diário: \(Int((step * 100).rounded()))% da semana por dia útil. Permitido agora (09:00–18:00):\(Int(($0 * 100).rounded()))% · usado \(Int((pace * 100).rounded()))% disso." }
                       ?? "Limite diário: \(Int((step * 100).rounded()))% da semana por dia útil.")
    }

    private static func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    private var costTiles: some View {
        let today = costStore.snapshot.today, week = costStore.snapshot.week
        return HStack(spacing: 8) {
            tile("Hoje", "\(UsageCost.compactTokens(today.total.tokens)) tok · ≈ \(UsageCost.dollars(today.total.cost))")
            tile("7 dias", "≈ \(UsageCost.dollars(week.total.cost))")
        }
        .islandTip("Equivalente à API, a preços editáveis nas Definições → Custo. Estimado a partir dos logs locais do Claude Code.")
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: IslandLayout.costTileHeight, maxHeight: IslandLayout.costTileHeight, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private var statusChip: some View {
        let (text, tint) = status
        return HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var status: (String, Color) {
        if store.isRefreshing { return ("a atualizar", Brand.blue) }
        if store.isEstimate {
            // Say why it is an estimate: the API error must stay visible while the local fallback fills in.
            switch store.status {
            case .rateLimited: return ("≈ estimado · API limitada\(store.retryHint)", Brand.amber)
            case .offline: return ("≈ estimado · sem ligação", Brand.amber)
            case .unauthorized: return ("≈ estimado · sessão expirada", Brand.red)
            default: return ("≈ estimado pelos logs", Brand.amber)
            }
        }
        switch store.status {
        case .ok, .loading: return ("ao vivo", Brand.green)
        case .noCredentials: return ("faz login no Claude Code", Brand.amber)
        case .unauthorized: return ("sessão expirada", Brand.red)
        case .offline: return ("sem ligação · último valor", Brand.amber)
        case .rateLimited: return ("API limitada\(store.retryHint)", Brand.amber)
        }
    }

    @ViewBuilder private func resetLabel(_ date: Date?, prefix: String) -> some View {
        if let date {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text("\(prefix) \(RemainingTime.string(until: date, now: context.date))").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
