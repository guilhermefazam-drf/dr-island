import Testing
@testable import DrIslandCore

@Suite struct AvatarColorTests {
    @Test func sameNameAlwaysGetsSameSlot() {
        let a = AvatarColor.index(for: "Luís Pedro Bettencourt", count: 6)
        #expect(AvatarColor.index(for: "Luís Pedro Bettencourt", count: 6) == a)
        #expect(AvatarColor.index(for: "  luís pedro bettencourt ", count: 6) == a)
    }

    @Test func slotIsAlwaysInRange() {
        for name in ["Ana", "Sónia Silva", "Tassio Lima", "luisinhoc", "x", "🙂"] {
            let i = AvatarColor.index(for: name, count: 5)
            #expect((0..<5).contains(i), "\(name)")
        }
    }

    @Test func emptyNameOrNoColoursIsZero() {
        #expect(AvatarColor.index(for: "", count: 6) == 0)
        #expect(AvatarColor.index(for: "Ana", count: 0) == 0)
    }
}
