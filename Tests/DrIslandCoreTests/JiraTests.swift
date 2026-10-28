import Testing
import Foundation
@testable import DrIslandCore

@Suite struct JiraTests {
    private let site = URL(string: "https://acme.atlassian.net")!
    private let sample = """
    {"issues":[
      {"key":"ACME-1","fields":{"summary":"Fix login","status":{"name":"In Progress","statusCategory":{"key":"indeterminate"}},"priority":{"name":"High"}}},
      {"key":"ACME-2","fields":{"summary":"Write docs","status":{"name":"To Do","statusCategory":{"key":"new"}},"priority":null}},
      {"key":"ACME-3","fields":{"status":{"name":"To Do"}}}
    ]}
    """

    @Test func parsesTasks() throws {
        let tasks = try JiraParser.parseTasks(Data(sample.utf8), site: site)
        #expect(tasks.count == 2)  // the issue without a summary is skipped
        #expect(tasks[0].key == "ACME-1" && tasks[0].category == .inProgress && tasks[0].priority == "High")
        #expect(tasks[1].category == .todo && tasks[1].priority == nil)
        #expect(tasks[0].url.absoluteString == "https://acme.atlassian.net/browse/ACME-1")
    }

    @Test func invalidPayloadThrows() {
        #expect(throws: Error.self) { try JiraParser.parseTasks(Data(#"{"errorMessages":["x"]}"#.utf8), site: site) }
    }

    @Test func parsesDisplayName() throws {
        #expect(try JiraParser.parseDisplayName(Data(#"{"displayName":"Ana Silva"}"#.utf8)) == "Ana Silva")
    }

    @Test func normalizesSite() {
        #expect(JiraClient.normalizedSite("acme.atlassian.net")?.absoluteString == "https://acme.atlassian.net")
        #expect(JiraClient.normalizedSite("  https://acme.atlassian.net/jira/software  ")?.absoluteString == "https://acme.atlassian.net")
        #expect(JiraClient.normalizedSite("https://jira.corp.local:8443/")?.absoluteString == "https://jira.corp.local:8443")
        #expect(JiraClient.normalizedSite("http://acme.atlassian.net") == nil)   // never send the token over plain HTTP
        #expect(JiraClient.normalizedSite("") == nil)
        #expect(JiraClient.normalizedSite("localhost") == nil)
    }

    @Test func buildsSearchURL() throws {
        let url = try #require(JiraClient.searchURL(site: site, jql: "assignee = currentUser() ORDER BY updated", maxResults: 500))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(url.path == "/rest/api/3/search/jql")
        #expect(items.first { $0.name == "jql" }?.value == "assignee = currentUser() ORDER BY updated")
        #expect(items.first { $0.name == "maxResults" }?.value == "50")
    }

    @Test func basicAuthHeader() {
        #expect(JiraClient.authorizationHeader(email: "a@b.c", token: "tok") == "Basic " + Data("a@b.c:tok".utf8).base64EncodedString())
    }

    @Test func approverQueryIsSeparate() throws {
        let config = JiraConfig(site: "acme.atlassian.net", email: "a@b.c", token: "t")
        #expect(config.approverJQL.hasPrefix("cf[10127] = currentUser()"))
        #expect(config.approverJQL != config.jql)
        let url = try #require(JiraClient.searchURL(site: site, jql: config.approverJQL, maxResults: 8))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "jql" }?.value == config.approverJQL)
    }

    @Test func configCompleteness() {
        #expect(!JiraConfig(site: "acme.atlassian.net", email: "a@b.c", token: "").isComplete)
        #expect(JiraConfig(site: "acme.atlassian.net", email: "a@b.c", token: "t").isComplete)
    }
}
