import Foundation

public struct AppPreferences: Codable, Equatable, Sendable {
    public static let defaultDoneVisibilityWindowSeconds: TimeInterval = 24 * 60 * 60

    public var lastSelectedPath: String?
    public var autoRestoreOnLaunch: Bool
    public var autoReloadEnabled: Bool
    public var defaultIssueType: String
    public var defaultIssuePriority: Int
    public var defaultCloseReasonTemplate: String
    public var doneVisibilityWindowSeconds: TimeInterval
    public var theme: AppTheme
    public var filterState: [String: FilterState]
    public var localAI: LocalAISettings

    public init(
        lastSelectedPath: String? = nil,
        autoRestoreOnLaunch: Bool = true,
        autoReloadEnabled: Bool = true,
        defaultIssueType: String = "task",
        defaultIssuePriority: Int = 2,
        defaultCloseReasonTemplate: String = "",
        doneVisibilityWindowSeconds: TimeInterval = AppPreferences.defaultDoneVisibilityWindowSeconds,
        theme: AppTheme = .system,
        filterState: [String: FilterState] = [:],
        localAI: LocalAISettings = LocalAISettings()
    ) {
        self.lastSelectedPath = lastSelectedPath
        self.autoRestoreOnLaunch = autoRestoreOnLaunch
        self.autoReloadEnabled = autoReloadEnabled
        self.defaultIssueType = defaultIssueType
        self.defaultIssuePriority = defaultIssuePriority
        self.defaultCloseReasonTemplate = defaultCloseReasonTemplate
        self.doneVisibilityWindowSeconds = doneVisibilityWindowSeconds
        self.theme = theme
        self.filterState = filterState
        self.localAI = localAI
    }

    enum CodingKeys: String, CodingKey {
        case lastSelectedPath
        case autoRestoreOnLaunch
        case autoReloadEnabled
        case defaultIssueType
        case defaultIssuePriority
        case defaultCloseReasonTemplate
        case doneVisibilityWindowSeconds
        case theme
        case filterState
        case localAI
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastSelectedPath = try c.decodeIfPresent(String.self, forKey: .lastSelectedPath)
        autoRestoreOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .autoRestoreOnLaunch) ?? true
        autoReloadEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoReloadEnabled) ?? true
        defaultIssueType = try c.decodeIfPresent(String.self, forKey: .defaultIssueType) ?? "task"
        defaultIssuePriority = try c.decodeIfPresent(Int.self, forKey: .defaultIssuePriority) ?? 2
        defaultCloseReasonTemplate = try c.decodeIfPresent(String.self, forKey: .defaultCloseReasonTemplate) ?? ""
        doneVisibilityWindowSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .doneVisibilityWindowSeconds)
            ?? AppPreferences.defaultDoneVisibilityWindowSeconds
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        filterState = try c.decodeIfPresent([String: FilterState].self, forKey: .filterState) ?? [:]
        localAI = try c.decodeIfPresent(LocalAISettings.self, forKey: .localAI) ?? LocalAISettings()
    }
}
