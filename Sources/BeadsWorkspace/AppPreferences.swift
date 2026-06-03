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
    public var kanbanCompactMode: Bool
    public var notificationsEnabled: Bool
    public var scheduler: SchedulerPreferences

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
        localAI: LocalAISettings = LocalAISettings(),
        kanbanCompactMode: Bool = false,
        notificationsEnabled: Bool = true,
        scheduler: SchedulerPreferences = SchedulerPreferences()
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
        self.kanbanCompactMode = kanbanCompactMode
        self.notificationsEnabled = notificationsEnabled
        self.scheduler = scheduler
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
        case kanbanCompactMode
        case notificationsEnabled
        case scheduler
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
        kanbanCompactMode = try c.decodeIfPresent(Bool.self, forKey: .kanbanCompactMode) ?? false
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        scheduler = try c.decodeIfPresent(SchedulerPreferences.self, forKey: .scheduler) ?? SchedulerPreferences()
    }
}

// MARK: - Scheduler Preferences

public struct SchedulerProfileSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var dailyRunLimit: Int
    public var requireApproval: Bool

    public init(enabled: Bool = true, dailyRunLimit: Int = 10, requireApproval: Bool = false) {
        self.enabled = enabled
        self.dailyRunLimit = dailyRunLimit
        self.requireApproval = requireApproval
    }
}

public struct SchedulerPreferences: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var pollIntervalSeconds: Int
    public var maxConcurrentRuns: Int
    public var requireApprovalBeforeLaunch: Bool
    public var perProfileSettings: [String: SchedulerProfileSettings]

    public init(
        isEnabled: Bool = false,
        pollIntervalSeconds: Int = 60,
        maxConcurrentRuns: Int = 2,
        requireApprovalBeforeLaunch: Bool = false,
        perProfileSettings: [String: SchedulerProfileSettings] = [:]
    ) {
        self.isEnabled = isEnabled
        self.pollIntervalSeconds = pollIntervalSeconds
        self.maxConcurrentRuns = maxConcurrentRuns
        self.requireApprovalBeforeLaunch = requireApprovalBeforeLaunch
        self.perProfileSettings = perProfileSettings
    }
}
