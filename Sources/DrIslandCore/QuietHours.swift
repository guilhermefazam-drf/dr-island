import Foundation

/// When sound and system notifications should stay silent.
public enum QuietHours {
    /// `startMinute`/`endMinute` are minutes since midnight. A window that ends before it starts crosses midnight
    /// (22:00–08:00); equal values mean no window.
    public static func isQuiet(now: Date, startMinute: Int, endMinute: Int, calendar: Calendar = .current) -> Bool {
        guard startMinute != endMinute else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return startMinute < endMinute ? (minute >= startMinute && minute < endMinute) : (minute >= startMinute || minute < endMinute)
    }

    /// Reads macOS's `~/Library/DoNotDisturb/DB/Assertions.json`: a Focus is on while it holds an assertion record.
    /// (The file needs Full Disk Access; without it the caller simply never sees Focus as active.)
    public static func focusIsActive(assertionsJSON: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: assertionsJSON) as? [String: Any],
              let entries = root["data"] as? [[String: Any]] else { return false }
        return entries.contains { ($0["storeAssertionRecords"] as? [Any])?.isEmpty == false }
    }
}
