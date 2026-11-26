import SwiftUI
import DrIslandCore

/// The small card a chart shows for the point under the pointer: a title and one line per series, each with its key.
struct ChartTooltip: View {
    struct Line: Identifiable {
        var id: String { label }
        let label: String
        let value: String
        let color: Color
    }

    let title: String
    let lines: [Line]
    @Environment(\.islandPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(palette.text))
            ForEach(lines) { line in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 1.5).fill(line.color).frame(width: 7, height: 7)
                    Text(line.label).foregroundStyle(Color(palette.textSecondary))
                    Spacer(minLength: 8)
                    Text(line.value).foregroundStyle(Color(palette.text)).monospacedDigit()
                }
                .font(.system(size: 10))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 110)
        .background {
            // Opaque, so the marks under it do not show through.
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(Color(palette.base.first ?? palette.collar))
                RoundedRectangle(cornerRadius: 7).fill(Color(palette.surfaceRaised))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color(palette.border)))
        .shadow(color: .black.opacity(palette.isLight ? 0.12 : 0.4), radius: 6, y: 2)
    }
}
