import Foundation

/// The words under the burndown: how much is done, what is blocked and how the deadline stands. Pure, so it can be tested.
public enum BurndownSummary {
    public enum Deadline: Equatable, Sendable { case closed, overdue, today, days(Int) }

    public static func doneText(_ result: BurndownResult) -> String {
        "\(Int((result.doneShare * 100).rounded()))% concluído"
    }

    public static func flaggedText(_ result: BurndownResult) -> String {
        result.flaggedOpen == 1 ? "1 bloqueada" : "\(result.flaggedOpen) bloqueadas"
    }

    public static func missingPointsText(_ result: BurndownResult) -> String {
        "\(result.missingPointsCount) de \(result.memberCount) tasks sem pontos"
    }

    /// Core's `isOverdue` is instant-based; «fora de prazo» only once the end day itself is over.
    public static func deadline(_ result: BurndownResult, closed: Bool, sprintEnd: Date?, now: Date, calendar: Calendar) -> Deadline {
        if closed { return .closed }
        let pastEndDay = sprintEnd.map { calendar.startOfDay(for: now) > calendar.startOfDay(for: $0) } ?? result.isOverdue
        if result.isOverdue && pastEndDay { return .overdue }
        return result.daysLeft == 0 ? .today : .days(result.daysLeft)
    }

    public static func text(_ deadline: Deadline) -> String {
        switch deadline {
        case .closed: return "fechada"
        case .overdue: return "fora de prazo"
        case .today: return "acaba hoje"
        case .days(1): return "acaba em 1 dia"
        case .days(let n): return "acaba em \(n) dias"
        }
    }
}
