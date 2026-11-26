import AppKit
import SwiftUI
import DrIslandCore

/// The width of the key column («TEP-52», «#2595») in list rows, so titles line up whatever the key's length.
/// A card sets the longest key it can show (in characters); keys are monospaced, so that fixes the width.
enum ListKeyColumn {
    /// The column for keys of up to `characters` characters, in the row's key font.
    static func width(characters: Int, metrics: IslandMetrics) -> CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(metrics.metaSize), weight: .medium)
        let advance = ("0" as NSString).size(withAttributes: [.font: font]).width
        return ceil(advance * CGFloat(max(characters, 0)))
    }

    /// The longest key among `keys`, in characters (0 when there are none).
    static func longest<S: Sequence>(_ keys: S) -> Int where S.Element == String {
        keys.reduce(0) { max($0, $1.count) }
    }
}

private struct ListKeyCharactersKey: EnvironmentKey { static let defaultValue: Int? = nil }

extension EnvironmentValues {
    /// The longest key a card's rows can show; nil lets each key take its own width.
    var listKeyCharacters: Int? {
        get { self[ListKeyCharactersKey.self] }
        set { self[ListKeyCharactersKey.self] = newValue }
    }
}
