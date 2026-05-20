import Foundation

public enum LocalAIServiceError: LocalizedError, Sendable {
    case disabled
    case unsupportedProvider(String)
    case invalidBaseURL
    case invalidModel(String)
    case emptyPrompt

    public var errorDescription: String? {
        switch self {
        case .disabled:
            return "Local AI is disabled."
        case let .unsupportedProvider(provider):
            return "Local AI provider \(provider) is not supported yet."
        case .invalidBaseURL:
            return "The Ollama base URL is invalid."
        case let .invalidModel(model):
            return "The selected Ollama model name is invalid: \(model)"
        case .emptyPrompt:
            return "The local AI prompt is empty."
        }
    }
}

public struct LocalAIService: Sendable {
    private let provider: any LocalAIProviding

    public init(provider: any LocalAIProviding = OllamaService()) {
        self.provider = provider
    }

    public func buildRequest(for action: LocalAIAction, settings: LocalAISettings) throws -> LocalAIRequest {
        guard settings.isEnabled else {
            throw LocalAIServiceError.disabled
        }
        guard settings.provider == .ollama else {
            throw LocalAIServiceError.unsupportedProvider(settings.provider.displayName)
        }
        guard let apiRootURL = settings.apiRootURL() else {
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

        return LocalAIRequest(
            baseURL: apiRootURL,
            model: model,
            prompt: prompt,
            system: action.systemPrompt,
            stream: false
        )
    }

    public func generate(for action: LocalAIAction, settings: LocalAISettings) async throws -> String {
        let request = try buildRequest(for: action, settings: settings)
        return try await provider.generate(request: request)
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
}
