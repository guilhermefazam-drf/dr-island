import ServiceManagement
import SwiftUI
import DrIslandCore

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, appearance, content, layout, claude, cost, github, jira, shortcuts, focus, alerts, events, day, history, log, about

    var id: String { rawValue }
    /// UserDefaults key that asks the next settings window to open on a given page.
    static let pendingKey = "settingsPagePending"

    enum Group: String, CaseIterable, Identifiable {
        case island, sources, tools, interaction, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .island: return "Ilha"
            case .sources: return "Fontes"
            case .tools: return "Ferramentas"
            case .interaction: return "Interação"
            case .about: return "Dr Island"
            }
        }
    }

    var group: Group {
        switch self {
        case .general, .appearance, .content, .layout: return .island
        case .claude, .cost, .github, .jira: return .sources
        case .shortcuts, .focus: return .tools
        case .alerts, .events, .day, .history: return .interaction
        case .log: return .about
        case .about: return .about
        }
    }

    var title: String {
        switch self {
        case .general: return "Geral"
        case .appearance: return "Aparência"
        case .content: return "Conteúdo"
        case .layout: return "Layout"
        case .claude: return "Claude"
        case .cost: return "Custo"
        case .github: return "GitHub"
        case .jira: return "Jira"
        case .shortcuts: return "Atalhos"
        case .focus: return "Foco"
        case .alerts: return "Avisos"
        case .events: return "O que avisar"
        case .day: return "Dia"
        case .history: return "Histórico"
        case .log: return "Registo de erros"
        case .about: return "Acerca"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .content: return "rectangle.3.group"
        case .layout: return "rectangle.split.3x1"
        case .claude: return "gauge.with.dots.needle.50percent"
        case .cost: return "dollarsign.circle"
        case .github: return "arrow.triangle.pull"
        case .jira: return "checklist"
        case .shortcuts: return "square.grid.2x2"
        case .focus: return "timer"
        case .alerts: return "bell.badge"
        case .events: return "list.bullet.rectangle"
        case .day: return "chart.xyaxis.line"
        case .history: return "clock.arrow.circlepath"
        case .log: return "exclamationmark.triangle"
        case .about: return "info.circle"
        }
    }
}
