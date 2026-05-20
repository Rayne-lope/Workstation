import Foundation

public enum GitStatusServiceError: LocalizedError, Sendable {
    case statusProbeFailed(detail: String)
    case malformedStatusLine(String)

    public var errorDescription: String? {
        switch self {
        case let .statusProbeFailed(detail):
            return "Unable to check git status: \(detail)"
        case let .malformedStatusLine(line):
            return "Unable to parse git status output: \(line)"
        }
    }
}

public struct GitStatusService: Sendable {
    private let commandRunner: any CommandRunning

    public init(commandRunner: any CommandRunning = ShellCommandRunner()) {
        self.commandRunner = commandRunner
    }

    public func statusSummary(in workingDirectory: URL) async throws -> GitStatusSummary {
        let statusResult = try await commandRunner.run(
            command: "git",
            arguments: ["status", "--porcelain"],
            workingDirectory: workingDirectory
        )

        guard statusResult.exitCode == 0 else {
            throw GitStatusServiceError.statusProbeFailed(detail: Self.detailMessage(for: statusResult))
        }

        let changedFiles = try Self.parseChangedFiles(from: statusResult.stdout)

        let branchName = await optionalValue(
            command: "git",
            arguments: ["branch", "--show-current"],
            workingDirectory: workingDirectory
        )

        let lastCommitSummary = await optionalValue(
            command: "git",
            arguments: ["log", "-1", "--pretty=format:%h%x20%s"],
            workingDirectory: workingDirectory
        )

        return GitStatusSummary(
            branchName: branchName,
            isDirty: !changedFiles.isEmpty,
            changedFiles: changedFiles,
            lastCommitSummary: lastCommitSummary
        )
    }

    private func optionalValue(
        command: String,
        arguments: [String],
        workingDirectory: URL
    ) async -> String? {
        do {
            let result = try await commandRunner.run(
                command: command,
                arguments: arguments,
                workingDirectory: workingDirectory
            )
            guard result.exitCode == 0 else { return nil }
            let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        } catch {
            return nil
        }
    }

    private static func parseChangedFiles(from output: String) throws -> [GitChangedFile] {
        var files: [GitChangedFile] = []
        for rawLine in output.split(whereSeparator: \.isNewline) {
            guard !rawLine.isEmpty else { continue }
            guard rawLine.count >= 3 else {
                throw GitStatusServiceError.malformedStatusLine(String(rawLine))
            }
            let status = normalizeStatusCode(String(rawLine.prefix(2)))
            let path = String(rawLine.dropFirst(3))
            files.append(GitChangedFile(path: path, status: status))
        }
        return files
    }

    private static func normalizeStatusCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? raw : trimmed
    }

    private static func detailMessage(for result: CommandResult) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty { return stderr }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty { return stdout }

        return "git status --porcelain exited with code \(result.exitCode)."
    }
}
