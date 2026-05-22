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

public final class OpenCodeConnectionTester: LocalAIConnectionTesting, @unchecked Sendable {
    private let session: any URLSessioning

    public init(session: any URLSessioning = URLSession.shared) {
        self.session = session
    }

    public func testConnection(settings: LocalAISettings) async throws -> LocalAIConnectionResult {
        let apiKey = settings.trimmedAPIKey
        guard !apiKey.isEmpty else {
            throw LocalAIConnectionError.missingAPIKey("OpenCode")
        }
        guard let rootURL = settings.generationRootURL() else {
            throw LocalAIConnectionError.invalidBaseURL
        }

        let model = settings.strongModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = rootURL.appendingPathComponent("chat/completions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = OpenCodeChatCompletionRequestBody(from: LocalAIRequest(
            baseURL: rootURL,
            model: model,
            prompt: "Reply with OK only."
        ))
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LocalAIConnectionError.invalidResponse
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                throw LocalAIConnectionError.unexpectedStatusCode(
                    httpResponse.statusCode,
                    message: Self.decodeOpenCodeError(from: data)
                )
            }
            return LocalAIConnectionResult(message: "OpenCode is reachable with model \(model).")
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

    private static func decodeOpenCodeError(from data: Data) -> String? {
        guard !data.isEmpty,
              let payload = try? JSONDecoder().decode(OpenCodeRemoteErrorResponse.self, from: data) else {
            return nil
        }
        return payload.error.message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
