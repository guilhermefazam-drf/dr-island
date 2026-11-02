import AppKit
import DrIslandCore

/// Reads a two-finger horizontal swipe on the touchpad and moves `IslandState.pageProgress` with it.
/// One per island; the controller hands it the scroll events that happen over that island while it is open.
@MainActor
final class IslandPageSwiper {
    private var translation = 0.0
    private var velocity = 0.0
    private var lastTime: TimeInterval = 0
    private var pendingX = 0.0
    private var pendingY = 0.0
    /// nil until the first movement shows whether the gesture is horizontal.
    private var horizontal: Bool?
    private var swallowMomentum = false

    /// Returns true when the event belongs to a page swipe and must not reach anything else. `settle` gets the page the
    /// island should land on when the fingers lift.
    func handle(_ event: NSEvent, state: IslandState, width: CGFloat, settle: (IslandPage) -> Void) -> Bool {
        guard event.hasPreciseScrollingDeltas else { return false }   // a mouse wheel never turns the page
        if !event.momentumPhase.isEmpty {
            // The tail of a swipe that already turned the page: swallow it so the lists below do not scroll.
            let swallow = swallowMomentum
            if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) { swallowMomentum = false }
            return swallow
        }
        if event.phase.contains(.began) || event.phase.contains(.mayBegin) { reset(); swallowMomentum = false }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            return finish(cancelled: event.phase.contains(.cancelled), state: state, width: width, settle: settle)
        }
        return track(event, state: state, width: width)
    }

    private func track(_ event: NSEvent, state: IslandState, width: CGFloat) -> Bool {
        // With natural scrolling the content follows the fingers; without it the deltas point the other way.
        let sign = event.isDirectionInvertedFromDevice ? 1.0 : -1.0
        let dx = Double(event.scrollingDeltaX), dy = Double(event.scrollingDeltaY)
        if horizontal == nil {
            pendingX += dx
            pendingY += dy
            guard abs(pendingX) + abs(pendingY) > 6 else { return false }
            horizontal = PageSwipe.isHorizontal(deltaX: pendingX, deltaY: pendingY)
            guard horizontal == true else { return false }
            translation = sign * pendingX
            lastTime = event.timestamp
        } else if horizontal == true {
            translation += sign * dx
            let elapsed = event.timestamp - lastTime
            if elapsed > 0 { velocity = 0.5 * velocity + 0.5 * (sign * dx / elapsed) }
            lastTime = event.timestamp
        }
        guard horizontal == true else { return false }
        state.isSwiping = true
        state.pageProgress = PageSwipe.progress(from: state.page, translation: translation, width: Double(width))
        return true
    }

    private func finish(cancelled: Bool, state: IslandState, width: CGFloat, settle: (IslandPage) -> Void) -> Bool {
        defer { reset() }
        guard horizontal == true else { return false }
        let target = cancelled ? state.page
            : PageSwipe.target(from: state.page, translation: translation, velocity: velocity, width: Double(width))
        swallowMomentum = true
        settle(target)
        return true
    }

    private func reset() {
        translation = 0; velocity = 0; pendingX = 0; pendingY = 0; lastTime = 0; horizontal = nil
    }
}
