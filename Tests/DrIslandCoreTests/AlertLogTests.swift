import Foundation
import Testing
@testable import DrIslandCore

@Suite struct AlertLogTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func change(_ kind: PRChange.Kind, _ id: String = "x") -> PRChange { PRChange(prID: id, ref: "r#1", title: "T", kind: kind) }

    @Test func oldEntriesGetTheirOriginWhenShown() {
        let old = AlertEntry(date: now, kind: .jiraComment, prID: "jira-A-1", ref: "A-1", message: "Novo comentário em A-1")
        let new = AlertEntry(change(.approved), date: now)
        #expect(old.displayMessage == "JIRA - Novo comentário em A-1")
        #expect(new.displayMessage == new.message && new.displayMessage.hasPrefix("GIT - "))
    }

    @Test func newestFirstAndFrozenMessage() {
        let first = AlertLog.appending([change(.ciFailed)], to: [], now: now)
        let second = AlertLog.appending([change(.approved)], to: first, now: now.addingTimeInterval(60))
        #expect(second.map(\.kind) == [.approved, .ciFailed])
        #expect(second.last?.message == "GIT - CI falhou: r#1")
    }

    @Test func repeatedAlertWithNothingBetweenIsNotLoggedTwice() {
        let first = AlertLog.appending([change(.conflicts)], to: [], now: now)
        let again = AlertLog.appending([change(.conflicts)], to: first, now: now.addingTimeInterval(3600))
        #expect(again.count == 1)
        let other = AlertLog.appending([change(.approved)], to: first, now: now.addingTimeInterval(60))
        #expect(AlertLog.appending([change(.conflicts)], to: other, now: now.addingTimeInterval(120)).count == 3)
        #expect(AlertLog.appending([change(.conflicts)], to: first, now: now.addingTimeInterval(13 * 3600)).count == 2)
    }

    @Test func dropsOldEntriesAndCaps() {
        let old = AlertEntry(date: now.addingTimeInterval(-31 * 86_400), kind: .ciFailed, prID: "a", ref: "r", message: "m")
        let kept = AlertLog.appending([change(.approved)], to: [old], now: now)
        #expect(kept.count == 1)
        var log: [AlertEntry] = []
        for i in 0..<(AlertLog.maxEntries + 20) { log = AlertLog.appending([change(.approved, "p\(i)")], to: log, now: now.addingTimeInterval(Double(i))) }
        #expect(log.count == AlertLog.maxEntries)
        #expect(log.first?.prID == "p\(AlertLog.maxEntries + 19)")
    }

    @Test func entriesOfRemovedKindsAreSkipped() {
        let valid = AlertLog.encode([AlertEntry(change(.merged), date: now)])
        let old = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"kind":"usageHigh","prID":"usage-sessão","ref":"Sessão","message":"x"}"#
        let mixed = "[" + old + "," + valid.dropFirst().dropLast() + "]"
        #expect(AlertLog.decode(mixed).map(\.kind) == [.merged])
    }

    @Test func sourcesAndTones() {
        #expect(AlertEntry(change(.mentioned), date: now).source == .pullRequests)
        #expect(AlertEntry(change(.jiraStatus), date: now).source == .jira)
        #expect(AlertEntry(change(.ciFailed), date: now).tone == .critical)
    }

    @Test func groupsByDayNewestFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let entries = [AlertEntry(date: now, kind: .approved, prID: "a", ref: "r", message: "1"),
                       AlertEntry(date: now.addingTimeInterval(-3600), kind: .approved, prID: "b", ref: "r", message: "2"),
                       AlertEntry(date: now.addingTimeInterval(-3 * 86_400), kind: .approved, prID: "c", ref: "r", message: "3")]
        let groups = AlertLog.groupedByDay(entries, calendar: calendar)
        #expect(groups.count == 2)
        #expect(groups[0].entries.map(\.message) == ["1", "2"])
        #expect(groups[1].entries.map(\.message) == ["3"])
    }

    @Test func roundTrip() {
        let log = AlertLog.appending([change(.merged)], to: [], now: now)
        #expect(AlertLog.decode(AlertLog.encode(log)) == log)
        #expect(AlertLog.decode("junk").isEmpty)
    }
}
