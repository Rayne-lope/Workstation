import Foundation

public enum OpenCodeServiceError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidResponse
    case unexpectedStatusCode(Int, message: String?)
    case unreachable(baseURL: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenCode requires an API key."
        case .invalidResponse:
            return "OpenCode returned an invalid response."
        case let .unexpectedStatusCode(statusCode, message):
            if let message, !message.isEmpty {
                return "OpenCode returned HTTP \(statusCode): \(message)"
            }
            return "OpenCode returned HTTP \(statusCode)."
        case let .unreachable(baseURL, underlying):
            if underlying.isEmpty {
                return "Could not reach OpenCode at \(baseURL)."
            }
            return "Could not reach OpenCode at \(baseURL): \(underlying)"
        }
    }
}

public final class OpenCodeService: LocalAIProviding, @unchecked Sendable {
    private let session: any URLSessioning

    public init(session: any URLSessioning = URLSession.shared) {
        self.session = session
    }

    public func generate(request: LocalAIRequest) async throws -> String {
        let apiKey = request.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !apiKey.isEmpty else {
            throw OpenCodeServiceError.missingAPIKey
        }

        let url = request.baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = OpenCodeChatCompletionRequestBody(from: request)
        urlRequest.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenCodeServiceError.invalidResponse
            }

            if !(200..<300).contains(httpResponse.statusCode) {
                throw OpenCodeServiceError.unexpectedStatusCode(
                    httpResponse.statusCode,
                    message: Self.decodeRemoteError(from: data)
                )
            }

            let payload = try JSONDecoder().decode(OpenCodeChatCompletionResponse.self, from: data)
            let text = payload.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else {
                throw OpenCodeServiceError.invalidResponse
            }
            return text
        } catch let error as OpenCodeServiceError {
            throw error
        } catch let error as URLError {
            throw OpenCodeServiceError.unreachable(
                baseURL: request.baseURL.absoluteString,
                underlying: error.localizedDescription
            )
        } catch {
            throw OpenCodeServiceError.unreachable(
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
              let payload = try? JSONDecoder().decode(OpenCodeRemoteErrorResponse.self, from: data) else {
            return nil
        }
        return payload.error.message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct OpenCodeChatCompletionRequestBody: Codable {
    public let model: String
    public let messages: [OpenCodeMessage]
    public let stream: Bool

    public init(from request: LocalAIRequest) {
        var cleanModel = request.model
        if cleanModel.hasPrefix("opencode-go/") {
            cleanModel = String(cleanModel.dropFirst("opencode-go/".count))
        } else if cleanModel.hasPrefix("opencode/") {
            cleanModel = String(cleanModel.dropFirst("opencode/".count))
        }
        self.model = cleanModel
        self.stream = false
        var msgs: [OpenCodeMessage] = []
        if let system = request.system?.trimmingCharacters(in: .whitespacesAndNewlines), !system.isEmpty {
            msgs.append(OpenCodeMessage(role: "system", content: system))
        }
        msgs.append(OpenCodeMessage(role: "user", content: request.prompt))
        self.messages = msgs
    }
}

public struct OpenCodeMessage: Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

private struct OpenCodeChatCompletionResponse: Decodable {
    let choices: [OpenCodeChoice]
}

private struct OpenCodeChoice: Decodable {
    let message: OpenCodeMessage
}

public struct OpenCodeRemoteErrorResponse: Decodable {
    public let error: OpenCodeRemoteError

    public init(error: OpenCodeRemoteError) {
        self.error = error
    }
}

public struct OpenCodeRemoteError: Decodable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}
