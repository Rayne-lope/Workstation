import Foundation

public struct LocalAIRequest: Sendable, Equatable {
    public let baseURL: URL
    public let model: String
    public let prompt: String
    public let system: String?
    public let stream: Bool
    public let apiKey: String?

    public init(
        baseURL: URL,
        model: String,
        prompt: String,
        system: String? = nil,
        stream: Bool = false,
        apiKey: String? = nil
    ) {
        self.baseURL = baseURL
        self.model = model
        self.prompt = prompt
        self.system = system
        self.stream = stream
        self.apiKey = apiKey
    }
}

public protocol LocalAIProviding: Sendable {
    func generate(request: LocalAIRequest) async throws -> String
    func generateStream(request: LocalAIRequest) -> AsyncThrowingStream<String, Error>
}

extension LocalAIProviding {
    public func generateStream(request: LocalAIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await generate(request: request)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
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

    public func generateStream(request: LocalAIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = request.baseURL.appendingPathComponent("generate")
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONEncoder().encode(GenerateRequestBody(from: request))

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OllamaServiceError.invalidResponse
                    }
                    if !(200..<300).contains(httpResponse.statusCode) {
                        throw OllamaServiceError.unexpectedStatusCode(httpResponse.statusCode, message: nil)
                    }

                    for try await line in bytes.lines {
                        guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)
                        if let token = chunk.response, !token.isEmpty {
                            continuation.yield(token)
                        }
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch let error as OllamaServiceError {
                    continuation.finish(throwing: error)
                } catch let error as URLError {
                    continuation.finish(throwing: OllamaServiceError.unreachable(
                        baseURL: request.baseURL.absoluteString,
                        underlying: error.localizedDescription
                    ))
                } catch {
                    continuation.finish(throwing: OllamaServiceError.unreachable(
                        baseURL: request.baseURL.absoluteString,
                        underlying: error.localizedDescription
                    ))
                }
            }
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

    private struct StreamChunk: Decodable {
        let response: String?
        let done: Bool
    }

    private struct RemoteErrorResponse: Decodable {
        let error: String?
    }
}

public enum GeminiServiceError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidResponse
    case unexpectedStatusCode(Int, message: String?)
    case unreachable(baseURL: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini requires an API key."
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case let .unexpectedStatusCode(statusCode, message):
            if let message, !message.isEmpty {
                return "Gemini returned HTTP \(statusCode): \(message)"
            }
            return "Gemini returned HTTP \(statusCode)."
        case let .unreachable(baseURL, underlying):
            if underlying.isEmpty {
                return "Could not reach Gemini at \(baseURL)."
            }
            return "Could not reach Gemini at \(baseURL): \(underlying)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey:
            return "Paste a Gemini API key in Local AI settings, then try again."
        case .invalidResponse, .unexpectedStatusCode:
            return "Check the Gemini model name, API key, and provider base URL."
        case .unreachable:
            return "Check your internet connection and Gemini provider base URL."
        }
    }
}

public final class GeminiService: LocalAIProviding, @unchecked Sendable {
    private let session: any URLSessioning

    public init(session: any URLSessioning = URLSession.shared) {
        self.session = session
    }

    public func generate(request: LocalAIRequest) async throws -> String {
        let apiKey = request.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !apiKey.isEmpty else {
            throw GeminiServiceError.missingAPIKey
        }

        let url = request.baseURL
            .appendingPathComponent("models")
            .appendingPathComponent("\(request.model):generateContent")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        urlRequest.httpBody = try JSONEncoder().encode(GeminiGenerateContentRequestBody(from: request))

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiServiceError.invalidResponse
            }

            if !(200..<300).contains(httpResponse.statusCode) {
                throw GeminiServiceError.unexpectedStatusCode(
                    httpResponse.statusCode,
                    message: Self.decodeRemoteError(from: data)
                )
            }

            let payload = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            let text = payload.candidates
                .flatMap { $0.content.parts }
                .compactMap(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw GeminiServiceError.invalidResponse
            }
            return text
        } catch let error as GeminiServiceError {
            throw error
        } catch let error as URLError {
            throw GeminiServiceError.unreachable(
                baseURL: request.baseURL.absoluteString,
                underlying: error.localizedDescription
            )
        } catch {
            throw GeminiServiceError.unreachable(
                baseURL: request.baseURL.absoluteString,
                underlying: error.localizedDescription
            )
        }
    }

    public func generateStream(request: LocalAIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let text = try await generate(request: request)
                    continuation.yield(text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func decodeRemoteError(from data: Data) -> String? {
        guard !data.isEmpty,
              let payload = try? JSONDecoder().decode(GeminiRemoteErrorResponse.self, from: data) else {
            return nil
        }
        let message = payload.error.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }
}

private struct GeminiGenerateContentRequestBody: Encodable {
    let systemInstruction: GeminiContent?
    let contents: [GeminiContent]

    init(from request: LocalAIRequest) {
        let system = request.system?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        systemInstruction = system.isEmpty
            ? nil
            : GeminiContent(role: nil, parts: [GeminiPart(text: system)])
        contents = [
            GeminiContent(
                role: "user",
                parts: [GeminiPart(text: request.prompt)]
            )
        ]
    }

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
    }
}

private struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
}

private struct GeminiGenerateContentResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct GeminiRemoteErrorResponse: Decodable {
    let error: GeminiRemoteError
}

private struct GeminiRemoteError: Decodable {
    let message: String
}
