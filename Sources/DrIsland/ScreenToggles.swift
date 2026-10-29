import ServiceManagement
import SwiftUI
import DrIslandCore

/// One switch per connected display.
struct ScreenToggles: View {
    @AppStorage(SettingsKey.disabledScreens) private var disabled = ""
    @State private var screens = NSScreen.screens

    var body: some View {
        ForEach(screens, id: \.stableID) { screen in
            let id = screen.stableID
            ToggleRow(screen.localizedName, detail: screen.safeAreaInsets.top > 0 ? "Com notch" : "Sem notch (pílula)", isOn: Binding(
                get: { !disabled.split(separator: ",").contains(Substring(id)) },
                set: { on in
                    var set = Set(disabled.split(separator: ",").map(String.init))
                    if on { set.remove(id) } else { set.insert(id) }
                    disabled = set.sorted().joined(separator: ",")
                }))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }
}
