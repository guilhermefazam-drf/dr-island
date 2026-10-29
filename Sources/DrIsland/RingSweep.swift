import SwiftUI
import DrIslandCore

/// A short bright segment that travels along the ring; `sweep` runs 0 → 1.22 so the tail also leaves the end.
struct RingSweep: Shape {
    var base: NotchRing
    var sweep: CGFloat
    var length: CGFloat = 0.22

    var animatableData: CGFloat {
        get { sweep }
        set { sweep = newValue }
    }

    func path(in rect: CGRect) -> Path {
        base.path(in: rect).trimmedPath(from: min(max(sweep - length, 0), 1), to: min(max(sweep, 0), 1))
    }
}
