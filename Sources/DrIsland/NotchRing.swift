import SwiftUI
import DrIslandCore

/// Open "U" hugging the outside of the notch, from the top-left edge, round the bottom, to the top-right edge.
struct NotchRing: Shape {
    var cornerRadius: CGFloat
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let x0 = rect.minX + inset
        let x1 = rect.maxX - inset
        let yb = rect.maxY - inset
        let r = max(0, min(cornerRadius, (x1 - x0) / 2, yb - rect.minY))
        var p = Path()
        p.move(to: CGPoint(x: x0, y: rect.minY))
        p.addLine(to: CGPoint(x: x0, y: yb - r))
        p.addRelativeArc(center: CGPoint(x: x0 + r, y: yb - r), radius: r, startAngle: .degrees(180), delta: .degrees(-90))
        p.addLine(to: CGPoint(x: x1 - r, y: yb))
        p.addRelativeArc(center: CGPoint(x: x1 - r, y: yb - r), radius: r, startAngle: .degrees(90), delta: .degrees(-90))
        p.addLine(to: CGPoint(x: x1, y: rect.minY))
        return p
    }
}
