import Foundation
import DrIslandCore

extension AlertEntry {
    /// The PR's page, or the Jira task's, when the entry points at one.
    var destination: URL? {
        switch source {
        case .pullRequests: return prID.hasPrefix("http") ? URL(string: prID) : nil
        case .jira:
            guard prID.hasPrefix("jira-"), let site = JiraClient.normalizedSite(UserDefaults.standard.string(forKey: SettingsKey.jiraSite) ?? "") else { return nil }
            return site.appendingPathComponent("browse/" + prID.dropFirst("jira-".count))
        }
    }
}
