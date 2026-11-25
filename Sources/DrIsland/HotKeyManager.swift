import Carbon.HIToolbox
import Foundation
import DrIslandCore

extension Notification.Name {
    static let islandHotKey = Notification.Name("islandHotKey")
    /// The shortcut that switches the island between Normal and Compacto.
    static let islandDensityHotKey = Notification.Name("islandDensityHotKey")
}

/// Registers the two global shortcuts: id 1 opens and closes the island, id 2 toggles its size.
@MainActor
final class HotKeyManager {
    nonisolated private static let signature = OSType(0x54494C44)
    nonisolated private static let toggleID: UInt32 = 1
    nonisolated private static let densityID: UInt32 = 2

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var current: [UInt32: HotKeyOption] = [:]
    private var handler: EventHandlerRef?

    func start() {
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let name: Notification.Name = status == noErr && id.id == HotKeyManager.densityID ? .islandDensityHotKey : .islandHotKey
            DispatchQueue.main.async { NotificationCenter.default.post(name: name, object: nil) }
            return noErr
        }, 1, [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))], nil, &handler)
        apply()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply() }
        }
        NotificationCenter.default.addObserver(forName: .islandDensityHotKey, object: nil, queue: .main) { _ in
            let defaults = UserDefaults.standard
            let next: IslandDensity = IslandDensity(stored: defaults.string(forKey: SettingsKey.islandDensity)) == .compact ? .regular : .compact
            defaults.set(next.rawValue, forKey: SettingsKey.islandDensity)
        }
    }

    private func apply() {
        let defaults = UserDefaults.standard
        let toggle = HotKeyOption(rawValue: defaults.string(forKey: SettingsKey.hotKey) ?? "") ?? .default
        var density = HotKeyOption(rawValue: defaults.string(forKey: SettingsKey.densityHotKey) ?? "") ?? .off
        // One key combination can only do one thing; the main shortcut wins.
        if density == toggle { density = .off }
        register(toggle, id: Self.toggleID)
        register(density, id: Self.densityID)
    }

    private func register(_ option: HotKeyOption, id: UInt32) {
        guard option != current[id] else { return }
        current[id] = option
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        guard option != .off else { return }
        var ref: EventHotKeyRef?
        RegisterEventHotKey(option.keyCode, option.modifiers, EventHotKeyID(signature: Self.signature, id: id),
                            GetApplicationEventTarget(), 0, &ref)
        if let ref { refs[id] = ref }
    }
}
