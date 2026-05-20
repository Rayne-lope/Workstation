import Foundation

public enum AgentRunMessageRole: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case user
    case agent
    case note

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .user: return "User"
        case .agent: return "Agent"
        case .note: return "Note"
        }
    }
}

public struct AgentRunMessage: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let runID: UUID
    public var role: AgentRunMessageRole
    public var content: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        runID: UUID,
        role: AgentRunMessageRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.runID = runID
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
