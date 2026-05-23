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
    case noChangesToCommit(worktreePath: String)
    case commitFailed(detail: String)
    case pushFailed(detail: String)
    case worktreeRemovalFailed(detail: String)

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
        case let .noChangesToCommit(worktreePath):
            return "No changes to commit in worktree at \(worktreePath)."
        case let .commitFailed(detail):
            return "Git commit failed: \(detail)"
        case let .pushFailed(detail):
            return "Git push failed: \(detail)"
        case let .worktreeRemovalFailed(detail):
            return "Failed to remove worktree: \(detail)"
        }
    }
}

public struct GitWorktreeLaunchPreflight: Hashable, Sendable {
    public let location: GitWorktreeLocation
    public let workspaceSetupHints: [WorkspaceSetupHint]
    public let statusSummary: GitStatusSummary?
    public let statusError: String?
    public let existingWorktreePath: String?
    public let branchConflictName: String?
    public let reusableWorktreePath: String?

    public init(
        location: GitWorktreeLocation,
        workspaceSetupHints: [WorkspaceSetupHint],
        statusSummary: GitStatusSummary?,
        statusError: String?,
        existingWorktreePath: String?,
        branchConflictName: String?,
        reusableWorktreePath: String? = nil
    ) {
        self.location = location
        self.workspaceSetupHints = workspaceSetupHints
        self.statusSummary = statusSummary
        self.statusError = statusError
        self.existingWorktreePath = existingWorktreePath
        self.branchConflictName = branchConflictName
        self.reusableWorktreePath = reusableWorktreePath
    }

    /// True when the worktree cannot be created due to orphan conflicts
    /// (folder-only or branch-only), setup issues, or status errors.
    /// A matching folder+branch pair (reusable) is NOT blocked.
    public var isBlocked: Bool {
        !workspaceSetupHints.isEmpty
            || statusError != nil
            || existingWorktreePath != nil
            || branchConflictName != nil
    }

    /// True when both folder and branch already exist for this issue's worktree,
    /// meaning we can relaunch Terminal there without running `git worktree add`.
    public var canReuseExistingWorktree: Bool {
        reusableWorktreePath != nil
    }

