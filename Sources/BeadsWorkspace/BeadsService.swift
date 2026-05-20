#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation

public struct BeadsService: Sendable {
    private let commandRunner: any CommandRunning

    public init(commandRunner: any CommandRunning = ShellCommandRunner()) {
        self.commandRunner = commandRunner
    }

    // MARK: - Raw probes (used by WorkspaceValidator)

    public func version(in workingDirectory: URL) async throws -> CommandResult {
        try await runRaw(arguments: ["--version"], in: workingDirectory)
    }

    public func list(in workingDirectory: URL) async throws -> CommandResult {
        try await runRaw(arguments: ["list", "--json"], in: workingDirectory)
    }

    public func ready(in workingDirectory: URL) async throws -> CommandResult {
        try await runRaw(arguments: ["ready", "--json"], in: workingDirectory)
    }

    public func show(id: String, in workingDirectory: URL) async throws -> CommandResult {
        try await runRaw(arguments: ["show", id, "--json"], in: workingDirectory)
    }

    // MARK: - Typed read API

    public func listIssues(in workingDirectory: URL) async throws -> [BeadIssue] {
        try await runDecodingIssues(arguments: ["list", "--json"], in: workingDirectory)
    }

    public func readyIssues(in workingDirectory: URL) async throws -> [BeadIssue] {
        try await runDecodingIssues(arguments: ["ready", "--json"], in: workingDirectory)
    }

    public func closedIssues(in workingDirectory: URL) async throws -> [BeadIssue] {
        try await runDecodingIssues(
            arguments: ["list", "--status=closed", "--json"],
            in: workingDirectory
        )
    }

    public func blockedIssues(in workingDirectory: URL) async throws -> [BeadIssue] {
        try await runDecodingIssues(arguments: ["blocked", "--json"], in: workingDirectory)
    }

    public func showIssue(id: String, in workingDirectory: URL) async throws -> BeadIssue {
        try Self.validateID(id)
        return try await runDecodingIssue(arguments: ["show", id, "--json"], in: workingDirectory)
    }

    // MARK: - Mutations

    public func createIssue(_ input: CreateIssueInput, in workingDirectory: URL) async throws -> BeadIssue {
        guard !input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeadsAppError.commandFailed(
                command: "bd create",
                stderr: "Issue title must not be empty.",
                exitCode: -1
            )
        }

        var arguments: [String] = ["create", input.title]
        if let type = input.issueType, !type.isEmpty {
            arguments.append(contentsOf: ["-t", type])
        }
        if let priority = input.priority {
            arguments.append(contentsOf: ["-p", String(priority)])
        }
        if let description = input.description, !description.isEmpty {
            arguments.append(contentsOf: ["-d", description])
        }
        if let acceptance = input.acceptanceCriteria, !acceptance.isEmpty {
            arguments.append(contentsOf: ["--acceptance", acceptance])
        }
        arguments.append("--json")

