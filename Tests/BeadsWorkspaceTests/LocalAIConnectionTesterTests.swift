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
