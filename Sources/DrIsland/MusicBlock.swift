import AppKit
import SwiftUI
import DrIslandCore

/// What is playing (Spotify, Apple Music or the system's Now Playing), on one line.
struct MusicBlock: View {
    let store: MusicStore
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    /// One line with the cover, title, artist and controls; at Normal density a thin progress bar runs under it when
    /// the source tells the track's length. With nothing playing, a single «Nada a tocar» row.
    static func contentHeight(_ playing: NowPlaying?, _ m: IslandMetrics) -> CGFloat {
        guard let playing else { return CGFloat(m.rowHeight) }
        let line: CGFloat = m.rowHasMeta ? 40 : CGFloat(m.rowHeight)
        return line + (m.rowHasMeta && playing.duration != nil ? 18 : 0)
    }

    /// The tallest the block gets (for the panel's maximum size).
    static func maxContentHeight(_ m: IslandMetrics) -> CGFloat { (m.rowHasMeta ? 40 : CGFloat(m.rowHeight)) + (m.rowHasMeta ? 18 : 0) }

    private var coverSize: CGFloat { metrics.rowHasMeta ? 40 : CGFloat(metrics.rowHeight) }
    private var mainButton: CGFloat { metrics.rowHasMeta ? 30 : 22 }

    var body: some View {
        if let playing = store.nowPlaying {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    cover(playing)
                    VStack(alignment: .leading, spacing: 2) {
                        MarqueeText(text: playing.title, font: .system(size: CGFloat(metrics.titleSize), weight: .semibold))
                        if store.needsAccessibility || store.needsAutomation {
                            Button { store.requestPermission() } label: {
                                Text(store.needsAutomation ? "Permite o Dr Island em Automação — toca para pedir" : "Permite o Dr Island em Acessibilidade — toca para pedir")
                                    .font(.system(size: CGFloat(metrics.metaSize))).foregroundStyle(Color(palette.amber)).lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        } else if metrics.rowHasMeta {
                            MarqueeText(text: subtitle(playing), font: .system(size: CGFloat(metrics.metaSize)), color: Color(palette.textSecondary))
                        }
                    }
                    Spacer(minLength: 6)
                    CircleButton(symbol: "backward.fill", size: mainButton * 0.85, help: "Anterior") { store.previous() }
                    CircleButton(symbol: playing.isPlaying ? "pause.fill" : "play.fill", size: mainButton, filled: true,
                                 help: playing.isPlaying ? "Pausar" : "Tocar") { store.playPause() }
                    CircleButton(symbol: "forward.fill", size: mainButton * 0.85, help: "Seguinte") { store.next() }
                }
                if metrics.rowHasMeta, playing.duration != nil { progress(playing) }
            }
            .frame(height: Self.contentHeight(playing, metrics))
            .blockCard()
        } else {
            idle
        }
    }

    /// Nothing playing: one dimmed row instead of a full player.
    private var idle: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: CGFloat(metrics.tile) * 0.55, weight: .semibold))
                .foregroundStyle(Color(palette.source(.music)))
                .frame(width: CGFloat(metrics.tile), height: CGFloat(metrics.tile))
                .background(RoundedRectangle(cornerRadius: CGFloat(metrics.tile) * 0.3, style: .continuous).fill(Color(palette.source(.music)).opacity(0.2)))
            Text("Nada a tocar").font(.system(size: CGFloat(metrics.bodySize))).foregroundStyle(Color(palette.textSecondary))
            Spacer(minLength: 0)
        }
        .frame(height: Self.contentHeight(nil, metrics))
        .blockCard()
        .opacity(0.7)
        .islandTip("Abre uma música para a controlar aqui")
    }

    private func cover(_ playing: NowPlaying) -> some View {
        Button { open(playing) } label: {
            Group {
                if let art = store.artwork {
                    Image(nsImage: art).resizable().scaledToFill()
                } else {
                    Image(systemName: "music.note").foregroundStyle(Color(palette.source(.music)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(palette.source(.music)).opacity(0.2))
                }
            }
            .frame(width: coverSize, height: coverSize)
            .clipShape(RoundedRectangle(cornerRadius: coverSize * 0.22, style: .continuous))
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
                UsageBar(fraction: position / length, color: Color(palette.text).opacity(0.85), height: 3.5)
                Text(Self.clock(length)).frame(width: 34, alignment: .leading)
            }
            .font(.system(size: 9).monospacedDigit()).foregroundStyle(Color(palette.textSecondary))
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
        return Duration.seconds(total).formatted(.time(pattern: total >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
