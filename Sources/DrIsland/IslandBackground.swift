import SwiftUI
import DrIslandCore

/// The expanded island's fill: the theme's base (flat or a top-to-bottom gradient), Aurora's two soft glows and,
/// when the collar differs from the base (Claro), a band of that colour under the physical notch so the island
/// still blends with it.
struct IslandBackground: View {
    let theme: IslandTheme
    let palette: IslandPalette
    /// Height of the collar band: the notch strip plus the gap above the content.
    let collarHeight: CGFloat
    let reduceTransparency: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if palette.base.count > 1 {
                LinearGradient(colors: palette.base.map { Color($0) }, startPoint: .top, endPoint: .bottom)
            } else {
                Color(palette.base.last ?? palette.collar)
            }
            if theme == .aurora && !reduceTransparency { glows }
            if palette.collar != palette.base.first {
                Color(palette.collar).frame(height: collarHeight)
            }
        }
    }

    private var glows: some View {
        GeometryReader { geo in
            let radius = max(geo.size.width, 1) * 0.55
            ZStack {
                RadialGradient(colors: [Color(ThemeColor(0x7A5CFF, alpha: 0.28)), .clear], center: .topLeading, startRadius: 0, endRadius: radius)
                RadialGradient(colors: [Color(ThemeColor(0x00BEC8, alpha: 0.20)), .clear], center: .topTrailing, startRadius: 0, endRadius: radius)
            }
        }
        .allowsHitTesting(false)
    }
}
