import SwiftUI
import DrIslandCore

/// What is playing, small, at the start of Bento's dock: the cover, the title and «a tocar» (Normal) and play/pause.
struct NowPlayingChip: View {
    let store: MusicStore
    let playing: NowPlaying
    /// The dock's icon size; the chip is as tall.
    let size: CGFloat
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        HStack(spacing: 7) {
            cover
            if metrics.rowHasMeta {
                VStack(alignment: .leading, spacing: 0) {
                    Text(playing.title).font(.system(size: CGFloat(metrics.metaSize), weight: .semibold))
                        .foregroundStyle(Color(palette.text))
                    Text(playing.isPlaying ? "a tocar" : "em pausa").font(.system(size: 10))
                        .foregroundStyle(Color(palette.textSecondary))
                }
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .leading)
            }
            Button { store.playPause() } label: {
                Image(systemName: playing.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(Color(palette.isLight ? ThemeColor(0xFFFFFF) : ThemeColor(0x000000)))
                    .frame(width: size * 0.72, height: size * 0.72)
                    .background(Circle().fill(Color(palette.text)))
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .islandTip(playing.isPlaying ? "Pausar" : "Tocar")
        }
        .frame(height: size)
        .islandTip(playing.artist.isEmpty ? playing.title : "\(playing.title) · \(playing.artist)")
    }

    private var cover: some View {
        Group {
            if let art = store.artwork {
                Image(nsImage: art).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").foregroundStyle(Color(palette.source(.music)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(palette.source(.music)).opacity(0.2))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}
