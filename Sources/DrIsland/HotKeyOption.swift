import Carbon.HIToolbox
import Foundation

/// The global shortcut that opens and closes the island. Carbon hot keys need no Accessibility permission.
enum HotKeyOption: String, CaseIterable {
    case off, ctrlOptI, ctrlOptSpace, optCmdI

    static let `default`: HotKeyOption = .ctrlOptI

    var title: String {
        switch self {
        case .off: return "Desligado"
        case .ctrlOptI: return "⌃⌥I"
        case .ctrlOptSpace: return "⌃⌥Espaço"
        case .optCmdI: return "⌥⌘I"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .off: return 0
        case .ctrlOptI, .optCmdI: return UInt32(kVK_ANSI_I)
        case .ctrlOptSpace: return UInt32(kVK_Space)
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .off: return 0
        case .ctrlOptI, .ctrlOptSpace: return UInt32(controlKey | optionKey)
        case .optCmdI: return UInt32(optionKey | cmdKey)
        }
    }
}
