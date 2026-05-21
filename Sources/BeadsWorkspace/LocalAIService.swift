import Foundation

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
    private let ollamaProvider: any LocalAIProviding
    private let geminiProvider: any LocalAIProviding

    public init(
        ollamaProvider: any LocalAIProviding = OllamaService(),
        geminiProvider: any LocalAIProviding = GeminiService()
    ) {
        self.ollamaProvider = ollamaProvider
        self.geminiProvider = geminiProvider
    }

    public init(provider: any LocalAIProviding) {
        self.ollamaProvider = provider
        self.geminiProvider = provider
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

        return LocalAIRequest(
            baseURL: apiRootURL,
            model: model,
            prompt: prompt,
            system: action.systemPrompt,
            stream: stream,
            apiKey: apiKey.isEmpty ? nil : apiKey
        )
    }

    public func generate(for action: LocalAIAction, settings: LocalAISettings) async throws -> String {
        let request = try buildRequest(for: action, settings: settings)
        return try await provider(for: settings.provider).generate(request: request)
    }

    public func generateStream(for action: LocalAIAction, settings: LocalAISettings) throws -> AsyncThrowingStream<String, Error> {
        let request = try buildRequest(for: action, settings: settings, stream: true)
        return provider(for: settings.provider).generateStream(request: request)
    }

    public func modelName(for action: LocalAIAction, settings: LocalAISettings) -> String {
        switch action.modelTier {
        case .fast:
            return settings.fastModel.trimmingCharacters(in: .whitespacesAndNewlines)
        case .strong:
            return settings.strongModel.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public func prompt(for action: LocalAIAction) -> String {
        action.prompt
    }

    private func provider(for provider: LocalAIProvider) -> any LocalAIProviding {
        switch provider {
        case .ollama:
            return ollamaProvider
        case .gemini:
            return geminiProvider
        }
    }
}
