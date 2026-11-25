import SwiftUI
import DrIslandCore

/// Small spinning sync arrows shown beside the notch while a refresh runs.
struct SyncIcon: View {
    @State private var angle: Double = 0
    @Environment(\.islandPalette) private var palette

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(palette.text).opacity(0.9))
            .rotationEffect(.degrees(angle))
            .onAppear { withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { angle = 360 } }
    }
}
