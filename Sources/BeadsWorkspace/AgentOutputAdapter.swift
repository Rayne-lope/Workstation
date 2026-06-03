import Foundation

/// Protocol for structured agent output adapters.
/// Each adapter spawns one agent (Claude, OpenCode, Gemini) and emits
/// TimelineDelta values from its native output format.
public protocol AgentOutputAdapter: AnyObject, Sendable {
    /// Start the agent with the given prompt in the given worktree directory.
    /// Returns an AsyncStream that emits TimelineDelta values in real time.
    func start(runID: UUID, prompt: String, worktreeURL: URL) async throws -> AsyncStream<TimelineDelta>

    /// Kill the running agent immediately.
    func kill()

    /// The process exit code, available once the stream has finished. `nil` while running.
    var lastExitCode: Int32? { get }
}

/// Selects the right adapter based on profile.command.
/// Returns nil for profiles that don't have a known adapter (falls back to Terminal.app).
public func makeAgentAdapter(forCommand command: String, commandArgsTemplate: String = "") -> (any AgentOutputAdapter)? {
    switch command {
    case "claude":
        return ClaudeAdapter()
    case "opencode":
        return OpenCodeAdapter(commandArgsTemplate: commandArgsTemplate)
    case "agy":
        return GeminiAdapter()
    default:
        return nil
    }
}
