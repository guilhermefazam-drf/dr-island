import Foundation

/// The short mark shown before a row to say whose it is: "eu" for the user, the initials for anyone else.
public enum Owner {
    public static let me = "eu"

    /// "Luís Pedro Costa" → "LC" (first and last name); a single word such as a login → its first two letters.
    public static func initials(_ name: String?) -> String? {
        let words = (name ?? "").split(whereSeparator: { $0.isWhitespace })
        guard let first = words.first else { return nil }
        if words.count == 1 { return String(first.filter(\.isLetter).prefix(2)).uppercased() }
        return [first, words[words.count - 1]].compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }

    public static func label(name: String?, isMine: Bool) -> String? { isMine ? me : initials(name) }
}
