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

public enum LocalAIServiceError: LocalizedError, Sendable {
    case disabled
    case unsupportedProvider(String)
    case invalidBaseURL
    case invalidModel(String)
    case missingAPIKey(String)
    case emptyPrompt

    public var errorDescription: String? {
        switch self {
        case .disabled:
            return "Local AI is disabled."
        case let .unsupportedProvider(provider):
            return "Local AI provider \(provider) is not supported yet."
        case .invalidBaseURL:
            return "The AI provider base URL is invalid."
        case let .invalidModel(model):
            return "The selected AI model name is invalid: \(model)"
        case let .missingAPIKey(provider):
            return "\(provider) requires an API key before Copilot can send requests."
        case .emptyPrompt:
            return "The local AI prompt is empty."
        }
    }
}

public struct LocalAIService: Sendable {
    private let opencodeProvider: any LocalAIProviding

    public init(
        opencodeProvider: any LocalAIProviding = OpenCodeService()
    ) {
        self.opencodeProvider = opencodeProvider
    }

    public init(provider: any LocalAIProviding) {
        self.opencodeProvider = provider
    }

    public func buildRequest(for action: LocalAIAction, settings: LocalAISettings, stream: Bool = false) throws -> LocalAIRequest {
        guard settings.isEnabled else {
            throw LocalAIServiceError.disabled
        }
        guard let apiRootURL = settings.generationRootURL() else {
            throw LocalAIServiceError.invalidBaseURL
        }

        let model = modelName(for: action, settings: settings)
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAIServiceError.invalidModel(model)
        }

        let prompt = action.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw LocalAIServiceError.emptyPrompt
        }

        let apiKey = settings.trimmedAPIKey
        if settings.provider.requiresAPIKey, apiKey.isEmpty {
            throw LocalAIServiceError.missingAPIKey(settings.provider.displayName)
        }

        let systemPrompt: String
        switch action {
        case .copilot:
            if !settings.copilotSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                systemPrompt = settings.copilotSystemPrompt
            } else {
                systemPrompt = action.systemPrompt
            }
        default:
            systemPrompt = action.systemPrompt
        }

        return LocalAIRequest(
            baseURL: apiRootURL,
            model: model,
            prompt: prompt,
            system: systemPrompt,
            stream: stream,
            apiKey: apiKey.isEmpty ? nil : apiKey
        )
    }

    public func generate(for action: LocalAIAction, settings: LocalAISettings) async throws -> String {
        let request = try buildRequest(for: action, settings: settings)
        return try await opencodeProvider.generate(request: request)
    }

    public func generateStream(for action: LocalAIAction, settings: LocalAISettings) throws -> AsyncThrowingStream<String, Error> {
        let request = try buildRequest(for: action, settings: settings, stream: true)
        return opencodeProvider.generateStream(request: request)
    }

    public func modelName(for action: LocalAIAction, settings: LocalAISettings) -> String {
        let raw: String
        switch action.modelTier {
        case .fast:
            raw = settings.fastModel.trimmingCharacters(in: .whitespacesAndNewlines)
        case .strong:
            raw = settings.strongModel.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }

    public func prompt(for action: LocalAIAction) -> String {
        action.prompt
    }

    private func provider(for provider: LocalAIProvider) -> any LocalAIProviding {
        return opencodeProvider
    }
}
