import Foundation

public protocol URLSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse)
}

extension URLSessioning {
    public func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        throw URLError(.unsupportedURL)
    }
}

extension URLSession: URLSessioning {}

public struct LocalAIConnectionResult: Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public enum LocalAIConnectionError: LocalizedError, Sendable {
    case unsupportedProvider(String)
    case invalidBaseURL
    case missingAPIKey(String)
    case invalidResponse
    case unexpectedStatusCode(Int, message: String? = nil)
    case unreachable(provider: String, baseURL: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedProvider(provider):
            return "Local AI provider \(provider) is not supported yet."
        case .invalidBaseURL:
            return "The AI provider base URL is invalid."
        case let .missingAPIKey(provider):
            return "\(provider) requires an API key before Copilot can send requests."
        case .invalidResponse:
            return "The AI provider returned an invalid response."
        case let .unexpectedStatusCode(statusCode, message):
            if let message, !message.isEmpty {
                return "The AI provider returned HTTP \(statusCode): \(message)"
            }
            return "The AI provider returned HTTP \(statusCode)."
        case let .unreachable(provider, baseURL, underlying):
            if underlying.isEmpty {
                return "Could not reach \(provider) at \(baseURL)."
            }
            return "Could not reach \(provider) at \(baseURL): \(underlying)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedProvider:
            return "Choose Ollama as the provider."
        case .invalidBaseURL:
            return "Use a valid provider URL."
        case .missingAPIKey:
            return "Paste an API key in Local AI settings, then try again."
        case .invalidResponse, .unexpectedStatusCode:
            return "Check the provider, model, API key, and base URL."
        case .unreachable:
            return "Confirm the provider is reachable, then try again."
        }
    }
}

public protocol LocalAIConnectionTesting: Sendable {
    func testConnection(settings: LocalAISettings) async throws -> LocalAIConnectionResult
}

public final class OllamaConnectionTester: LocalAIConnectionTesting, @unchecked Sendable {
    private let session: any URLSessioning

    public init(session: any URLSessioning = URLSession.shared) {
        self.session = session
    }

    public func testConnection(settings: LocalAISettings) async throws -> LocalAIConnectionResult {
        switch settings.provider {
        case .ollama:
            return try await testOllama(settings: settings)
        case .gemini:
            return try await testGemini(settings: settings)
        }
    }

    private func testOllama(settings: LocalAISettings) async throws -> LocalAIConnectionResult {
        guard let url = settings.tagsURL() else {
            throw LocalAIConnectionError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LocalAIConnectionError.invalidResponse
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                throw LocalAIConnectionError.unexpectedStatusCode(httpResponse.statusCode)
            }

            _ = data
            return LocalAIConnectionResult(
                message: "Ollama is reachable at \(settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines))."
            )
        } catch let error as LocalAIConnectionError {
            throw error
        } catch let error as URLError {
            throw LocalAIConnectionError.unreachable(
                provider: settings.provider.displayName,
                baseURL: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                underlying: error.localizedDescription
            )
        } catch {
            throw LocalAIConnectionError.unreachable(
                provider: settings.provider.displayName,
                baseURL: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                underlying: error.localizedDescription
            )
        }
    }

    private func testGemini(settings: LocalAISettings) async throws -> LocalAIConnectionResult {
        let apiKey = settings.trimmedAPIKey
        guard !apiKey.isEmpty else {
            throw LocalAIConnectionError.missingAPIKey(settings.provider.displayName)
        }
        guard let rootURL = settings.generationRootURL() else {
            throw LocalAIConnectionError.invalidBaseURL
        }

        let model = settings.strongModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = rootURL
            .appendingPathComponent("models")
            .appendingPathComponent("\(model):generateContent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = Data(#"{"contents":[{"parts":[{"text":"Reply with OK only."}]}]}"#.utf8)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LocalAIConnectionError.invalidResponse
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                throw LocalAIConnectionError.unexpectedStatusCode(
                    httpResponse.statusCode,
                    message: Self.decodeGeminiError(from: data)
                )
            }
            _ = data
            return LocalAIConnectionResult(message: "Gemini is reachable with model \(model).")
        } catch let error as LocalAIConnectionError {
            throw error
        } catch let error as URLError {
            throw LocalAIConnectionError.unreachable(
                provider: settings.provider.displayName,
                baseURL: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                underlying: error.localizedDescription
            )
        } catch {
            throw LocalAIConnectionError.unreachable(
                provider: settings.provider.displayName,
                baseURL: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                underlying: error.localizedDescription
            )
        }
    }

    private static func decodeGeminiError(from data: Data) -> String? {
        guard !data.isEmpty,
              let payload = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) else {
            return nil
        }
        let message = payload.error.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }

    private struct GeminiErrorResponse: Decodable {
        let error: GeminiError
    }

    private struct GeminiError: Decodable {
        let message: String
    }
}
