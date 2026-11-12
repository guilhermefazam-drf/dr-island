import Foundation

/// Turns a horizontal swipe on the touchpad into the page the island settles on. Pure, so it can be tested.
public enum PageSwipe {
    /// A swipe that covers a third of the island's width turns the page.
    public static let distanceFraction = 1.0 / 3.0
    /// A quick flick (points per second) turns it even over a short distance.
    public static let velocityThreshold = 500.0

    /// Whether a scroll gesture is a horizontal swipe; mostly vertical movement never turns the page.
    public static func isHorizontal(deltaX: Double, deltaY: Double) -> Bool {
        abs(deltaX) > abs(deltaY) * 1.2
    }

    /// 0 = overview, 1 = management, following the finger. `translation` is positive when the content moves to the right
    /// (the finger moves right), so the management page, which sits on the right, comes in with a negative one.
    public static func progress(from page: IslandPage, translation: Double, width: Double) -> Double {
        guard width > 0 else { return Double(page.rawValue) }
        return min(max(Double(page.rawValue) - translation / width, 0), 1)
    }

    /// The page to settle on when the finger lifts.
    public static func target(from page: IslandPage, translation: Double, velocity: Double, width: Double) -> IslandPage {
        guard width > 0 else { return page }
        let farEnough = abs(translation) >= width * distanceFraction
        let fastEnough = abs(velocity) >= velocityThreshold
        guard farEnough || fastEnough else { return page }
        // Same direction as the move (a flick wins over a short drag that went the other way).
        let direction = fastEnough ? velocity : translation
        switch (page, direction < 0) {
        case (.overview, true): return .management
        case (.management, false): return .overview
        default: return page
        }
    }
}
