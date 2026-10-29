import AppKit
import SwiftUI
import DrIslandCore

/// The Doutor Finanças blue and the macOS window-button colours used across the island.
enum Brand {
    static let blue = Color(red: 0x00 / 255, green: 0xA6 / 255, blue: 0xE5 / 255)
    static let green = Color(red: 0x28 / 255, green: 0xC8 / 255, blue: 0x40 / 255)
    static let amber = Color(red: 0xFE / 255, green: 0xBC / 255, blue: 0x2E / 255)
    static let red = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)
}

private struct ColumnWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 300 }
extension EnvironmentValues {
    /// Width of the island column a block sits in, so blocks can use extra room instead of just stretching.
    var islandColumnWidth: CGFloat {
        get { self[ColumnWidthKey.self] }
        set { self[ColumnWidthKey.self] = newValue }
    }
}

// MARK: - Tooltips

/// The island's own tooltip. The native `.help` never shows here: the island is a non-activating panel of an app that is
/// never frontmost, and AppKit only shows tooltips for the active app. So a hovered view reports its frame here and
/// `IslandView` draws the bubble inside the visible island, where it is never cut at the edges.
struct IslandTipData: Equatable {
    let text: String
    /// The hovered view's frame in the island's `islandRoot` coordinate space.
    let anchor: CGRect
}

let islandRootSpace = "islandRoot"

private struct TipSetterKey: EnvironmentKey { static let defaultValue: (IslandTipData?) -> Void = { _ in } }
extension EnvironmentValues {
    var islandTip: (IslandTipData?) -> Void {
        get { self[TipSetterKey.self] }
        set { self[TipSetterKey.self] = newValue }
    }
}

private struct IslandTipModifier: ViewModifier {
    let text: String
    @Environment(\.islandTip) private var setTip
    @State private var frame: CGRect = .zero
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { frame = geo.frame(in: .named(islandRootSpace)) }
                    .onChange(of: geo.frame(in: .named(islandRootSpace))) { _, new in frame = new }
            })
            .onHover { inside in
                pending?.cancel()
                guard !text.isEmpty else { return }
                guard inside else { setTip(nil); return }
                pending = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }
                    setTip(IslandTipData(text: text, anchor: frame))
                }
            }
            .onDisappear { pending?.cancel(); setTip(nil) }
            .accessibilityLabel(text)
    }
}

extension View {
    /// Hover label that works in the island (see `IslandTipData`); also the accessibility label.
    func islandTip(_ text: String) -> some View { modifier(IslandTipModifier(text: text)) }
}

/// From this column width a block may spread out (controls to the edge, extra details).
let islandWideColumn: CGFloat = 340

extension View {
    /// A slightly lighter rounded panel behind the secondary blocks, so the island has structure.
    func blockCard() -> some View {
        padding(IslandLayout.cardPadding)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.055)))
    }
}

/// A round icon button; `filled` is the main action of a group (white disc, dark glyph).
struct CircleButton: View {
    let symbol: String
    var size: CGFloat = 26
    var filled = false
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(filled ? Color.black : Color.white.opacity(0.9))
                .frame(width: size, height: size)
                .background(Circle().fill(filled ? Color.white : Color.white.opacity(0.0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .islandTip(help)
    }
}

/// A progress bar with optional tick marks (for the amber and red limits).
struct UsageBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6
    var ticks: [Double] = []

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(color).frame(width: max(geo.size.width * min(max(fraction, 0), 1), height))
                    .animation(.easeOut(duration: 0.5), value: fraction)
                ForEach(ticks, id: \.self) { tick in
                    Rectangle().fill(Color.black.opacity(0.55)).frame(width: 1.5, height: height)
                        .offset(x: geo.size.width * tick - 0.75)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}

/// One line that scrolls to and fro when it does not fit, instead of being cut off.
struct MarqueeText: View {
    let text: String
    var font: Font = .caption
    var color: Color = .white

    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0
    private var overflow: CGFloat { max(0, textWidth - boxWidth) }

    var body: some View {
        // The invisible, truncated copy gives the box its height and a width that never exceeds the column;
        // the real text is laid out at its natural width inside it and slid along when it is longer.
        Text(text).font(font).lineLimit(1).opacity(0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { geo in
                Color.clear.onAppear { boxWidth = geo.size.width }.onChange(of: geo.size.width) { _, w in boxWidth = w }
            })
            .overlay(alignment: .leading) {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: overflow == 0)) { context in
                    Text(text).font(font).foregroundStyle(color).fixedSize()
                        .background(GeometryReader { geo in
                            Color.clear.onAppear { textWidth = geo.size.width }.onChange(of: geo.size.width) { _, w in textWidth = w }
                        })
                        .offset(x: -offset(at: context.date))
                }
            }
            .clipped()
            .id(text)
    }

