import Foundation

/// The island header's greeting for the time of day.
public enum Greeting {
    /// 05:00–11:59 «Bom dia», 12:00–19:59 «Boa tarde», otherwise «Boa noite».
    public static func text(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Bom dia"
        case 12..<20: "Boa tarde"
        default: "Boa noite"
        }
    }
}
