import SwiftUI
import DrIslandCore

/// The flow card's three status groups (to do, in progress, done), with what sits in each and the typical stay.
struct FlowGroup: Identifiable {
    let id: String
    let name: String
    let amount: Double
    /// The mean of the group's statuses' median stays, in days; nil when none has a finished stay.
    let days: Double?

    static let order: [(category: String, name: String)] = [("new", "Por fazer"), ("indeterminate", "Em curso"), ("done", "Concluído")]

    static func groups(_ rows: [FlowStatusRow]) -> [FlowGroup] {
        order.map { group in
            let inGroup = rows.filter { $0.category == group.category }
            let stays = inGroup.compactMap(\.medianDays)
            return FlowGroup(id: group.category, name: group.name, amount: inGroup.map(\.amount).reduce(0, +),
                             days: stays.isEmpty ? nil : stays.reduce(0, +) / Double(stays.count))
        }
    }

    func color(_ palette: IslandPalette) -> Color {
        switch id {
        case "done": Color(palette.green)
        case "indeterminate": Color(palette.accent)
        default: Color(palette.surfaceRaised)
        }
    }

    /// The swatch in the key: the to-do group's fill is too faint to read as a colour on its own.
    func keyColor(_ palette: IslandPalette) -> Color { id == "new" ? Color(palette.textTertiary) : color(palette) }

    /// Text set inside the group's block: dark on the bright fills of the dark themes, white on the light theme's.
    func ink(_ palette: IslandPalette) -> Color {
        if id == "new" { return Color(palette.text) }
        return palette.isLight ? .white : Color(red: 0.04, green: 0.05, blue: 0.06)
    }
}