    public var requiresConfirmation: Bool {
        statusSummary?.isDirty == true
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

    public func preflightLaunch(
        for issue: BeadIssue,
        in workspace: ProjectWorkspace
    ) async -> GitWorktreeLaunchPreflight {
        let location = worktreeLocation(for: workspace, issueID: issue.id)

        var statusSummary: GitStatusSummary?
        var statusError: String?
        do {
            statusSummary = try await GitStatusService(commandRunner: commandRunner).statusSummary(in: workspace.inspectionURL)
        } catch {
            statusError = error.localizedDescription
        }

        let folderExists = fileManager.fileExists(atPath: location.worktreeURL.path)
        var branchConflictDetected = false
        do {
            branchConflictDetected = try await branchExists(named: location.branchName, in: workspace.inspectionURL)
        } catch {
            branchConflictDetected = false
            if statusError == nil {
                statusError = error.localizedDescription
            }
        }

        // Distinguish three mutually-exclusive states:
        //  • folder+branch → reusable (same-issue worktree, NOT blocked)
        //  • folder only   → orphan folder (blocked)
        //  • branch only   → orphan branch (blocked)
        let reusableWorktreePath: String?
        let existingWorktreePath: String?
        let branchConflictName: String?

        if folderExists && branchConflictDetected {
            reusableWorktreePath = location.worktreeURL.path
            existingWorktreePath = nil
            branchConflictName = nil
        } else {
            reusableWorktreePath = nil
            existingWorktreePath = folderExists ? location.worktreeURL.path : nil
            branchConflictName = branchConflictDetected ? location.branchName : nil
        }

        return GitWorktreeLaunchPreflight(
            location: location,
            workspaceSetupHints: workspace.setupHints,
            statusSummary: statusSummary,
            statusError: statusError,
            existingWorktreePath: existingWorktreePath,
            branchConflictName: branchConflictName,
            reusableWorktreePath: reusableWorktreePath
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

    /// Remove an orphan or stale worktree folder + branch so a fresh
    /// `createWorktree` can succeed on the next attempt.
    public func cleanupOrphanWorktree(
        for issue: BeadIssue,
        in workspace: ProjectWorkspace
    ) async {
        let location = worktreeLocation(for: workspace, issueID: issue.id)
        await rollbackWorktree(at: location, in: workspace.inspectionURL)
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

    // MARK: - Commit & Push

    /// Get the diff of all changed files in the worktree.
    public func getDiff(in worktreeURL: URL) async throws -> String {
        let result = try await commandRunner.run(
            command: "git",
            arguments: ["diff", "--no-color"],
            workingDirectory: worktreeURL
        )
        guard result.exitCode == 0 else {
            throw GitWorktreeServiceError.commitFailed(detail: Self.detailMessage(for: result))
        }
        return result.stdout
    }

    /// Get the diff of staged files only.
    public func getStagedDiff(in worktreeURL: URL) async throws -> String {
        let result = try await commandRunner.run(
            command: "git",
            arguments: ["diff", "--cached", "--no-color"],
            workingDirectory: worktreeURL
        )
        guard result.exitCode == 0 else {
            throw GitWorktreeServiceError.commitFailed(detail: Self.detailMessage(for: result))
        }
        return result.stdout
    }

    /// Get a summary of changed file paths and statuses.
    public func getChangedFilesSummary(in worktreeURL: URL) async throws -> String {
        let result = try await commandRunner.run(
            command: "git",
            arguments: ["status", "--porcelain"],
            workingDirectory: worktreeURL
        )
        guard result.exitCode == 0 else {
            throw GitWorktreeServiceError.commitFailed(detail: Self.detailMessage(for: result))
        }
        let lines = result.stdout
            .split(whereSeparator: \.isNewline)
            .map { line -> String in
                let parts = line.split(separator: " ", maxSplits: 1)
                if parts.count >= 2 {
                    return "\(parts[0]) \(parts[1])"
                }
                return String(line)
            }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return lines.isEmpty ? "" : lines.joined(separator: "\n")
    }

    /// Get the last commit message on the current branch.
    public func getLastCommitMessage(in worktreeURL: URL) async throws -> String? {
        let result = try await commandRunner.run(
            command: "git",
            arguments: ["log", "-1", "--pretty=format:%s", "HEAD"],
            workingDirectory: worktreeURL
        )
        guard result.exitCode == 0 else { return nil }
        let message = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }

    /// Stage all changes and commit with the given message.
    public func commitChanges(
        message: String,
        in worktreeURL: URL
    ) async throws {
        // Stage all changes
        let stageResult = try await commandRunner.run(
            command: "git",
            arguments: ["add", "-A"],
            workingDirectory: worktreeURL
        )
        guard stageResult.exitCode == 0 else {
            throw GitWorktreeServiceError.commitFailed(detail: Self.detailMessage(for: stageResult))
        }

        // Check if there are staged changes
        let statusResult = try await commandRunner.run(
            command: "git",
            arguments: ["status", "--porcelain"],
            workingDirectory: worktreeURL
        )
        guard statusResult.exitCode == 0 else {
            throw GitWorktreeServiceError.commitFailed(detail: Self.detailMessage(for: statusResult))
        }
        let hasChanges = !statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasChanges {
            throw GitWorktreeServiceError.noChangesToCommit(worktreePath: worktreeURL.path)
        }

        // Commit
        let commitResult = try await commandRunner.run(
            command: "git",
            arguments: ["commit", "-m", message],
            workingDirectory: worktreeURL
        )
        guard commitResult.exitCode == 0 else {
            throw GitWorktreeServiceError.commitFailed(detail: Self.detailMessage(for: commitResult))
        }
    }

    /// Push the current branch to the origin remote.
    public func pushCurrentBranch(from worktreeURL: URL) async throws {
        let result = try await commandRunner.run(
            command: "git",
            arguments: ["push", "-u", "origin", "HEAD"],
            workingDirectory: worktreeURL
        )
        guard result.exitCode == 0 else {
            throw GitWorktreeServiceError.pushFailed(detail: Self.detailMessage(for: result))
        }
    }

    /// Execute commit and push in one operation.
    /// - Parameters:
    ///   - message: The commit message to use.
    ///   - worktreeURL: The worktree directory to commit and push from.
    /// - Throws: GitWorktreeServiceError if commit or push fails.
    public func commitAndPush(
        message: String,
        in worktreeURL: URL
    ) async throws {
        try await commitChanges(message: message, in: worktreeURL)
        try await pushCurrentBranch(from: worktreeURL)
    }

    /// Remove the git worktree folder and delete the associated branch.
    /// This is used after successfully committing and pushing to clean up.
    /// - Parameters:
    ///   - location: The worktree location to remove.
    ///   - workingDirectory: The root git repository (not the worktree) for branch deletion.
    /// - Throws: GitWorktreeServiceError if removal fails.
    public func removeWorktree(location: GitWorktreeLocation, workingDirectory: URL) async throws {
        // Remove worktree folder
        let removeResult = try await commandRunner.run(
            command: "git",
            arguments: ["worktree", "remove", "--force", location.worktreeURL.path],
            workingDirectory: workingDirectory
        )
        guard removeResult.exitCode == 0 else {
            throw GitWorktreeServiceError.worktreeRemovalFailed(detail: Self.detailMessage(for: removeResult))
        }

        // Delete the branch (safe because we already pushed)
        let branchResult = try await commandRunner.run(
            command: "git",
            arguments: ["branch", "-D", location.branchName],
            workingDirectory: workingDirectory
        )
        if branchResult.exitCode != 0 {
            // Non-fatal: branch may already be gone or not fully pushed
            // Log but don't throw — the worktree folder removal is the primary concern
            NSLog("Failed to delete branch %@: %@", location.branchName, Self.detailMessage(for: branchResult))
        }
    }
}
