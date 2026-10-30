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

    @Test func readsTheIssueType() throws {
        let json = #"{"issues":[{"key":"A-1","fields":{"summary":"x","status":{"name":"To Do"},"issuetype":{"name":"Bug"}}},{"key":"A-2","fields":{"summary":"y","status":{"name":"To Do"}}}]}"#
        let tasks = try JiraParser.parseTasks(Data(json.utf8), site: site)
        #expect(tasks[0].issueType == "Bug" && tasks[0].kind == .bug)
        #expect(tasks[1].issueType == nil && tasks[1].kind == .other)
    }

    @Test(arguments: [("Bug", JiraIssueKind.bug), ("ERRO", .bug), ("Problema", .bug), ("Story", .feature), ("Funcionalidade", .feature), ("História", .feature),
                      ("Melhoria", .feature), ("Task", .task), ("Tarefa", .task), ("Sub-task", .subtask), ("Subtarefa", .subtask),
                      ("Epic", .epic), ("Pedido", .other)])
    func classifiesIssueTypes(name: String, kind: JiraIssueKind) {
        #expect(JiraIssueKind(typeName: name) == kind)
    }

    @Test func readsFlaggedField() throws {
        let json = #"{"issues":[{"key":"A-1","fields":{"summary":"x","customfield_10006":[{"value":"Impediment"}]}},{"key":"A-2","fields":{"summary":"y","customfield_10021":null}}]}"#
        let tasks = try JiraParser.parseTasks(Data(json.utf8), site: site)
        #expect(tasks.map(\.isFlagged) == [true, false])
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

@Suite struct SprintTasksTests {
    private func task(_ key: String, owner: String, inProgress: Bool = false) -> JiraTask {
        JiraTask(key: key, summary: key, status: "x", category: inProgress ? .inProgress : .todo, priority: nil,
                 url: URL(string: "https://x.atlassian.net/browse/\(key)")!, assignee: owner)
    }

    @Test func myTasksComeBeforeTheOnesHandedOn() {
        let tasks = [task("A-1", owner: "Rui", inProgress: true), task("A-2", owner: "Ana"), task("A-3", owner: "Ana", inProgress: true)]
        #expect(JiraOrder.sprintSorted(tasks, me: "Ana").map(\.key) == ["A-3", "A-2", "A-1"])
    }

    @Test func queryKeepsTasksAfterTheyChangeOwner() {
        #expect(JiraClient.sprintTasksJQL(field: nil, sprintIDs: [1]).contains("assignee was currentUser()"))
    }

    @Test func sprintFieldIsNamedByIdWhenTheSiteHasTwoSprintFields() {
        #expect(SprintJQL.field("customfield_10000") == "cf[10000]")
        #expect(SprintJQL.field(nil) == "sprint")
        #expect(JiraClient.sprintTasksJQL(field: "customfield_10000", sprintIDs: [7648]).hasPrefix("cf[10000] in (7648)"))
        #expect(Backlog.defaultJQL(project: "TEP", sprintField: "customfield_10000").contains("cf[10000] in futureSprints()"))
    }
}

@Suite struct JiraReadOnlyTests {
    private func request(_ method: String, body: Bool = false) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://x.atlassian.net/rest/api/3/issue/A-1")!)
        request.httpMethod = method
        if body { request.httpBody = Data("{}".utf8) }
        return request
    }

    @Test func readsPass() throws {
        try JiraClient.requireReadOnly(request("GET"))
        try JiraClient.requireReadOnly(request("HEAD"))
    }

    @Test(arguments: ["POST", "PUT", "PATCH", "DELETE"])
    func writesAreRefused(method: String) {
        #expect(throws: JiraError.readOnly) { try JiraClient.requireReadOnly(request(method)) }
    }

    @Test func aBodyIsRefusedEvenOnGet() {
        #expect(throws: JiraError.readOnly) { try JiraClient.requireReadOnly(request("GET", body: true)) }
    }
}
