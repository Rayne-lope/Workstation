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

        let simplifyRequest = try service.buildRequest(
            for: .simplifyIssueIndonesian(issue: issue),
            settings: settings
        )
        #expect(simplifyRequest.model == "strong-model")
        #expect(simplifyRequest.prompt.contains("Bahasa Indonesia"))
        #expect(simplifyRequest.prompt.contains(issue.title))
        #expect(simplifyRequest.prompt.contains("read-only"))

        let roughIdeaRequest = try service.buildRequest(
            for: .detailIssueFromRoughIdea(roughIdea: "Let users turn a rough idea into a draft"),
            settings: settings
        )
        #expect(roughIdeaRequest.model == "strong-model")
        #expect(roughIdeaRequest.prompt.contains("Return a single JSON object only"))
        #expect(roughIdeaRequest.prompt.contains("rough idea"))

        let prdRequest = try service.buildRequest(
            for: .draftIssuesFromPRD(prd: "Build a PRD import flow with draft review"),
            settings: settings
        )
        #expect(prdRequest.model == "strong-model")
        #expect(prdRequest.prompt.contains("Return a JSON array only"))
        #expect(prdRequest.prompt.contains("dependency_suggestions"))
        #expect(prdRequest.prompt.contains("reason"))

        let copilotRequest = try service.buildRequest(
            for: .copilot(prompt: "What should I do next?", contextIssues: [issue]),
            settings: settings
        )
        #expect(copilotRequest.model == "strong-model")
        #expect(copilotRequest.prompt.contains("Workflow Copilot request"))
        #expect(copilotRequest.prompt.contains("What should I do next?"))
        #expect(copilotRequest.prompt.contains(issue.id))
    }

    @Test("buildRequest includes API key for Gemini-backed Copilot actions")
    func buildRequestIncludesGeminiAPIKey() throws {
        let settings = LocalAISettings(
            isEnabled: true,
            provider: .gemini,
            baseURL: LocalAISettings.defaultGeminiBaseURL,
            fastModel: LocalAISettings.defaultGeminiModel,
            strongModel: LocalAISettings.defaultGeminiModel,
            apiKey: " test-key "
        )
        let service = LocalAIService(provider: RecordingProvider())

        let request = try service.buildRequest(
            for: .copilot(prompt: "Summarize selected issues", contextIssues: [makeIssue()]),
            settings: settings,
            stream: true
        )

        #expect(request.baseURL.absoluteString == LocalAISettings.defaultGeminiBaseURL)
        #expect(request.model == LocalAISettings.defaultGeminiModel)
        #expect(request.apiKey == "test-key")
        #expect(request.stream)
    }

    @Test("buildRequest rejects Gemini without an API key")
    func buildRequestRejectsGeminiWithoutAPIKey() throws {
        let settings = LocalAISettings(
            isEnabled: true,
            provider: .gemini,
            baseURL: LocalAISettings.defaultGeminiBaseURL,
            fastModel: LocalAISettings.defaultGeminiModel,
            strongModel: LocalAISettings.defaultGeminiModel
        )
        let service = LocalAIService(provider: RecordingProvider())

        #expect(throws: LocalAIServiceError.self) {
            _ = try service.buildRequest(
                for: .draftIssuesFromPRD(prd: "A PRD"),
                settings: settings
            )
        }
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

    @Test("Gemini service sends API key header and decodes generated text")
    func geminiGenerateSendsAPIKey() async throws {
        let provider = GeminiService(session: StubURLSession { request in
            #expect(request.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "secret-key")

            let body = try #require(request.httpBody)
            let payload = try JSONDecoder().decode(GeminiRequestBody.self, from: body)
            #expect(payload.contents.first?.parts.first?.text.contains("Hello") == true)
            #expect(payload.systemInstruction?.parts.first?.text.contains("system") == true)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                Data(#"{"candidates":[{"content":{"parts":[{"text":"Hi there"}],"role":"model"}}]}"#.utf8),
                response
            )
        })
        let request = LocalAIRequest(
            baseURL: URL(string: LocalAISettings.defaultGeminiBaseURL)!,
            model: "gemini-3.5-flash",
            prompt: "Hello",
            system: "system prompt",
            apiKey: "secret-key"
        )

        let text = try await provider.generate(request: request)
        #expect(text == "Hi there")
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

private struct GeminiRequestBody: Decodable {
    let systemInstruction: GeminiContent?
    let contents: [GeminiContent]

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
    }
}

private struct GeminiContent: Decodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Decodable {
    let text: String
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