        return try await runDecodingIssue(arguments: arguments, in: workingDirectory)
    }

    public func claimIssue(
        id: String,
        assignee: String? = nil,
        in workingDirectory: URL
    ) async throws -> BeadIssue {
        try Self.validateID(id)
        var arguments: [String] = ["update", id, "--claim"]
        if let assignee, !assignee.isEmpty {
            arguments.append(contentsOf: ["--assignee", assignee])
        }
        arguments.append("--json")
        return try await runDecodingIssue(
            arguments: arguments,
            in: workingDirectory
        )
    }

    public func updateIssue(
        id: String,
        input: UpdateIssueInput,
        in workingDirectory: URL
    ) async throws -> BeadIssue {
        try Self.validateID(id)
        guard !input.isEmpty else {
            throw BeadsAppError.commandFailed(
                command: "bd update",
                stderr: "UpdateIssueInput has no fields to update.",
                exitCode: -1
            )
        }

        var arguments: [String] = ["update", id]
        if let title = input.title {
            arguments.append(contentsOf: ["--title", title])
        }
        if let description = input.description {
            arguments.append(contentsOf: ["-d", description])
        }
        if let priority = input.priority {
            arguments.append(contentsOf: ["-p", String(priority)])
        }
        if let status = input.status {
            arguments.append(contentsOf: ["-s", status])
        }
        if let assignee = input.assignee {
            arguments.append(contentsOf: ["--assignee", assignee])
        }
        arguments.append("--json")

        return try await runDecodingIssue(arguments: arguments, in: workingDirectory)
    }

    public func closeIssue(id: String, reason: String, in workingDirectory: URL) async throws -> BeadIssue {
        try Self.validateID(id)
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeadsAppError.commandFailed(
                command: "bd close",
                stderr: "Close reason must not be empty.",
                exitCode: -1
            )
        }

        return try await runDecodingIssue(
            arguments: ["close", id, "--reason", reason, "--json"],
            in: workingDirectory
        )
    }

    public func reopenIssue(id: String, in workingDirectory: URL) async throws -> BeadIssue {
        try Self.validateID(id)
        return try await runDecodingIssue(
            arguments: ["reopen", id, "--json"],
            in: workingDirectory
        )
    }

    public func addDependency(
        id: String,
        dependsOn: String,
        in workingDirectory: URL
    ) async throws {
        try Self.validateID(id)
        try Self.validateID(dependsOn)
        guard id != dependsOn else {
            throw BeadsAppError.commandFailed(
                command: "bd dep add",
                stderr: "Issue cannot depend on itself.",
                exitCode: -1
            )
        }
        _ = try await runExpectingSuccess(
            arguments: ["dep", "add", id, dependsOn],
            in: workingDirectory
        )
    }

    public func removeDependency(
        id: String,
        dependsOn: String,
        in workingDirectory: URL
    ) async throws {
        try Self.validateID(id)
        try Self.validateID(dependsOn)
        _ = try await runExpectingSuccess(
            arguments: ["dep", "remove", id, dependsOn],
            in: workingDirectory
        )
    }

    public func addLabel(id: String, label: String, in workingDirectory: URL) async throws -> BeadIssue {
        try Self.validateID(id)
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeadsAppError.commandFailed(
                command: "bd update",
                stderr: "Label must not be empty.",
                exitCode: -1
            )
        }
        return try await runDecodingIssue(
            arguments: ["update", id, "--add-label", label, "--json"],
            in: workingDirectory
        )
    }

    public func removeLabel(id: String, label: String, in workingDirectory: URL) async throws -> BeadIssue {
        try Self.validateID(id)
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeadsAppError.commandFailed(
                command: "bd update",
                stderr: "Label must not be empty.",
                exitCode: -1
            )
        }
        return try await runDecodingIssue(
            arguments: ["update", id, "--remove-label", label, "--json"],
            in: workingDirectory
        )
    }

    // MARK: - Private helpers

    private static func validateID(_ id: String) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeadsAppError.commandFailed(
                command: "bd",
                stderr: "Issue id must not be empty.",
                exitCode: -1
            )
        }
    }

    private func runRaw(arguments: [String], in workingDirectory: URL) async throws -> CommandResult {
        try await commandRunner.run(command: "bd", arguments: arguments, workingDirectory: workingDirectory)
    }

    private func runExpectingSuccess(arguments: [String], in workingDirectory: URL) async throws -> CommandResult {
        let result: CommandResult
        do {
            result = try await runRaw(arguments: arguments, in: workingDirectory)
        } catch let error as ShellCommandRunnerError {
            throw mapRunnerError(
                error,
                arguments: arguments,
                workingDirectory: workingDirectory
            )
        } catch {
            throw BeadsAppError.commandFailed(
                command: Self.commandString(arguments),
                stderr: error.localizedDescription,
                exitCode: -1
            )
        }

        guard result.exitCode == 0 else {
            if result.exitCode == 127 || Self.looksLikeMissingBinary(result.stderr) {
                throw BeadsAppError.bdNotInstalled
            }
            if result.exitCode == 126 || Self.looksLikePermissionDenied(result.stderr) {
                throw BeadsAppError.permissionDenied(path: workingDirectory.path)
            }
            if Self.looksLikeUninitializedWorkspace(result.stderr) {
                throw BeadsAppError.beadsNotInitialized
            }
            throw BeadsAppError.commandFailed(
                command: Self.commandString(arguments),
                stderr: result.stderr,
                exitCode: result.exitCode
            )
        }
        return result
    }

    private func runDecodingIssues(arguments: [String], in workingDirectory: URL) async throws -> [BeadIssue] {
        let result = try await runExpectingSuccess(arguments: arguments, in: workingDirectory)
        do {
            return try BeadsJSONDecoder.decodeIssues(from: Data(result.stdout.utf8))
        } catch {
            throw BeadsError.jsonDecodeFailed(raw: result.stdout)
        }
    }

    private func runDecodingIssue(arguments: [String], in workingDirectory: URL) async throws -> BeadIssue {
        let result = try await runExpectingSuccess(arguments: arguments, in: workingDirectory)
        do {
            return try BeadsJSONDecoder.decodeIssue(from: Data(result.stdout.utf8))
        } catch {
            throw BeadsError.jsonDecodeFailed(raw: result.stdout)
        }
    }

    private func mapRunnerError(
        _ error: ShellCommandRunnerError,
        arguments: [String],
        workingDirectory: URL
    ) -> BeadsAppError {
        switch error {
        case .timedOut:
            return .timeout(command: Self.commandString(arguments))
        case .cancelled:
            return .commandFailed(
                command: Self.commandString(arguments),
                stderr: "Cancelled.",
                exitCode: -1
            )
        case let .launchFailed(command, underlying):
            if command == "bd" {
                if Self.looksLikePermissionDenied(underlying) {
                    return .permissionDenied(path: workingDirectory.path)
                }
                return .bdNotInstalled
            }

            return .commandFailed(
                command: command,
                stderr: underlying,
                exitCode: -1
            )
        }
    }

    private static func commandString(_ arguments: [String]) -> String {
        (["bd"] + arguments).joined(separator: " ")
    }

    private static func looksLikeMissingBinary(_ stderr: String) -> Bool {
        let message = stderr.lowercased()
        return message.contains("not found") || message.contains("no such file or directory")
    }

    private static func looksLikePermissionDenied(_ stderr: String) -> Bool {
        stderr.lowercased().contains("permission denied") || stderr.lowercased().contains("operation not permitted")
    }

    private static func looksLikeUninitializedWorkspace(_ stderr: String) -> Bool {
        let message = stderr.lowercased()
        return message.contains("no beads workspace") || message.contains("not a beads workspace")
    }
}
