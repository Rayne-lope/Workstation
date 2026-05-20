import Foundation

struct PendingAgentLaunch: Identifiable, Hashable, Sendable {
    let id: UUID
    let issue: BeadIssue
    let profile: AgentProfile
    let workspace: ProjectWorkspace
    let gitStatus: GitStatusSummary

    init(
        issue: BeadIssue,
        profile: AgentProfile,
        workspace: ProjectWorkspace,
        gitStatus: GitStatusSummary
    ) {
        self.id = UUID()
        self.issue = issue
        self.profile = profile
        self.workspace = workspace
        self.gitStatus = gitStatus
    }
}

struct PendingWorktreeLaunch: Identifiable, Hashable, Sendable {
    let id: UUID
    let issue: BeadIssue
    let profile: AgentProfile
    let workspace: ProjectWorkspace
    let preflight: GitWorktreeLaunchPreflight

    init(
        issue: BeadIssue,
        profile: AgentProfile,
        workspace: ProjectWorkspace,
        preflight: GitWorktreeLaunchPreflight
    ) {
        self.id = UUID()
        self.issue = issue
        self.profile = profile
        self.workspace = workspace
        self.preflight = preflight
    }
}
