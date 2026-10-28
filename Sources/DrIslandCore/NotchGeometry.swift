import CoreGraphics

public struct NotchMetrics: Equatable, Sendable {
    public var width: CGFloat
    public var height: CGFloat
    /// False on screens without a notch; the island then falls back to a pill under the menu bar.
    public var hasNotch: Bool
    /// Horizontal distance from the screen centre to the notch centre (the cut-out is not always exactly centred).
    public var centerOffset: CGFloat

    public init(width: CGFloat, height: CGFloat, hasNotch: Bool, centerOffset: CGFloat = 0) {
        self.width = width
        self.height = height
        self.hasNotch = hasNotch
        self.centerOffset = centerOffset
    }
}

public enum NotchGeometry {
    public static let fallbackPillWidth: CGFloat = 150

    /// - Parameters:
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top` (0 without a notch).
    ///   - auxLeftWidth / auxRightWidth: widths of `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`.
    public static func metrics(
        screenWidth: CGFloat,
        safeAreaTop: CGFloat,
        auxLeftWidth: CGFloat?,
        auxRightWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) -> NotchMetrics {
        if safeAreaTop > 0, let left = auxLeftWidth, let right = auxRightWidth, screenWidth - left - right > 0 {
            let width = screenWidth - left - right
            return NotchMetrics(width: width, height: safeAreaTop, hasNotch: true, centerOffset: left + width / 2 - screenWidth / 2)
        }
        return NotchMetrics(width: fallbackPillWidth, height: max(menuBarHeight, 24), hasNotch: false)
    }

    /// A rect of `size` centered horizontally (plus `centerOffset`) and flush with the top of `screenFrame` (AppKit coordinates).
    public static func topCenteredFrame(screenFrame: CGRect, size: CGSize, centerOffset: CGFloat = 0) -> CGRect {
        CGRect(x: screenFrame.midX + centerOffset - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
    }
}
