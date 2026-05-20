import Foundation

public struct AgentRunRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let issueID: String
    public let issueTitle: String
    public let agentProfileID: UUID?
    public let agentName: String
    public let command: String
    public let prompt: String
    public let projectPath: String
    public let startedAt: Date
    public var completedAt: Date?
    public var status: AgentRunStatus
    public var notes: String?

    public init(
        id: UUID = UUID(),
        issueID: String,
        issueTitle: String,
        agentProfileID: UUID?,
        agentName: String,
        command: String,
        prompt: String,
        projectPath: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        status: AgentRunStatus,
        notes: String? = nil
    ) {
        self.id = id
        self.issueID = issueID
        self.issueTitle = issueTitle
        self.agentProfileID = agentProfileID
        self.agentName = agentName
        self.command = command
        self.prompt = prompt
        self.projectPath = projectPath
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.notes = notes
    }
}