    /// Wait, scroll to the end, wait, scroll back.
    private func offset(at date: Date) -> CGFloat {
        guard overflow > 0 else { return 0 }
        let travel = Double(overflow) / 28, pause = 1.6
        let total = 2 * (travel + pause)
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: total)
        if t < pause { return 0 }
        if t < pause + travel { return CGFloat((t - pause) / travel) * overflow }
        if t < 2 * pause + travel { return overflow }
        return CGFloat(1 - (t - 2 * pause - travel) / travel) * overflow
    }
}

// MARK: - Foco

struct FocusBlock: View {
    let store: FocusStore
    @Environment(\.islandColumnWidth) private var columnWidth

    var body: some View {
        let timer = store.timer
        let config = store.config
        let tint = timer.phase == .focus ? Brand.blue : Brand.green
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(timer.remaining(now: context.date, config).rounded(.up))
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
                    Circle().trim(from: 0, to: timer.progress(now: context.date, config))
                        .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                }
                .frame(width: IslandLayout.focusContent, height: IslandLayout.focusContent)
                let controls = HStack(spacing: 8) {
                    CircleButton(symbol: timer.isRunning ? "pause.fill" : "play.fill", size: 30, filled: true,
                                 help: timer.isRunning ? "Pausar" : "Começar") { store.toggle() }
                    CircleButton(symbol: "forward.end.fill", help: "Saltar para a fase seguinte") { store.skip() }
                    CircleButton(symbol: "arrow.counterclockwise", help: "Recomeçar") { store.reset() }
                }
                if columnWidth >= islandWideColumn {
                    // Wide: the text keeps the left, the controls sit at the right edge, and nothing floats in between.
                    VStack(alignment: .leading, spacing: 7) {
                        Text(label(timer, config)).font(.system(size: 13, weight: .medium))
                        dots(timer, config, tint: tint)
                    }
                    Spacer(minLength: 8)
                    controls
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(label(timer, config)).font(.caption).foregroundStyle(.secondary)
                        dots(timer, config, tint: tint)
                        controls
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: IslandLayout.focusContent)
        .blockCard()
    }

    private func label(_ timer: FocusTimer, _ config: FocusTimer.Config) -> String {
        guard timer.phase == .focus else { return timer.phase.title }
        return "Foco · ronda \(timer.completedRounds % config.roundsBeforeLongBreak + 1) de \(config.roundsBeforeLongBreak)"
    }

    /// One dot per round of the cycle; filled for the finished ones (all of them during the long break).
    private func dots(_ timer: FocusTimer, _ config: FocusTimer.Config, tint: Color) -> some View {
        let total = config.roundsBeforeLongBreak
        let done = timer.phase == .longBreak ? total : timer.completedRounds % total
        return HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Circle().fill(index < done ? tint : Color.white.opacity(0.18)).frame(width: 7, height: 7)
            }
        }
    }
}

// MARK: - Música

struct MusicBlock: View {
    let store: MusicStore
    @Environment(\.islandColumnWidth) private var columnWidth

    /// The block's height for a given track: the progress row only exists when the source tells the length.
    static func contentHeight(_ playing: NowPlaying) -> CGFloat {
        playing.duration == nil ? IslandLayout.musicContent : IslandLayout.musicContentWithProgress
    }

