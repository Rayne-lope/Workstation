#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation

@MainActor
public final class AgentLaunchFlowCoordinator {
    public let historyStore: AgentRunHistoryStore

    private let launchCoordinator: AgentRunLaunchCoordinator
    private let gitStatusService: GitStatusService

    public init(
        historyStore: AgentRunHistoryStore,
        promptGenerator: PromptGenerator,
        terminalLauncher: any TerminalLaunching,
        commandRunner: any CommandRunning = ShellCommandRunner()
    ) {
        self.historyStore = historyStore
        self.launchCoordinator = AgentRunLaunchCoordinator(
            historyStore: historyStore,
            promptGenerator: promptGenerator,
            terminalLauncher: terminalLauncher
        )
        self.gitStatusService = GitStatusService(commandRunner: commandRunner)
    }

    public func buildPayload(
        for issue: BeadIssue,
        profile: AgentProfile,
        projectPath: String?
    ) -> AgentRunLaunchPayload {
        launchCoordinator.buildPayload(
            for: issue,
            profile: profile,
            projectPath: projectPath
        )
    }

    public func statusSummary(in workingDirectory: URL) async throws -> GitStatusSummary {
        try await gitStatusService.statusSummary(in: workingDirectory)
    }

    public func prepareLaunch(
        for issue: BeadIssue,
        profile: AgentProfile,
        projectPath: String?,
        worktree: AgentRunWorktreeMetadata? = nil
    ) -> AgentRunLaunchSession {
        launchCoordinator.prepareLaunch(
            for: issue,
            profile: profile,
            projectPath: projectPath,
            worktree: worktree
        )
    }

    public func prepareLaunchSession(
        for issue: BeadIssue,
        profile: AgentProfile,
        projectPath: String?,
        worktree: AgentRunWorktreeMetadata? = nil,
        issueStore: IssueStore?,
        clearHumanReviewLabel: Bool = false
    ) async -> AgentRunLaunchSession? {
        guard profile.canExecuteCode else { return nil }

        if profile.shouldClaimIssue {
            guard let issueStore else { return nil }
            guard await issueStore.claim(id: issue.id, assignee: profile.claimAssigneeToken) else {
                return nil
            }
            if clearHumanReviewLabel {
                guard await issueStore.clearHumanReview(id: issue.id) else {
                    return nil
                }
            }
        }

        return prepareLaunch(
            for: issue,
            profile: profile,
            projectPath: projectPath,
            worktree: worktree
        )
    }

    public func openTerminal(
        for session: AgentRunLaunchSession,
        projectURL: URL,
        terminalCommand: String
    ) throws {
        try launchCoordinator.openTerminal(
            for: session,
            projectURL: projectURL,
            terminalCommand: terminalCommand
        )
    }
}
