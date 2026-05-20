import Foundation

public struct CommandResult: Sendable, Hashable {
    public let command: String
    public let arguments: [String]
    public let workingDirectory: URL
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let durationMs: Int

    public init(
        command: String,
        arguments: [String],
        workingDirectory: URL,
        stdout: String,
        stderr: String,
        exitCode: Int32,
        durationMs: Int
    ) {
        self.command = command
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.durationMs = durationMs
    }
}
