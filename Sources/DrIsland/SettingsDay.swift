import AppKit
import SwiftUI
import DrIslandCore

// MARK: - Dia

/// A day in full: the events-per-hour chart, a few numbers, and every event in order. The island shows the same chart small.
struct DayPage: View {
    @AppStorage(SettingsKey.alertHistory) private var json = "[]"
    @State private var daysBack = 0

    private static let daysShown = 7
    private var calendar: Calendar { .current }
    private var day: Date { calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: Date())) ?? Date() }
    private var isToday: Bool { daysBack == 0 }

    var body: some View {
        let all = AlertLog.decode(json)
        let entries = DayBriefing.timeline(all, now: day)
        let counts = DayBriefing.hourly(all, day: day)
        let range = DayBriefing.hourRange(counts, endHour: isToday ? calendar.component(.hour, from: Date()) : 23)
        Form {
            Section {
                Picker("Dia", selection: $daysBack) {
                    ForEach(0..<Self.daysShown, id: \.self) { Text(label(for: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Mostra o que a ilha registou: avisos de PRs e Jira, dos últimos 30 dias (até 300).")
            }
            Section("Eventos por hora") {
                HourlyLineChart(counts: counts, range: range, nowHour: isToday ? calendar.component(.hour, from: Date()) : nil, height: 150, labelStride: 2)
                    .padding(.vertical, 6)
                    .overlay { if entries.isEmpty { Text("Sem eventos neste dia").foregroundStyle(.secondary).padding(.bottom, 16) } }
            }
            if !entries.isEmpty {
                Section("Em números") {
                    LabeledContent("Eventos", value: "\(entries.count)")
                    LabeledContent("Por fonte", value: DayBriefing.summary(entries))
                    if let peak = DayBriefing.peakHour(counts) {
                        LabeledContent("Hora mais ativa", value: "\(Self.twoDigits(peak))h–\(Self.twoDigits((peak + 1) % 24))h · \(counts[peak])")
                    }
                    if let first = entries.first, let last = entries.last {
                        LabeledContent("Primeiro evento", value: first.date.formatted(date: .omitted, time: .shortened))
                        LabeledContent("Último evento", value: last.date.formatted(date: .omitted, time: .shortened))
                    }
                }
                Section("Todos os eventos") {
                    ForEach(entries) { row($0) }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// "07", "13": hours on the clock.
    private static func twoDigits(_ hour: Int) -> String { hour.formatted(.number.precision(.integerLength(2))) }

    private func label(for back: Int) -> String {
        switch back {
        case 0: return "Hoje"
        case 1: return "Ontem"
        default:
            let date = calendar.date(byAdding: .day, value: -back, to: Date()) ?? Date()
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    private func row(_ entry: AlertEntry) -> some View {
        HStack(spacing: 10) {
            Circle().fill(entry.tone.color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayMessage)
                Text("\(entry.source.title) · \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let url = entry.destination { Button("Abrir") { NSWorkspace.shared.open(url) } }
        }
    }
}
