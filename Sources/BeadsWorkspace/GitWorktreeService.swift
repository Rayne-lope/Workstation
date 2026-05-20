#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation

public struct GitWorktreeLocation: Hashable, Sendable {
    public let worktreeRootURL: URL
    public let worktreeURL: URL
    public let branchName: String

    public init(worktreeRootURL: URL, worktreeURL: URL, branchName: String) {
        self.worktreeRootURL = worktreeRootURL
        self.worktreeURL = worktreeURL
        self.branchName = branchName
    }
}

public enum GitWorktreeServiceError: LocalizedError, Sendable {
    case notGitRepository(path: String)
    case dirtyWorkingTree(changedFiles: [GitChangedFile])
    case worktreeFolderExists(path: String)
    case branchAlreadyExists(name: String)
    case worktreeCreationFailed(detail: String)
    case symlinkFailed(detail: String)

    public var errorDescription: String? {
        switch self {
        case let .notGitRepository(path):
            return "Unable to create a worktree because \(path) is not a git repository."
        case let .dirtyWorkingTree(changedFiles):
            let preview = changedFiles.prefix(5).map(\.path).joined(separator: ", ")
            if preview.isEmpty {
                return "Working tree has uncommitted changes."
            }
            return "Working tree has uncommitted changes: \(preview)"
        case let .worktreeFolderExists(path):
            return "Worktree folder already exists at \(path)."
        case let .branchAlreadyExists(name):
            return "Branch \(name) already exists."
        case let .worktreeCreationFailed(detail):
            return "Failed to create git worktree: \(detail)"
        case let .symlinkFailed(detail):
            return "Failed to prepare worktree Beads link: \(detail)"
        }
    }
}

public struct GitWorktreeService: @unchecked Sendable {
    private let commandRunner: any CommandRunning
    private let fileManager: FileManager

    public init(
        commandRunner: any CommandRunning = ShellCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    public func worktreeLocation(for workspace: ProjectWorkspace, issueID: String) -> GitWorktreeLocation {
        let projectSlug = Self.slug(from: workspace.name, fallback: "workspace")
        let issueSlug = Self.slug(from: issueID, fallback: "issue")
        let rootURL = workspace.inspectionURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(projectSlug)-worktrees", isDirectory: true)
        let worktreeURL = rootURL.appendingPathComponent("\(projectSlug)-\(issueSlug)", isDirectory: true)
        let branchName = "agent/\(issueSlug)"
        return GitWorktreeLocation(
            worktreeRootURL: rootURL,
            worktreeURL: worktreeURL,
            branchName: branchName
        )
    }

    public func createWorktree(
        for issue: BeadIssue,
        in workspace: ProjectWorkspace
    ) async throws -> GitWorktreeLocation {
        try await ensureGitRepository(at: workspace.inspectionURL)

        let location = worktreeLocation(for: workspace, issueID: issue.id)

        if fileManager.fileExists(atPath: location.worktreeURL.path) {
            throw GitWorktreeServiceError.worktreeFolderExists(path: location.worktreeURL.path)
        }

        if try await branchExists(named: location.branchName, in: workspace.inspectionURL) {
            throw GitWorktreeServiceError.branchAlreadyExists(name: location.branchName)
        }

        do {
            try fileManager.createDirectory(
                at: location.worktreeRootURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw GitWorktreeServiceError.worktreeCreationFailed(detail: error.localizedDescription)
        }

        // Best-effort prune of stale `.git/worktrees/<name>` registrations that
        // would otherwise make `worktree add` fail with "missing but already
        // registered" when a user manually deleted a previous worktree folder.
        // Failures here are intentionally swallowed — prune is a recovery hint,
        // not a precondition.
        _ = try? await commandRunner.run(
            command: "git",
            arguments: ["worktree", "prune"],
            workingDirectory: workspace.inspectionURL
        )

        let result = try await commandRunner.run(
            command: "git",
            arguments: ["worktree", "add", location.worktreeURL.path, "-b", location.branchName],
            workingDirectory: workspace.inspectionURL
        )
        guard result.exitCode == 0 else {
            throw GitWorktreeServiceError.worktreeCreationFailed(detail: Self.detailMessage(for: result))
        }

        do {
            try createBeadsSymlinkIfNeeded(
                in: location.worktreeURL,
                sourceURL: workspace.inspectionURL.appendingPathComponent(".beads", isDirectory: true)
            )
        } catch {
            // Roll back the partially-created worktree so the next attempt is
            // not blocked by `worktreeFolderExists` / `branchAlreadyExists`.
            await rollbackWorktree(at: location, in: workspace.inspectionURL)
            throw error
        }
        return location
    }

    private func rollbackWorktree(at location: GitWorktreeLocation, in workingDirectory: URL) async {
        _ = try? await commandRunner.run(
            command: "git",
            arguments: ["worktree", "remove", "--force", location.worktreeURL.path],
            workingDirectory: workingDirectory
        )
        _ = try? await commandRunner.run(
            command: "git",
            arguments: ["branch", "-D", location.branchName],
            workingDirectory: workingDirectory
        )
    }

    private func ensureGitRepository(at workingDirectory: URL) async throws {
        let result = try await commandRunner.run(
            command: "git",
            arguments: ["rev-parse", "--is-inside-work-tree"],
            workingDirectory: workingDirectory
        )
        guard result.exitCode == 0 else {
            throw GitWorktreeServiceError.notGitRepository(path: workingDirectory.path)
        }
    }

    private func branchExists(named branchName: String, in workingDirectory: URL) async throws -> Bool {
        let result = try await commandRunner.run(
            command: "git",
            arguments: ["branch", "--list", branchName],
            workingDirectory: workingDirectory
        )
        guard result.exitCode == 0 else {
            return false
        }
        return !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func createBeadsSymlinkIfNeeded(in worktreeURL: URL, sourceURL: URL) throws {
        // Skip silently if the source `.beads` folder doesn't exist — creating
        // a symlink to a missing target would produce a dangling link and make
        // `bd` commands inside the worktree fail with cryptic errors.
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }

        let linkURL = worktreeURL.appendingPathComponent(".beads", isDirectory: true)
        guard !fileManager.fileExists(atPath: linkURL.path) else { return }

        do {
            try fileManager.createSymbolicLink(atPath: linkURL.path, withDestinationPath: sourceURL.path)
        } catch {
            throw GitWorktreeServiceError.symlinkFailed(detail: error.localizedDescription)
        }
    }

    private static func slug(from value: String, fallback: String) -> String {
        let lowered = value.lowercased()
        let mapped = lowered.unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
        }
        let raw = mapped.joined()
        let collapsed = raw.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func detailMessage(for result: CommandResult) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty { return stderr }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty { return stdout }

        return "git worktree add exited with code \(result.exitCode)."
    }
}
