import Foundation

public struct LocalAIRequest: Sendable, Equatable {
    public let baseURL: URL
    public let model: String
    public let prompt: String
    public let system: String?
    public let stream: Bool

    public init(
        baseURL: URL,
        model: String,
        prompt: String,
        system: String? = nil,
        stream: Bool = false
    ) {
        self.baseURL = baseURL
        self.model = model
        self.prompt = prompt
        self.system = system
        self.stream = stream
    }
}

public protocol LocalAIProviding: Sendable {
    func generate(request: LocalAIRequest) async throws -> String
}

public enum OllamaServiceError: LocalizedError, Sendable {
    case invalidBaseURL
    case invalidResponse
    case unexpectedStatusCode(Int, message: String?)
    case unreachable(baseURL: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The Ollama base URL is invalid."
        case .invalidResponse:
            return "Ollama returned an invalid response."
        case let .unexpectedStatusCode(statusCode, message):
            if let message, !message.isEmpty {
                return "Ollama returned HTTP \(statusCode): \(message)"
            }
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
        case .invalidBaseURL:
            return "Use a URL like http://localhost:11434."
        case .invalidResponse, .unexpectedStatusCode:
            return "Make sure Ollama is running and the base URL points to its local API."
        case .unreachable:
            return "Start Ollama, confirm the base URL, then try again."
        }
    }
}

public final class OllamaService: LocalAIProviding, @unchecked Sendable {
    private let session: any URLSessioning

    public init(session: any URLSessioning = URLSession.shared) {
        self.session = session
    }

    public func generate(request: LocalAIRequest) async throws -> String {
        let url = request.baseURL.appendingPathComponent("generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(GenerateRequestBody(from: request))

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaServiceError.invalidResponse
            }

            if !(200..<300).contains(httpResponse.statusCode) {
                if let errorMessage = Self.decodeRemoteError(from: data) {
                    throw OllamaServiceError.unexpectedStatusCode(httpResponse.statusCode, message: errorMessage)
                }
                throw OllamaServiceError.unexpectedStatusCode(httpResponse.statusCode, message: nil)
            }

            let payload = try JSONDecoder().decode(GenerateResponse.self, from: data)
            if let errorMessage = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines), !errorMessage.isEmpty {
                throw OllamaServiceError.unexpectedStatusCode(httpResponse.statusCode, message: errorMessage)
            }

            let text = payload.response?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else {
                throw OllamaServiceError.invalidResponse
            }
            return text
        } catch let error as OllamaServiceError {
            throw error
        } catch let error as URLError {
            throw OllamaServiceError.unreachable(
                baseURL: request.baseURL.absoluteString,
                underlying: error.localizedDescription
            )
        } catch {
            throw OllamaServiceError.unreachable(
                baseURL: request.baseURL.absoluteString,
                underlying: error.localizedDescription
            )
        }
    }

    private static func decodeRemoteError(from data: Data) -> String? {
        guard !data.isEmpty,
              let payload = try? JSONDecoder().decode(RemoteErrorResponse.self, from: data) else {
            return nil
        }
        let message = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return message.isEmpty ? nil : message
    }

    private struct GenerateRequestBody: Codable {
        let model: String
        let prompt: String
        let system: String?
        let stream: Bool

        init(from request: LocalAIRequest) {
            self.model = request.model
            self.prompt = request.prompt
            self.system = request.system
            self.stream = request.stream
        }
    }

    private struct GenerateResponse: Decodable {
        let response: String?
        let error: String?
    }

    private struct RemoteErrorResponse: Decodable {
        let error: String?
    }
}
