import Foundation

public struct CommandSnapshot: Sendable, Hashable {
    public let command: String
    public let arguments: [String]
    public let workingDirectory: URL
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let durationMs: Int
    public let timestamp: Date
    public let errorMessage: String?

    public init(
        command: String,
        arguments: [String],
        workingDirectory: URL,
        stdout: String,
        stderr: String,
        exitCode: Int32,
        durationMs: Int,
        timestamp: Date = .now,
        errorMessage: String? = nil
    ) {
        self.command = command
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.durationMs = durationMs
        self.timestamp = timestamp
        self.errorMessage = errorMessage
    }
}
