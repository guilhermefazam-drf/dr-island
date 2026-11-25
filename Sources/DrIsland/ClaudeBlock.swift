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
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    /// Whether the "esgota às" chip is shown (it adds a row, so the island's height depends on it). Compacto leaves it out.
    static func showsForecast(_ store: UsageStore, enabled: Bool, metrics: IslandMetrics) -> Bool {
        enabled && metrics.rowHasMeta && !store.isEstimate && store.sessionExhaustsAt != nil
    }

    /// The card's height: header, the gauge (bar or ring), the forecast chip and the cost tiles.
    static func height(_ store: UsageStore, ring: Bool, showForecast: Bool, showCost: Bool, metrics: IslandMetrics) -> CGFloat {
        let gauge = ring ? CGFloat(metrics.ringSize)
            : IslandLayout.claudeBarBody + (showsForecast(store, enabled: showForecast, metrics: metrics) ? IslandLayout.forecastExtra : 0)
        let content = CGFloat(metrics.cardHeader) + 8 + gauge + (showCost ? IslandLayout.costExtra : 0)
        return CGFloat(metrics.card(Double(content)))
    }

    private var showsForecast: Bool { Self.showsForecast(store, enabled: showForecast, metrics: metrics) }

    private func color(_ fraction: Double) -> Color {
        Brand.color(forFraction: fraction, amber: amber, red: red, palette: palette)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader(title: "Claude", icon: "sparkle", source: .claude) { statusChip }
            if gauge == "ring" { ringBody } else {
                // Pinned to the height `height(...)` assumes, so the card never clips or leaves a gap.
                barBody.frame(height: IslandLayout.claudeBarBody + (showsForecast ? IslandLayout.forecastExtra : 0), alignment: .top)
            }
            if showCost { costTiles }
        }
        .blockCard()
    }

    /// The session as a ring with the percentage inside; the details sit beside it.
    private var ringBody: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color(palette.text).opacity(0.12), lineWidth: 9)
                Circle().trim(from: 0, to: min(max(store.sessionFraction, 0), 1))
                    .stroke(color(store.sessionFraction), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: store.sessionFraction)
                Text("\(store.isEstimate ? "≈" : "")\(Int((store.sessionFraction * 100).rounded()))%")
                    .font(.system(size: CGFloat(metrics.ringSize) * 0.26, weight: .semibold, design: .rounded)).foregroundStyle(color(store.sessionFraction))
                    .contentTransition(.numericText())
            }
            .frame(width: CGFloat(metrics.ringSize), height: CGFloat(metrics.ringSize))
            VStack(alignment: .leading, spacing: metrics.rowHasMeta ? 7 : 3) {
                Text("Sessão · 5 h").font(.caption2).foregroundStyle(Color(palette.textSecondary))
                resetLabel(store.sessionResetsAt, prefix: "reinicia em")
                if showsForecast, let eta = store.sessionExhaustsAt {
                    Label("esgota às \(eta.formatted(date: .omitted, time: .shortened))", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.medium)).foregroundStyle(Color(palette.amber))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color(palette.amber).opacity(0.16)))
                }
                if showWeekly, let weekly = store.weeklyFraction {
                    HStack(spacing: 6) {
                        Text("Semana").font(.caption2).foregroundStyle(Color(palette.textSecondary))
                        weeklyBar(weekly)
                        Text("\(Int((weekly * 100).rounded()))%").font(.caption2.monospacedDigit()).foregroundStyle(Color(palette.textSecondary))
                        if columnWidth >= islandWideColumn { resetLabel(store.weeklyResetsAt, prefix: "·") }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: CGFloat(metrics.ringSize))
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
            if showsForecast, let eta = store.sessionExhaustsAt {
                Label("Ao ritmo atual, esgota às \(eta.formatted(date: .omitted, time: .shortened))", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.medium)).foregroundStyle(Color(palette.amber))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(palette.amber).opacity(0.16)))
            }
            if showWeekly, let weekly = store.weeklyFraction {
                HStack(spacing: 8) {
                    Text("Semana").font(.caption2).foregroundStyle(Color(palette.textSecondary)).frame(width: 44, alignment: .leading)
                    weeklyBar(weekly)
                    Text("\(Int((weekly * 100).rounded()))%").font(.caption2.monospacedDigit()).foregroundStyle(Color(palette.textSecondary))
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
            Text(title).font(.caption2).foregroundStyle(Color(palette.textSecondary))
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: IslandLayout.costTileHeight, maxHeight: IslandLayout.costTileHeight, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(palette.text).opacity(0.06)))
    }

    private var statusChip: some View {
        let (text, tint) = status
        return HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(text).foregroundStyle(Color(palette.textSecondary))
        }
    }

    private var status: (String, Color) {
        if store.isRefreshing { return ("a atualizar", Color(palette.accent)) }
        if store.isEstimate {
            // Say why it is an estimate: the API error must stay visible while the local fallback fills in.
            switch store.status {
            case .rateLimited: return ("≈ estimado · API limitada\(store.retryHint)", Color(palette.amber))
            case .offline: return ("≈ estimado · sem ligação", Color(palette.amber))
            case .unauthorized: return ("≈ estimado · sessão expirada", Color(palette.red))
            default: return ("≈ estimado pelos logs", Color(palette.amber))
            }
        }
        switch store.status {
        case .ok, .loading: return ("ao vivo", Color(palette.green))
        case .noCredentials: return ("faz login no Claude Code", Color(palette.amber))
        case .unauthorized: return ("sessão expirada", Color(palette.red))
        case .offline: return ("sem ligação · último valor", Color(palette.amber))
        case .rateLimited: return ("API limitada\(store.retryHint)", Color(palette.amber))
        }
    }

    @ViewBuilder private func resetLabel(_ date: Date?, prefix: String) -> some View {
        if let date {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text("\(prefix) \(RemainingTime.string(until: date, now: context.date))").font(.caption2).foregroundStyle(Color(palette.textSecondary))
            }
        }
    }
}