    var body: some View {
        if let playing = store.nowPlaying {
            HStack(spacing: 12) {
                cover(playing)
                VStack(alignment: .leading, spacing: 4) {
                    MarqueeText(text: playing.title, font: .system(size: 13, weight: .semibold))
                    if store.needsAccessibility || store.needsAutomation {
                        Button { store.requestPermission() } label: {
                            Text(store.needsAutomation ? "Permite o Dr Island em Automação — toca para pedir" : "Permite o Dr Island em Acessibilidade — toca para pedir")
                                .font(.caption2).foregroundStyle(Brand.amber).lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        MarqueeText(text: subtitle(playing), font: .caption, color: .secondary)
                    }
                    if playing.duration != nil { progress(playing) }
                    HStack(spacing: 14) {
                        if columnWidth < islandWideColumn { Spacer(minLength: 0) }
                        CircleButton(symbol: "backward.fill", help: "Anterior") { store.previous() }
                        CircleButton(symbol: playing.isPlaying ? "pause.fill" : "play.fill", size: 30, filled: true,
                                     help: playing.isPlaying ? "Pausar" : "Tocar") { store.playPause() }
                        CircleButton(symbol: "forward.fill", help: "Seguinte") { store.next() }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: Self.contentHeight(playing))
            .blockCard()
        } else {
            idle
        }
    }

    /// Nothing playing: the block stays in place, dimmed and inert.
    private var idle: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note").font(.title2).foregroundStyle(.secondary)
                .frame(width: 64, height: 64).background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Nada a tocar").font(.system(size: 13, weight: .semibold))
                Text("Abre uma música para a controlar aqui").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 14) {
                    Spacer(minLength: 0)
                    CircleButton(symbol: "backward.fill", help: "Anterior") {}
                    CircleButton(symbol: "play.fill", size: 30, filled: true, help: "Tocar") {}
                    CircleButton(symbol: "forward.fill", help: "Seguinte") {}
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: IslandLayout.musicContent)
        .blockCard()
        .disabled(true)
        .opacity(0.45)
        .islandTip("Nenhuma música a tocar")
    }

    private func cover(_ playing: NowPlaying) -> some View {
        Button { open(playing) } label: {
            Group {
                if let art = store.artwork {
                    Image(nsImage: art).resizable().scaledToFill()
                } else {
                    Image(systemName: "music.note").font(.title2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white.opacity(0.08))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .islandTip(sourceName(playing).map { "Abrir \($0)" } ?? "")
    }

    private func progress(_ playing: NowPlaying) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = playing.currentPosition(now: context.date) ?? 0
            let length = playing.duration ?? 1
            HStack(spacing: 6) {
                Text(Self.clock(position)).frame(width: 34, alignment: .trailing)
                UsageBar(fraction: position / length, color: .white.opacity(0.85), height: 3.5)
                Text(Self.clock(length)).frame(width: 34, alignment: .leading)
            }
            .font(.system(size: 9).monospacedDigit()).foregroundStyle(.secondary)
        }
        .frame(height: 12)
    }

    private func subtitle(_ playing: NowPlaying) -> String {
        [playing.artist.isEmpty ? nil : playing.artist, sourceName(playing)].compactMap { $0 }.joined(separator: " · ")
    }

    private func sourceName(_ playing: NowPlaying) -> String? {
        guard let id = playing.sourceBundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return playing.player == .system ? nil : playing.player.name
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func open(_ playing: NowPlaying) {
        guard let id = playing.sourceBundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60) : String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Claude

struct ClaudeBlock: View {
    @Environment(\.islandColumnWidth) private var columnWidth
    let store: UsageStore
    let costStore: CostStore
    let showCost: Bool
    @AppStorage(SettingsKey.showWeekly) private var showWeekly = true
    @AppStorage(SettingsKey.showForecast) private var showForecast = true
    @AppStorage(SettingsKey.amberThreshold) private var amber = 60.0
    @AppStorage(SettingsKey.redThreshold) private var red = 85.0
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
                        UsageBar(fraction: weekly, color: color(weekly), height: 5)
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
                    UsageBar(fraction: weekly, color: color(weekly), height: 5)
                    Text("\(Int((weekly * 100).rounded()))%").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                    resetLabel(store.weeklyResetsAt, prefix: "·")
                }
            }
        }
    }

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

// MARK: - Avisos recentes

struct AlertsBlock: View {
    let entries: [AlertEntry]
    let openAll: () -> Void

    static let maxRows = 4

    static func contentHeight(rows: Int) -> CGFloat {
        IslandLayout.alertsHeader + 6 + CGFloat(rows) * IslandLayout.alertsRow
    }

    var body: some View {
        let shown = Array(entries.prefix(Self.maxRows))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Avisos recentes", systemImage: "bell").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action: openAll) {
                    Text("ver tudo").font(.caption2).foregroundStyle(Color(red: 0.45, green: 0.68, blue: 1.0))
                }
                .buttonStyle(.plain).pointingHandCursor()
            }
            .frame(height: IslandLayout.alertsHeader)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(shown) { entry in row(entry, now: context.date) }
                }
            }
        }
        .frame(height: Self.contentHeight(rows: shown.count), alignment: .top)
        .blockCard()
    }

    private func row(_ entry: AlertEntry, now: Date) -> some View {
        let content = HStack(spacing: 8) {
            Circle().fill(entry.tone.color).frame(width: 7, height: 7)
            Text(entry.displayMessage).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            Text(Self.relative(entry.date, now: now)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(height: IslandLayout.alertsRow)
        .contentShape(Rectangle())
        return Group {
            if let url = entry.destination {
                Button { NSWorkspace.shared.open(url) } label: { content }.buttonStyle(.plain).pointingHandCursor()
                    .islandTip("Abrir")
            } else {
                content
            }
        }
    }

    /// "agora", "5 min", "2 h", "ontem".
    static func relative(_ date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "agora"
        case ..<3600: return "\(seconds / 60) min"
        case ..<86_400: return "\(seconds / 3600) h"
        default: return Calendar.current.isDateInYesterday(date) ? "ontem" : "\(seconds / 86_400) d"
        }
    }
}

// MARK: - Sprint

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
