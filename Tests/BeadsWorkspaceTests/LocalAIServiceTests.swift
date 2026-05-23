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
            baseURL: "https://opencode.ai/zen/go/v1",
            fastModel: "fast-model",
            strongModel: "strong-model",
            apiKey: "dummy-key"
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
            for: .copilot(prompt: "What should I do next?", contextIssues: [makeIssue()]),
            settings: settings
        )
        #expect(copilotRequest.model == "strong-model")
        #expect(copilotRequest.prompt.contains("Workflow Copilot request"))
        #expect(copilotRequest.prompt.contains("What should I do next?"))
    }

    @Test("buildRequest includes API key for OpenCode-backed Copilot actions")
    func buildRequestIncludesOpenCodeAPIKey() throws {
        let settings = LocalAISettings(
            isEnabled: true,
            provider: .opencode,
            baseURL: LocalAISettings.defaultBaseURL,
            fastModel: LocalAISettings.defaultFastModel,
            strongModel: LocalAISettings.defaultStrongModel,
            apiKey: " test-key "
        )
        let service = LocalAIService(provider: RecordingProvider())

        let request = try service.buildRequest(
            for: .copilot(prompt: "Summarize selected issues", contextIssues: [makeIssue()]),
            settings: settings,
            stream: true
        )

        #expect(request.baseURL.absoluteString == LocalAISettings.defaultBaseURL)
        #expect(request.model == LocalAISettings.defaultStrongModel)
        #expect(request.apiKey == "test-key")
        #expect(request.stream)
    }

    @Test("buildRequest rejects OpenCode without an API key")
    func buildRequestRejectsOpenCodeWithoutAPIKey() throws {
        var settings = LocalAISettings(
            isEnabled: true,
            provider: .opencode,
            baseURL: LocalAISettings.defaultBaseURL,
            fastModel: LocalAISettings.defaultFastModel,
            strongModel: LocalAISettings.defaultStrongModel
        )
        settings.apiKey = "" // Override auto key discovery
        let service = LocalAIService(provider: RecordingProvider())

        #expect(throws: LocalAIServiceError.self) {
            _ = try service.buildRequest(
                for: .draftIssuesFromPRD(prd: "A PRD"),
                settings: settings
            )
        }
    }

    @Test("generate sends a chat completion OpenCode request and returns the text response")
    func generateSendsRequest() async throws {
        let settings = LocalAISettings(
            isEnabled: true,
            baseURL: "https://opencode.ai/zen/go/v1",
            fastModel: "fast-model",
            strongModel: "strong-model",
            apiKey: "test-key"
        )
        let issue = makeIssue()
        let provider = OpenCodeService(session: StubURLSession { request in
            #expect(request.url?.absoluteString == "https://opencode.ai/zen/go/v1/chat/completions")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")

            let body = try #require(request.httpBody)
            let payload = try JSONDecoder().decode(OpenCodeChatCompletionRequestBody.self, from: body)
            #expect(payload.model == "strong-model")
            #expect(payload.messages.last?.content.contains(issue.title) == true)
            #expect(payload.stream == false)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Data(#"{"choices":[{"message":{"role":"assistant","content":"preview text"}}]}"#.utf8), response)
        })
        let service = LocalAIService(provider: provider)

        let text = try await service.generate(for: .issueDrafting(issue: issue), settings: settings)
        #expect(text == "preview text")
    }

    @Test("generate surfaces OpenCode errors cleanly")
    func generateSurfacesErrors() async throws {
        let settings = LocalAISettings(
            isEnabled: true,
            apiKey: "test-key"
        )
        let provider = OpenCodeService(session: StubURLSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(#"{"error":{"message":"model unavailable"}}"#.utf8), response)
        })
        let service = LocalAIService(provider: provider)

        await #expect(throws: OpenCodeServiceError.self) {
            _ = try await service.generate(for: .promptOptimization(prompt: "shorten this"), settings: settings)
        }
    }

    @Test("buildRequest rejects disabled settings before calling the provider")
    func buildRequestRejectsDisabledSettings() throws {
        let service = LocalAIService(provider: RecordingProvider())
        var settings = LocalAISettings()
        settings.isEnabled = false

        #expect(throws: LocalAIServiceError.self) {
            _ = try service.buildRequest(
                for: .promptOptimization(prompt: "shorten this"),
                settings: settings
            )
        }
    }

    @Test("OpenCodeChatCompletionRequestBody strips opencode-go/ and opencode/ prefixes")
    func requestBodyStripsPrefixes() throws {
        let request1 = LocalAIRequest(
            baseURL: URL(string: "https://opencode.ai/zen/go/v1")!,
            model: "opencode-go/deepseek-v4-flash",
            prompt: "test"
        )
        let body1 = OpenCodeChatCompletionRequestBody(from: request1)
        #expect(body1.model == "deepseek-v4-flash")

        let request2 = LocalAIRequest(
            baseURL: URL(string: "https://opencode.ai/zen/go/v1")!,
            model: "opencode/deepseek-v4-flash-free",
            prompt: "test"
        )
        let body2 = OpenCodeChatCompletionRequestBody(from: request2)
        #expect(body2.model == "deepseek-v4-flash-free")

        let request3 = LocalAIRequest(
            baseURL: URL(string: "https://opencode.ai/zen/go/v1")!,
            model: "custom-model",
            prompt: "test"
        )
        let body3 = OpenCodeChatCompletionRequestBody(from: request3)
        #expect(body3.model == "custom-model")
    }

    @Test("buildRequest routes draftCommitMessage to the strong model tier")
    func buildRequestRoutesDraftCommitMessage() throws {
        let settings = LocalAISettings(
            isEnabled: true,
            baseURL: "https://opencode.ai/zen/go/v1",
            fastModel: "fast-model",
            strongModel: "strong-model",
            apiKey: "dummy-key"
        )
        let service = LocalAIService(provider: RecordingProvider())

        let request = try service.buildRequest(
            for: .draftCommitMessage(
                worktreeURL: "/path/to/worktree",
                diffSummary: "M Sources/App.swift\nA Sources/New.swift",
                diff: "diff --git a/Sources/App.swift b/Sources/App.swift\n--- a/Sources/App.swift\n+++ b/Sources/App.swift\n@@ -1,5 +1,7 @@\n+import NewModule",
                lastCommit: "feat: add auth module"
            ),
            settings: settings
        )

        #expect(request.model == "strong-model")
        #expect(request.prompt.contains("Generate a commit message for this worktree"))
        #expect(request.prompt.contains("/path/to/worktree"))
        #expect(request.prompt.contains("M Sources/App.swift"))
        #expect(request.prompt.contains("feat: add auth module"))
        #expect(request.prompt.contains("Conventional Commits"))
        #expect(request.system?.contains("professional commit message generator") == true)
    }

    @Test("draftCommitMessage system prompt has strict formatting rules")
    func draftCommitMessageSystemPromptIsStrict() throws {
        let settings = LocalAISettings(
            isEnabled: true,
            apiKey: "dummy-key"
        )
        let service = LocalAIService(provider: RecordingProvider())

        let request = try service.buildRequest(
            for: .draftCommitMessage(
                worktreeURL: "/test/worktree",
                diffSummary: "M README.md",
                diff: "diff content",
                lastCommit: nil
            ),
            settings: settings
        )

        #expect(request.system?.contains("type(scope): short description") == true)
        #expect(request.system?.contains("Do not wrap output in markdown fences") == true)
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
