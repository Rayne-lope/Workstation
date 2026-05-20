import Foundation

public protocol URLSessioning: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
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
    case invalidResponse
    case unexpectedStatusCode(Int)
    case unreachable(baseURL: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedProvider(provider):
            return "Local AI provider \(provider) is not supported yet."
        case .invalidBaseURL:
            return "The Ollama base URL is invalid."
        case .invalidResponse:
            return "Ollama returned an invalid response."
        case let .unexpectedStatusCode(statusCode):
            return "Ollama returned HTTP \(statusCode)."
        case let .unreachable(baseURL, underlying):
            if underlying.isEmpty {
                return "Could not reach Ollama at \(baseURL)."
            }
            return "Could not reach Ollama at \(baseURL): \(underlying)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedProvider:
            return "Choose Ollama as the provider."
        case .invalidBaseURL:
            return "Use a URL like http://localhost:11434."
        case .invalidResponse, .unexpectedStatusCode:
            return "Make sure Ollama is running and the base URL points to its local API."
        case .unreachable:
            return "Start Ollama, confirm the base URL, then try again."
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
        guard settings.provider == .ollama else {
            throw LocalAIConnectionError.unsupportedProvider(settings.provider.displayName)
        }

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
                baseURL: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                underlying: error.localizedDescription
            )
        } catch {
            throw LocalAIConnectionError.unreachable(
                baseURL: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                underlying: error.localizedDescription
            )
        }
    }
}
