import AppKit
import SwiftUI
import DrIslandCore

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
        return Duration.seconds(total).formatted(.time(pattern: total >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
