import SwiftUI
import DrIslandCore

struct HistoryPage: View {
    @AppStorage(SettingsKey.alertHistory) private var json = "[]"
    @State private var source: AlertEntry.Source?
    @State private var confirmClear = false

    private var entries: [AlertEntry] {
        AlertLog.decode(json).filter { source == nil || $0.source == source }
    }

    var body: some View {
        Form {
            Section {
                Picker("Mostrar", selection: $source) {
                    Text("Tudo").tag(AlertEntry.Source?.none)
                    ForEach(AlertEntry.Source.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Guarda os avisos dos últimos 30 dias (até 300), mesmo os que chegaram com o som e as notificações desligados ou durante o «Não incomodar».")
            }
            let groups = AlertLog.groupedByDay(entries)
            if groups.isEmpty {
                Section { Text("Ainda não há avisos.").foregroundStyle(.secondary) }
            }
            ForEach(groups, id: \.day) { group in
                Section(dayTitle(group.day)) {
                    ForEach(group.entries) { entry in row(entry) }
                }
            }
            if !AlertLog.decode(json).isEmpty {
                Section {
                    Button("Limpar histórico…", role: .destructive) { confirmClear = true }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Apagar todo o histórico de avisos?", isPresented: $confirmClear) {
            Button("Apagar", role: .destructive) { json = "[]" }
        }
    }

    private func row(_ entry: AlertEntry) -> some View {
        let url = entry.destination
        return HStack(spacing: 10) {
            Circle().fill(entry.tone.color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayMessage)
                Text("\(entry.source.title) · \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let url { Button("Abrir") { NSWorkspace.shared.open(url) } }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Hoje" }
        if Calendar.current.isDateInYesterday(day) { return "Ontem" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
