import Foundation

public protocol CommandRunning: Sendable {
    func run(command: String, arguments: [String], workingDirectory: URL) async throws -> CommandResult
}
