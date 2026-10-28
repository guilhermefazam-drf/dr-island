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

    fileprivate var keyCode: UInt32 {
        switch self {
        case .off: return 0
        case .ctrlOptI, .optCmdI: return UInt32(kVK_ANSI_I)
        case .ctrlOptSpace: return UInt32(kVK_Space)
        }
    }

    fileprivate var modifiers: UInt32 {
        switch self {
        case .off: return 0
        case .ctrlOptI, .ctrlOptSpace: return UInt32(controlKey | optionKey)
        case .optCmdI: return UInt32(optionKey | cmdKey)
        }
    }
}

extension Notification.Name {
    static let islandHotKey = Notification.Name("islandHotKey")
}

@MainActor
final class HotKeyManager {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current: HotKeyOption = .off

    func start() {
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { NotificationCenter.default.post(name: .islandHotKey, object: nil) }
            return noErr
        }, 1, [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))], nil, &handler)
        apply()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply() }
        }
    }

    private func apply() {
        let option = HotKeyOption(rawValue: UserDefaults.standard.string(forKey: SettingsKey.hotKey) ?? "") ?? .default
        guard option != current else { return }
        current = option
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        guard option != .off else { return }
        RegisterEventHotKey(option.keyCode, option.modifiers, EventHotKeyID(signature: OSType(0x54494C44), id: 1),
                            GetApplicationEventTarget(), 0, &ref)
    }
}
