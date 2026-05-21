import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("LocalAIConnectionTester")
struct LocalAIConnectionTesterTests {
    @Test("Builds an Ollama tags URL from the base URL")
    func buildsTagsURL() {
        let settings = LocalAISettings(baseURL: "http://localhost:11434")
        #expect(settings.tagsURL()?.absoluteString == "http://localhost:11434/api/tags")
    }

    @Test("Accepts a base URL that already points at /api")
    func acceptsApiBaseURL() {
        let settings = LocalAISettings(baseURL: "http://localhost:11434/api")
        #expect(settings.tagsURL()?.absoluteString == "http://localhost:11434/api/tags")
    }

    @Test("Returns a friendly success message when Ollama responds")
    func successMessage() async throws {
        let settings = LocalAISettings(isEnabled: true)
        let tester = OllamaConnectionTester(session: StubURLSession { request in
            #expect(request.url?.absoluteString == "http://localhost:11434/api/tags")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(#"{"models":[]}"#.utf8), response)
        })

        let result = try await tester.testConnection(settings: settings)
        #expect(result.message.contains("Ollama is reachable"))
    }

    @Test("Gemini connection test requires API key")
    func geminiRequiresAPIKey() async throws {
        let settings = LocalAISettings(
            isEnabled: true,
            provider: .gemini,
            baseURL: LocalAISettings.defaultGeminiBaseURL,
            fastModel: LocalAISettings.defaultGeminiModel,
            strongModel: LocalAISettings.defaultGeminiModel
        )
        let tester = OllamaConnectionTester(session: StubURLSession { _ in
            #expect(Bool(false), "Connection test should fail before network without an API key")
            throw URLError(.badURL)
        })

        do {
            _ = try await tester.testConnection(settings: settings)
            #expect(Bool(false))
        } catch {
            #expect(error.localizedDescription.contains("requires an API key"))
        }
    }

    @Test("Gemini connection test sends API key header")
    func geminiConnectionSendsAPIKey() async throws {
        let settings = LocalAISettings(
            isEnabled: true,
            provider: .gemini,
            baseURL: LocalAISettings.defaultGeminiBaseURL,
            fastModel: LocalAISettings.defaultGeminiModel,
            strongModel: LocalAISettings.defaultGeminiModel,
            apiKey: "secret-key"
        )
        let tester = OllamaConnectionTester(session: StubURLSession { request in
            #expect(request.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent")
            #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "secret-key")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(#"{"candidates":[{"content":{"parts":[{"text":"OK"}]}}]}"#.utf8), response)
        })

        let result = try await tester.testConnection(settings: settings)
        #expect(result.message.contains("Gemini is reachable"))
    }

    @Test("Maps connection failures to friendly errors")
    func unreachableMessage() async throws {
        let settings = LocalAISettings(isEnabled: true)
        let tester = OllamaConnectionTester(session: StubURLSession { _ in
            throw URLError(.cannotConnectToHost)
        })

        do {
            _ = try await tester.testConnection(settings: settings)
            #expect(Bool(false))
        } catch {
            #expect(error.localizedDescription.contains("Could not reach Ollama"))
        }
    }
}

private struct StubURLSession: URLSessioning {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}
