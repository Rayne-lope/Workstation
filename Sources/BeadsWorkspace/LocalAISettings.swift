import Foundation

public enum LocalAIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case ollama
    case gemini

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ollama:
            return "Ollama"
        case .gemini:
            return "Gemini"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .ollama:
            return false
        case .gemini:
            return true
        }
    }
}

public struct LocalAISettings: Codable, Equatable, Sendable {
    public static let defaultBaseURL = "http://localhost:11434"
    public static let defaultGeminiBaseURL = "https://generativelanguage.googleapis.com/v1beta"
    public static let defaultFastModel = "qwen2.5-coder:3b"
    public static let defaultStrongModel = "qwen2.5-coder:7b"
    public static let defaultGeminiModel = "gemini-3.5-flash"

    public var isEnabled: Bool
    public var provider: LocalAIProvider
    public var baseURL: String
    public var fastModel: String
    public var strongModel: String
    public var apiKey: String

    public init(
        isEnabled: Bool = false,
        provider: LocalAIProvider = .ollama,
        baseURL: String = LocalAISettings.defaultBaseURL,
        fastModel: String = LocalAISettings.defaultFastModel,
        strongModel: String = LocalAISettings.defaultStrongModel,
        apiKey: String = ""
    ) {
        self.isEnabled = isEnabled
        self.provider = provider
        self.baseURL = baseURL
        self.fastModel = fastModel
        self.strongModel = strongModel
        self.apiKey = apiKey
    }

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case provider
        case baseURL
        case fastModel
        case strongModel
        case apiKey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        provider = try c.decodeIfPresent(LocalAIProvider.self, forKey: .provider) ?? .ollama
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? LocalAISettings.defaultBaseURL
        fastModel = try c.decodeIfPresent(String.self, forKey: .fastModel) ?? LocalAISettings.defaultFastModel
        strongModel = try c.decodeIfPresent(String.self, forKey: .strongModel) ?? LocalAISettings.defaultStrongModel
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
    }

    public func apiRootURL() -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else { return nil }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            components.path = "/api"
        } else if path == "api" || path.hasSuffix("/api") {
            components.path = "/\(path)"
        } else {
            components.path = "/\(path)/api"
        }
        return components.url
    }

    public func tagsURL() -> URL? {
        apiRootURL()?.appendingPathComponent("tags")
    }

    public func generationRootURL() -> URL? {
        switch provider {
        case .ollama:
            return apiRootURL()
        case .gemini:
            let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
            return url
        }
    }

    public var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
