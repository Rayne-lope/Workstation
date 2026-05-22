import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("LocalAIConnectionTester")
struct LocalAIConnectionTesterTests {
    @Test("OpenCode connection test requires API key")
    func openCodeRequiresAPIKey() async throws {
        var settings = LocalAISettings(
            isEnabled: true,
            provider: .opencode,
            baseURL: LocalAISettings.defaultBaseURL,
            fastModel: LocalAISettings.defaultFastModel,
            strongModel: LocalAISettings.defaultStrongModel
        )
        settings.apiKey = "" // Explicitly empty key to override auto key discovery
        let tester = OpenCodeConnectionTester(session: StubURLSession { _ in
            #expect(Bool(false), "Connection test should fail before network without an API key")
            throw URLError(.badURL)
        })

        do {
            _ = try await tester.testConnection(settings: settings)
            #expect(Bool(false), "Should have thrown missingAPIKey error")
        } catch let error as LocalAIConnectionError {
            #expect(error.errorDescription?.contains("requires an API key") == true)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Returns a friendly success message when OpenCode responds successfully")
    func successMessage() async throws {
        let settings = LocalAISettings(
            isEnabled: true,
            provider: .opencode,
            baseURL: "https://opencode.ai/zen/go/v1",
            fastModel: "fast-model",
            strongModel: "strong-model",
            apiKey: "secret-key"
        )
        let tester = OpenCodeConnectionTester(session: StubURLSession { request in
            #expect(request.url?.absoluteString == "https://opencode.ai/zen/go/v1/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-key")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(#"{"choices":[{"message":{"role":"assistant","content":"OK"}}]}"#.utf8), response)
        })

        let result = try await tester.testConnection(settings: settings)
        #expect(result.message.contains("OpenCode is reachable with model strong-model."))
    }

    @Test("Maps connection failures to friendly errors")
    func unreachableMessage() async throws {
        let settings = LocalAISettings(
            isEnabled: true,
            provider: .opencode,
            baseURL: "https://opencode.ai/zen/go/v1",
            apiKey: "secret-key"
        )
        let tester = OpenCodeConnectionTester(session: StubURLSession { _ in
            throw URLError(.cannotConnectToHost)
        })

        do {
            _ = try await tester.testConnection(settings: settings)
            #expect(Bool(false), "Should have thrown unreachable error")
        } catch let error as LocalAIConnectionError {
            #expect(error.errorDescription?.contains("Could not reach OpenCode") == true)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Propagates remote error messages correctly")
    func remoteErrorMessage() async throws {
        let settings = LocalAISettings(
            isEnabled: true,
            provider: .opencode,
            baseURL: "https://opencode.ai/zen/go/v1",
            apiKey: "secret-key"
        )
        let tester = OpenCodeConnectionTester(session: StubURLSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(#"{"error":{"message":"Invalid model selected"}}"#.utf8), response)
        })

        do {
            _ = try await tester.testConnection(settings: settings)
            #expect(Bool(false), "Should have thrown unexpectedStatusCode error")
        } catch let error as LocalAIConnectionError {
            #expect(error.errorDescription?.contains("Invalid model selected") == true)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}

private struct StubURLSession: URLSessioning {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}
