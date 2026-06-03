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
            try terminalLauncher.openTerminal(at: projectURL, command: terminalCommand, runID: session.id)
            historyStore.updateStatus(id: session.id, status: .terminalOpened)
        } catch {
            historyStore.updateStatus(id: session.id, status: .failed, notes: error.localizedDescription)
            throw error
        }
    }

    /// Launch an agent via a structured output adapter instead of opening Terminal.app.
    /// The adapter streams TimelineDelta values; `onDelta` is called for each one.
    /// `onTerminated` is called with the process exit code when the agent finishes.
    /// Returns immediately after starting the adapter; consumption happens in a background Task.
    @discardableResult
    public func launchWithAdapter(
        for session: AgentRunLaunchSession,
        profile: AgentProfile,
        worktreeURL: URL,
        onDelta: @escaping @Sendable @MainActor (TimelineDelta) -> Void,
        onTerminated: @escaping @Sendable @MainActor (Int32) -> Void
    ) throws -> (any AgentOutputAdapter) {
        guard let adapter = makeAgentAdapter(
            forCommand: profile.command,
            commandArgsTemplate: profile.commandArgsTemplate
        ) else {
            throw AdapterError.noAdapterForCommand(profile.command)
        }

        historyStore.updateStatus(id: session.id, status: .accepted)

        Task {
            do {
                let stream = try await adapter.start(
                    runID: session.id,
                    prompt: session.payload.prompt,
                    worktreeURL: worktreeURL
                )
                for await delta in stream {
                    await MainActor.run { onDelta(delta) }
                }
                await MainActor.run { onTerminated(0) }
            } catch {
                await MainActor.run { onTerminated(1) }
            }
        }

        return adapter
    }
}

public enum AdapterError: Error, LocalizedError {
    case noAdapterForCommand(String)

    public var errorDescription: String? {
        switch self {
        case .noAdapterForCommand(let cmd):
            return "No adapter available for command '\(cmd)'. Will fall back to Terminal."
        }
    }
}
