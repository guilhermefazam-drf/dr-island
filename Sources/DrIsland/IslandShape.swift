import SwiftUI

/// The island silhouette between the notch and the fully expanded size.
/// `widthProgress` and `heightProgress` run 0 (notch) → 1 (expanded) independently, so effects can
/// stage width and height separately; springs may overshoot past 1. With `funnel` the top stays near
/// notch width while the bottom flares out, which gives the Mac "genie" look.
struct IslandShape: Shape {
    var widthProgress: CGFloat
    var heightProgress: CGFloat
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var funnel = false
    var collapsedRadius: CGFloat = 10
    var expandedRadius: CGFloat = 28
    /// Only the left side, bottom and right side (no top edge), for stroking a border that hugs the island.
    var outlineOnly = false

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(widthProgress, heightProgress) }
        set { widthProgress = newValue.first; heightProgress = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let hp = heightProgress, wp = widthProgress
        let height = max(0, notchHeight + (rect.height - notchHeight) * hp)
        let bottomWidth = max(1, notchWidth + (rect.width - notchWidth) * wp)
        let radius = collapsedRadius + (expandedRadius - collapsedRadius) * min(max(hp, 0), 1)
        let cx = rect.midX
        let y0 = rect.minY

        guard funnel else {
            if outlineOnly {
                let x0 = cx - bottomWidth / 2, x1 = cx + bottomWidth / 2, yb = y0 + height
                let r = min(radius, height / 2, bottomWidth / 2)
                var p = Path()
                p.move(to: CGPoint(x: x0, y: y0))
                p.addLine(to: CGPoint(x: x0, y: yb - r))
                p.addRelativeArc(center: CGPoint(x: x0 + r, y: yb - r), radius: r, startAngle: .degrees(180), delta: .degrees(-90))
                p.addLine(to: CGPoint(x: x1 - r, y: yb))
                p.addRelativeArc(center: CGPoint(x: x1 - r, y: yb - r), radius: r, startAngle: .degrees(90), delta: .degrees(-90))
                p.addLine(to: CGPoint(x: x1, y: y0))
                return p
            }
            let box = CGRect(x: cx - bottomWidth / 2, y: y0, width: bottomWidth, height: height)
            return UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius).path(in: box)
        }

        // The top edge stays narrow until late in the animation (cubic), the bottom follows the width linearly.
        let u = min(max(wp, 0), 1)
        let topWidth = notchWidth + (rect.width - notchWidth) * u * u * u
        let r = min(radius, height / 2, bottomWidth / 2)
        let l0 = cx - topWidth / 2, r0 = cx + topWidth / 2
        let lb = cx - bottomWidth / 2, rb = cx + bottomWidth / 2
        let yb = y0 + height
        let ySide = yb - r
        let bend = y0 + (ySide - y0) * 0.65

        var p = Path()
        p.move(to: CGPoint(x: l0, y: y0))
        p.addCurve(to: CGPoint(x: lb, y: ySide), control1: CGPoint(x: l0, y: bend), control2: CGPoint(x: lb, y: bend))
        p.addQuadCurve(to: CGPoint(x: lb + r, y: yb), control: CGPoint(x: lb, y: yb))
        p.addLine(to: CGPoint(x: rb - r, y: yb))
        p.addQuadCurve(to: CGPoint(x: rb, y: ySide), control: CGPoint(x: rb, y: yb))
        p.addCurve(to: CGPoint(x: r0, y: y0), control1: CGPoint(x: rb, y: bend), control2: CGPoint(x: r0, y: bend))
        p.closeSubpath()
        return p
    }
}
