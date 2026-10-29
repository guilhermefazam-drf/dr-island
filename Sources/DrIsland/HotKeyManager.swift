import Carbon.HIToolbox
import Foundation

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
