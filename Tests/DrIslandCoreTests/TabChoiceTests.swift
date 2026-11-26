import Testing
@testable import DrIslandCore

@Suite struct TabChoiceTests {
    @Test func tabsOnlyWhenBothListsHaveSomething() {
        #expect(TabChoice.tabs(firstCount: 3, secondCount: 2, secondEnabled: true) == [.first, .second])
        #expect(TabChoice.tabs(firstCount: 0, secondCount: 2, secondEnabled: true).isEmpty)
        #expect(TabChoice.tabs(firstCount: 3, secondCount: 0, secondEnabled: true).isEmpty)
        #expect(TabChoice.tabs(firstCount: 3, secondCount: 2, secondEnabled: false).isEmpty)
    }

    @Test func opensOnTheOtherTabOnlyWhenItHasNewsAndCurrentHasNone() {
        #expect(TabChoice.onOpen(current: .first, firstUnseen: 0, secondUnseen: 2) == .second)
        #expect(TabChoice.onOpen(current: .second, firstUnseen: 1, secondUnseen: 0) == .first)
    }

    @Test func staysWhenCurrentHasNewsOrNobodyHas() {
        #expect(TabChoice.onOpen(current: .first, firstUnseen: 1, secondUnseen: 2) == .first)
        #expect(TabChoice.onOpen(current: .second, firstUnseen: 0, secondUnseen: 0) == .second)
    }

    @Test func opensOnTheTabWithItemsWhenCurrentIsEmpty() {
        #expect(TabChoice.onOpen(current: .first, firstUnseen: 0, secondUnseen: 0, firstItems: 0, secondItems: 3) == .second)
        #expect(TabChoice.onOpen(current: .second, firstUnseen: 0, secondUnseen: 0, firstItems: 2, secondItems: 0) == .first)
    }

    @Test func neverMovesToAnEmptyTab() {
        #expect(TabChoice.onOpen(current: .first, firstUnseen: 0, secondUnseen: 2, firstItems: 2, secondItems: 0) == .first)
    }
}
