#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation

public struct AgentRunLaunchPayload: Hashable, Sendable {
    public let prompt: String
    public let command: String
}

public struct AgentRunLaunchSession: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let payload: AgentRunLaunchPayload
}

@MainActor
public final class AgentRunLaunchCoordinator {
    public let historyStore: AgentRunHistoryStore

    private let promptGenerator: PromptGenerator
    private let terminalLauncher: any TerminalLaunching

    public init(
        historyStore: AgentRunHistoryStore,
        promptGenerator: PromptGenerator,
        terminalLauncher: any TerminalLaunching
    ) {
        self.historyStore = historyStore
        self.promptGenerator = promptGenerator
        self.terminalLauncher = terminalLauncher
    }

    public func buildPayload(
        for issue: BeadIssue,
        profile: AgentProfile,
        projectPath: String?
    ) -> AgentRunLaunchPayload {
        let prompt = promptGenerator.generatePrompt(
            for: profile,
            issue: issue,
            projectPath: projectPath
        )
        let command = promptGenerator.generateCommand(
            for: profile,
            issue: issue,
            projectPath: projectPath
        )
        return AgentRunLaunchPayload(prompt: prompt, command: command)
    }

    public func prepareLaunch(
        for issue: BeadIssue,
        profile: AgentProfile,
        projectPath: String?,
        worktree: AgentRunWorktreeMetadata? = nil
    ) -> AgentRunLaunchSession {
        let payload = buildPayload(for: issue, profile: profile, projectPath: projectPath)
        let record = historyStore.recordLaunchAttempt(
            issueID: issue.id,
            issueTitle: issue.title,
            agentProfileID: profile.id,
            agentName: profile.name,
            command: payload.command,
            prompt: payload.prompt,
            projectPath: projectPath ?? "",
            worktree: worktree,
            status: .prepared
        )
        return AgentRunLaunchSession(id: record.id, payload: payload)
    }

    public func openTerminal(
        for session: AgentRunLaunchSession,
        projectURL: URL,
        terminalCommand: String
    ) throws {
        do {
            try terminalLauncher.openTerminal(at: projectURL, command: terminalCommand)
            historyStore.updateStatus(id: session.id, status: .terminalOpened)
        } catch {
            historyStore.updateStatus(id: session.id, status: .failed, notes: error.localizedDescription)
            throw error
        }
    }
}
