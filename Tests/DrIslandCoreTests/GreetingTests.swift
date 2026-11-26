import Foundation
import Testing
@testable import DrIslandCore

@Suite struct GreetingTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: hour, minute: minute))!
    }

    @Test func greetingChangesAtTheBoundaries() {
        #expect(Greeting.text(for: at(4, 59), calendar: calendar) == "Boa noite")
        #expect(Greeting.text(for: at(5), calendar: calendar) == "Bom dia")
        #expect(Greeting.text(for: at(11, 59), calendar: calendar) == "Bom dia")
        #expect(Greeting.text(for: at(12), calendar: calendar) == "Boa tarde")
        #expect(Greeting.text(for: at(19, 59), calendar: calendar) == "Boa tarde")
        #expect(Greeting.text(for: at(20), calendar: calendar) == "Boa noite")
        #expect(Greeting.text(for: at(0), calendar: calendar) == "Boa noite")
    }
}
