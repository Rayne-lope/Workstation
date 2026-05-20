import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@Suite("LocalAIService")
struct LocalAIServiceTests {
    @Test("buildRequest routes supported actions to the right model tier")
    func buildRequestRoutesActions() throws {
        let settings = LocalAISettings(
            isEnabled: true,
            baseURL: "http://localhost:11434",
            fastModel: "fast-model",
            strongModel: "strong-model"
        )
        let issue = makeIssue()
        let run = makeRun()
        let service = LocalAIService(provider: RecordingProvider())

        let issueRequest = try service.buildRequest(for: .issueDrafting(issue: issue), settings: settings)
        #expect(issueRequest.model == "strong-model")
        #expect(issueRequest.prompt.contains("Draft a concise issue refinement"))
        #expect(issueRequest.system?.contains("Return plain text only") == true)

        let backlogRequest = try service.buildRequest(for: .backlogAnalysis(issues: [issue]), settings: settings)
        #expect(backlogRequest.model == "strong-model")
        #expect(backlogRequest.prompt.contains("Analyze the provided Beads backlog issues"))
        #expect(backlogRequest.prompt.contains("Build the login flow"))
        #expect(backlogRequest.prompt.contains("split candidates"))
        #expect(backlogRequest.prompt.contains("issues that should be refined"))

        let promptRequest = try service.buildRequest(
            for: .promptOptimization(prompt: "Make this shorter"),
            settings: settings
        )
        #expect(promptRequest.model == "fast-model")
        #expect(promptRequest.prompt.contains("Improve the following prompt"))
        #expect(promptRequest.prompt.contains("Make this shorter"))

        let closeRequest = try service.buildRequest(
            for: .closeReason(issue: issue, summary: "Implemented login validation."),
            settings: settings
        )
        #expect(closeRequest.model == "fast-model")
        #expect(closeRequest.prompt.contains("Draft a concise close reason"))
        #expect(closeRequest.prompt.contains("Implemented login validation."))

        let summaryRequest = try service.buildRequest(for: .runSummary(record: run), settings: settings)
        #expect(summaryRequest.model == "strong-model")
        #expect(summaryRequest.prompt.contains("Summarize the following agent run"))
        #expect(summaryRequest.prompt.contains("worktree focus"))
    }

    @Test("generate sends a non-streaming Ollama request and returns the text response")
    func generateSendsRequest() async throws {
        let settings = LocalAISettings(
            isEnabled: true,
            baseURL: "http://localhost:11434",
            fastModel: "fast-model",
            strongModel: "strong-model"
        )
        let issue = makeIssue()
        let provider = OllamaService(session: StubURLSession { request in
            #expect(request.url?.absoluteString == "http://localhost:11434/api/generate")
            #expect(request.httpMethod == "POST")

            let body = try #require(request.httpBody)
            let payload = try JSONDecoder().decode(RequestBody.self, from: body)
            #expect(payload.model == "strong-model")
            #expect(payload.prompt.contains(issue.title))
            #expect(payload.system?.contains("local AI assistant") == true)
            #expect(payload.stream == false)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Data(#"{"response":"preview text","done":true}"#.utf8), response)
        })
        let service = LocalAIService(provider: provider)

        let text = try await service.generate(for: .issueDrafting(issue: issue), settings: settings)
        #expect(text == "preview text")
    }

    @Test("generate surfaces Ollama errors cleanly")
    func generateSurfacesErrors() async throws {
        let settings = LocalAISettings(isEnabled: true)
        let provider = OllamaService(session: StubURLSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(#"{"error":"model unavailable"}"#.utf8), response)
        })
        let service = LocalAIService(provider: provider)

        await #expect(throws: OllamaServiceError.self) {
            _ = try await service.generate(for: .promptOptimization(prompt: "shorten this"), settings: settings)
        }
    }

    @Test("buildRequest rejects disabled settings before calling the provider")
    func buildRequestRejectsDisabledSettings() throws {
        let service = LocalAIService(provider: RecordingProvider())

        #expect(throws: LocalAIServiceError.self) {
            _ = try service.buildRequest(
                for: .promptOptimization(prompt: "shorten this"),
                settings: LocalAISettings()
            )
        }
    }
}

private struct RecordingProvider: LocalAIProviding {
    func generate(request: LocalAIRequest) async throws -> String {
        "recorded"
    }
}

private struct StubURLSession: URLSessioning {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

private struct RequestBody: Decodable {
    let model: String
    let prompt: String
    let system: String?
    let stream: Bool
}

private func makeIssue() -> BeadIssue {
    BeadIssue(
        id: "bd-101",
        title: "Build the login flow",
        status: "open",
        priority: 1,
        issueType: "feature",
        description: "Create the first pass of login and session restore.",
        acceptanceCriteria: "User can sign in.\nUser stays signed in.",
        notes: "Keep this scoped to local auth.",
        labels: ["backend", "auth"],
        assignee: "codex",
        blockedBy: ["bd-50"]
    )
}

private func makeRun() -> AgentRunRecord {
    AgentRunRecord(
        issueID: "bd-204",
        issueTitle: "Tune worktree focus",
        agentProfileID: nil,
        agentName: "Codex",
        command: "codex --dangerously-skip-permissions",
        prompt: "Tune worktree focus",
        projectPath: "/Users/apple/Programming/Projects/Personal/Workstation",
        startedAt: Date(timeIntervalSince1970: 1_000),
        completedAt: Date(timeIntervalSince1970: 1_500),
        status: .accepted,
        notes: "Adjusted the focus heuristic."
    )
}
