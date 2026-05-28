import Foundation

/// Represents a completed agent run that is waiting for the human to review and
/// decide whether to close or flag for review. Created by AppViewModel when
/// `AgentRunStatus.isFinalized` transitions to `true`.
public struct PendingLanding: Identifiable, Sendable {
    /// Equal to the underlying `AgentRunRecord.id`.
    public let id: UUID
    public let issueID: String
    public let issueTitle: String
    /// Working directory to use for test execution and git diff.
    /// For worktree runs this is the worktree directory; otherwise the main project path.
    public let workDirectory: URL
    public let agentRecord: AgentRunRecord

    public init(from record: AgentRunRecord) {
        self.id = record.id
        self.issueID = record.issueID
        self.issueTitle = record.issueTitle
        let pathString = record.worktree?.path ?? record.projectPath
        self.workDirectory = URL(fileURLWithPath: pathString)
        self.agentRecord = record
    }
}
