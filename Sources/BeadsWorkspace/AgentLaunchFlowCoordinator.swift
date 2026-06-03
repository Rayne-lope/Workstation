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
            let claimed = await issueStore.claim(id: issue.id, assignee: profile.claimAssigneeToken)
            if !claimed {
                // If claim fails, it could be because the issue is already claimed or in_progress.
                // If already assigned to the correct agent, we can safely proceed.
                if issue.assignee == profile.claimAssigneeToken {
                    if issue.status != "in_progress" {
                        await issueStore.update(
                            id: issue.id,
                            UpdateIssueInput(status: "in_progress")
                        )
                    }
                } else if issue.status == "in_progress" || issue.status == "open" || issue.status == "ready" {
                    // Fall back to a plain update of assignee and status.
                    // Only set status to in_progress if it is not already in_progress.
                    let statusUpdate = issue.status == "in_progress" ? nil : "in_progress"
                    await issueStore.update(
                        id: issue.id,
                        UpdateIssueInput(
                            status: statusUpdate,
                            assignee: profile.claimAssigneeToken
                        )
                    )
                    
                    // If the plain update also fails and the original status was not in_progress,
                    // return nil to respect the strict failure behavior expected by tests.
                    if issueStore.errorMessage != nil && issue.status != "in_progress" {
                        return nil
                    }
                } else {
                    return nil
                }
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

    @discardableResult
    public func launchWithAdapter(
        for session: AgentRunLaunchSession,
        profile: AgentProfile,
        worktreeURL: URL,
        onDelta: @escaping @Sendable @MainActor (TimelineDelta) -> Void,
        onTerminated: @escaping @Sendable @MainActor (Int32) -> Void
    ) throws -> (any AgentOutputAdapter) {
        try launchCoordinator.launchWithAdapter(
            for: session,
            profile: profile,
            worktreeURL: worktreeURL,
            onDelta: onDelta,
            onTerminated: onTerminated
        )
    }
}
