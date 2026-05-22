import Foundation

public struct AgentLaunchPreflight: Codable, Equatable, Sendable {
    public var issueId: String
    public var selectedProfileId: UUID
    public var useFastModel: Bool
    public var extraPrompt: String
    public var autoClaim: Bool
    public var autoMerge: Bool
    public var requestReview: Bool

    public init(
        issueId: String,
        selectedProfileId: UUID,
        useFastModel: Bool,
        extraPrompt: String,
        autoClaim: Bool,
        autoMerge: Bool,
        requestReview: Bool
    ) {
        self.issueId = issueId
        self.selectedProfileId = selectedProfileId
        self.useFastModel = useFastModel
        self.extraPrompt = extraPrompt
        self.autoClaim = autoClaim
        self.autoMerge = autoMerge
        self.requestReview = requestReview
    }
}

public struct CopilotConversationMessage: Codable, Identifiable, Equatable, Sendable {
    public enum Role: String, Codable, Equatable, Sendable {
        case user
        case assistant
        case error
    }

    public let id: UUID
    public let createdAt: Date
    public let role: Role
    public var text: String
    public var isStreaming: Bool
    public var thinkingDuration: TimeInterval?
    
    // Action plan fields
    public var plan: WorkflowPlan?
    public var isPlan: Bool
    public var planError: String?
    public var isExecuted: Bool
    public var isExecuting: Bool

    // Agent launch pre-flight fields
    public var isAgentLaunch: Bool
    public var agentLaunch: AgentLaunchPreflight?

    // Offline status
    public var isNetworkOffline: Bool

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        role: Role,
        text: String,
        isStreaming: Bool = false,
        thinkingDuration: TimeInterval? = nil,
        plan: WorkflowPlan? = nil,
        isPlan: Bool = false,
        planError: String? = nil,
        isExecuted: Bool = false,
        isExecuting: Bool = false,
        isAgentLaunch: Bool = false,
        agentLaunch: AgentLaunchPreflight? = nil,
        isNetworkOffline: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
        self.thinkingDuration = thinkingDuration
        self.plan = plan
        self.isPlan = isPlan
        self.planError = planError
        self.isExecuted = isExecuted
        self.isExecuting = isExecuting
        self.isAgentLaunch = isAgentLaunch
        self.agentLaunch = agentLaunch
        self.isNetworkOffline = isNetworkOffline
    }
}
