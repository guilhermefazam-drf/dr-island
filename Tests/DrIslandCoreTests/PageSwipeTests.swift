import Testing
@testable import DrIslandCore

@Suite struct PageSwipeTests {
    private let width = 600.0

    @Test func aLongSwipeLeftOpensManagement() {
        #expect(PageSwipe.target(from: .overview, translation: -250, velocity: 0, width: width) == .management)
    }

    @Test func aShortSlowSwipeStaysPut() {
        #expect(PageSwipe.target(from: .overview, translation: -100, velocity: -100, width: width) == .overview)
    }

    @Test func aQuickFlickTurnsTheFirstPageOverAShortDistance() {
        #expect(PageSwipe.target(from: .overview, translation: -40, velocity: -900, width: width) == .management)
    }

    @Test func aLongSwipeRightGoesBack() {
        #expect(PageSwipe.target(from: .management, translation: 250, velocity: 0, width: width) == .overview)
    }

    @Test func pagesDoNotWrapAround() {
        #expect(PageSwipe.target(from: .overview, translation: 400, velocity: 900, width: width) == .overview)
        #expect(PageSwipe.target(from: .management, translation: -400, velocity: -900, width: width) == .management)
    }

    @Test func aFlickWinsOverAShortDragTheOtherWay() {
        #expect(PageSwipe.target(from: .overview, translation: 400, velocity: -900, width: width) == .management)
    }

    @Test func progressFollowsTheFingerAndIsClamped() {
        #expect(PageSwipe.progress(from: .overview, translation: -300, width: width) == 0.5)
        #expect(PageSwipe.progress(from: .overview, translation: 300, width: width) == 0)
        #expect(PageSwipe.progress(from: .management, translation: -300, width: width) == 1)
        #expect(PageSwipe.progress(from: .management, translation: 150, width: width) == 0.75)
    }

    @Test func verticalMovementNeverTurnsThePage() {
        #expect(PageSwipe.isHorizontal(deltaX: 30, deltaY: 5))
        #expect(!PageSwipe.isHorizontal(deltaX: 5, deltaY: 30))
        #expect(!PageSwipe.isHorizontal(deltaX: 10, deltaY: 10))
    }

    @Test func aZeroWidthIsHarmless() {
        #expect(PageSwipe.target(from: .overview, translation: -100, velocity: -900, width: 0) == .overview)
        #expect(PageSwipe.progress(from: .management, translation: -100, width: 0) == 1)
    }
}
