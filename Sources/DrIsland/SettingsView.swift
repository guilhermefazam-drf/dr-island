import ServiceManagement
import SwiftUI
import DrIslandCore

/// The settings window: a sidebar with the pages grouped by what they are about, and the page on the right.
struct SettingsView: View {
    let costStore: CostStore
    @State private var page: SettingsPage = {
        let pending = UserDefaults.standard.string(forKey: SettingsPage.pendingKey).flatMap(SettingsPage.init(rawValue:))
        UserDefaults.standard.removeObject(forKey: SettingsPage.pendingKey)
        return pending ?? .general
    }()

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                ForEach(SettingsPage.Group.allCases) { group in
                    Section(group.title) {
                        ForEach(SettingsPage.allCases.filter { $0.group == group }) { page in
                            Label(page.title, systemImage: page.icon).tag(page)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
            .safeAreaInset(edge: .bottom) {
                Text("Dr Island \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.caption2).foregroundStyle(.tertiary).padding(.vertical, 8)
            }
        } detail: {
            detail.navigationTitle(page.title)
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 480, idealHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .showSettingsPage)) { note in
            if let raw = note.object as? String, let target = SettingsPage(rawValue: raw) { page = target }
        }
    }

    @ViewBuilder private var detail: some View {
        switch page {
        case .general: GeneralPage()
        case .appearance: AppearancePage()
        case .content: ContentPage()
        case .layout: LayoutPage()
        case .claude: ClaudePage()
        case .cost: CostPage(costStore: costStore)
        case .github: GitHubPage()
        case .jira: JiraPage()
        case .shortcuts: ShortcutsPage()
        case .alerts: AlertsPage()
        case .events: EventsPage()
        case .day: DayPage()
        case .history: HistoryPage()
        case .log: LogPage()
        case .focus: FocusPage()
        case .about: AboutPage()
        }
    }
}
