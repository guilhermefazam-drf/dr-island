import Foundation

/// A stable colour slot for a person's avatar, so the same name always gets the same colour.
public enum AvatarColor {
    /// 0..<count from the name's letters (case and surrounding spaces ignored); 0 for an empty name.
    public static func index(for name: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sum = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return sum % count
    }
}
