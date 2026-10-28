import Foundation
import Testing
@testable import DrIslandCore

@Suite struct QuietHoursTests {
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    @Test func sameDayWindow() {
        #expect(QuietHours.isQuiet(now: at(10), startMinute: 9 * 60, endMinute: 12 * 60))
        #expect(!QuietHours.isQuiet(now: at(12), startMinute: 9 * 60, endMinute: 12 * 60))
        #expect(!QuietHours.isQuiet(now: at(8, 59), startMinute: 9 * 60, endMinute: 12 * 60))
    }

    @Test func overnightWindow() {
        #expect(QuietHours.isQuiet(now: at(23), startMinute: 22 * 60, endMinute: 8 * 60))
        #expect(QuietHours.isQuiet(now: at(7, 30), startMinute: 22 * 60, endMinute: 8 * 60))
        #expect(!QuietHours.isQuiet(now: at(8), startMinute: 22 * 60, endMinute: 8 * 60))
        #expect(!QuietHours.isQuiet(now: at(15), startMinute: 22 * 60, endMinute: 8 * 60))
    }

    @Test func equalBoundsMeanNoWindow() {
        #expect(!QuietHours.isQuiet(now: at(10), startMinute: 600, endMinute: 600))
    }

    @Test func focusAssertions() {
        let on = #"{"data":[{"storeAssertionRecords":[{"x":1}]}]}"#.data(using: .utf8)!
        let off = #"{"data":[{"storeAssertionRecords":[]}]}"#.data(using: .utf8)!
        #expect(QuietHours.focusIsActive(assertionsJSON: on))
        #expect(!QuietHours.focusIsActive(assertionsJSON: off))
        #expect(!QuietHours.focusIsActive(assertionsJSON: Data("junk".utf8)))
    }
}
