import SwiftUI

/// The launch splash logo: it rises out of a blur with a soft spring, then a highlight sweeps across it once.
/// With Reduce Motion it only fades in.
struct SplashLogo: View {
    let image: NSImage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var sheen: CGFloat = -1

    private var logo: some View {
        Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
    }

    var body: some View {
        logo
            .overlay {
                if !reduceMotion {
                    LinearGradient(colors: [.clear, .white.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 36)
                        .rotationEffect(.degrees(18))
                        .offset(x: sheen * 90)
                        .mask { logo }
                        .blendMode(.plusLighter)
                }
            }
            .scaleEffect(reduceMotion ? 1 : (revealed ? 1 : 0.72))
            .blur(radius: reduceMotion || revealed ? 0 : 7)
            .opacity(revealed ? 1 : 0)
            .shadow(color: .white.opacity(revealed && !reduceMotion ? 0.18 : 0), radius: 6)
            .task {
                // The mini island is still growing out of the notch: the logo arrives a beat later.
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 280))
                withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.72)) { revealed = true }
                guard !reduceMotion else { return }
                try? await Task.sleep(for: .milliseconds(550))
                withAnimation(.easeInOut(duration: 0.9)) { sheen = 1 }
            }
    }
}
