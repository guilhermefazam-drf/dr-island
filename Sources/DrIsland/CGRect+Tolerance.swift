import AppKit
import SwiftUI
import DrIslandCore

extension CGRect {
    func isClose(to other: CGRect, tolerance: CGFloat = 1) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}
