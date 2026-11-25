import AppKit
import SwiftUI
import DrIslandCore

/// The focus timer on one line: tile, phase and rounds, the time left and the controls.
struct FocusBlock: View {
    let store: FocusStore
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    /// Normal shows the round dots under the label; Compacto keeps a single line.
    static func contentHeight(_ m: IslandMetrics) -> CGFloat { m.rowHasMeta ? 40 : CGFloat(m.rowHeight) }

    var body: some View {
        let timer = store.timer
        let config = store.config
        let tint = timer.phase == .focus ? Color(palette.accent) : Color(palette.green)
        let button = CGFloat(metrics.rowHasMeta ? 30 : 22)
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(timer.remaining(now: context.date, config).rounded(.up))
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: CGFloat(metrics.tile) * 0.3, style: .continuous)
                        .fill(Color(palette.source(.focus)).opacity(0.2))
                    Image(systemName: "timer")
                        .font(.system(size: CGFloat(metrics.tile) * 0.45, weight: .semibold))
                        .foregroundStyle(Color(palette.source(.focus)))
                    Circle().trim(from: 0, to: timer.progress(now: context.date, config))
                        .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(4)
                }
                .frame(width: CGFloat(metrics.tile), height: CGFloat(metrics.tile))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(label(timer, config))
                        .font(.system(size: CGFloat(metrics.titleSize), weight: .semibold))
                        .foregroundStyle(Color(palette.text)).lineLimit(1)
                    if metrics.rowHasMeta { dots(timer, config, tint: tint) }
                }
                Spacer(minLength: 6)
                Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                    .font(.system(size: CGFloat(metrics.titleSize) * (metrics.rowHasMeta ? 1.4 : 1.1), weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color(palette.text))
                CircleButton(symbol: timer.isRunning ? "pause.fill" : "play.fill", size: button, filled: true,
                             help: timer.isRunning ? "Pausar" : "Começar") { store.toggle() }
                CircleButton(symbol: "forward.end.fill", size: button * 0.85, help: "Saltar para a fase seguinte") { store.skip() }
                CircleButton(symbol: "arrow.counterclockwise", size: button * 0.85, help: "Recomeçar") { store.reset() }
            }
        }
        .frame(height: Self.contentHeight(metrics))
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
        return HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Circle().fill(index < done ? tint : Color(palette.surfaceRaised)).frame(width: 6, height: 6)
            }
        }
    }
}
