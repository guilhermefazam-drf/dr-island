import AppKit
import SwiftUI
import DrIslandCore

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
                    Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
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
