import Foundation

public enum LocalAIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case opencode

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .opencode:
            return "OpenCode"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .opencode:
            return true
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = LocalAIProvider(rawValue: rawValue.lowercased()) ?? .opencode
    }
}

public struct LocalAISettings: Codable, Equatable, Sendable {
    public static let defaultBaseURL = "https://opencode.ai/zen/go/v1"
    public static let defaultFastModel = "opencode-go/deepseek-v4-flash"
    public static let defaultStrongModel = "opencode-go/deepseek-v4-flash"

    public var isEnabled: Bool
    public var provider: LocalAIProvider
    public var baseURL: String
    public var fastModel: String
    public var strongModel: String
    public var apiKey: String

    public static func loadDefaultAPIKey() -> String {
        let home = NSHomeDirectory()
        let path = (home as NSString).appendingPathComponent(".local/share/opencode/auth.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let opencodeGo = json["opencode-go"] as? [String: Any],
              let key = opencodeGo["key"] as? String else {
            return ""
        }
        return key
    }

    public init(
        isEnabled: Bool = false,
        provider: LocalAIProvider = .opencode,
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
        self.apiKey = apiKey.isEmpty ? Self.loadDefaultAPIKey() : apiKey
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
        provider = try c.decodeIfPresent(LocalAIProvider.self, forKey: .provider) ?? .opencode
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? LocalAISettings.defaultBaseURL
        fastModel = try c.decodeIfPresent(String.self, forKey: .fastModel) ?? LocalAISettings.defaultFastModel
        strongModel = try c.decodeIfPresent(String.self, forKey: .strongModel) ?? LocalAISettings.defaultStrongModel
        let rawKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        apiKey = rawKey.isEmpty ? Self.loadDefaultAPIKey() : rawKey
    }

    public func apiRootURL() -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmed)
    }

    public func tagsURL() -> URL? {
        nil
    }

    public func generationRootURL() -> URL? {
        apiRootURL()
    }

    public var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
