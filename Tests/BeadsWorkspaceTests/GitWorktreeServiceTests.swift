import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("GitWorktreeService")
struct GitWorktreeServiceTests {
    private func makeService(runner: StubCommandRunner) -> GitWorktreeService {
        GitWorktreeService(commandRunner: runner)
    }

    private func makeWorkspace(rootName: String = "Workstation Project") throws -> (ProjectWorkspace, URL) {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("git-worktree-service-tests-\(UUID().uuidString)", isDirectory: true)
        let workspaceURL = baseURL.appendingPathComponent(rootName, isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: workspaceURL.appendingPathComponent(".beads", isDirectory: true),
            withIntermediateDirectories: true
        )
        return (
            ProjectWorkspace(
                selectedURL: workspaceURL,
                rootURL: workspaceURL,
                inspectionURL: workspaceURL,
                name: rootName,
                validationState: .valid,
                checks: []
            ),
            baseURL
        )
    }

    private func runGit(arguments: [String], in workingDirectory: URL) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            throw NSError(
                domain: "GitWorktreeServiceTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }
    }

    private func makeGitRepo(name: String = "Workstation Project") throws -> (ProjectWorkspace, URL) {
        let (workspace, baseURL) = try makeWorkspace(rootName: name)
        try runGit(arguments: ["init", "-q"], in: workspace.inspectionURL)
        try runGit(arguments: ["config", "user.name", "Test User"], in: workspace.inspectionURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], in: workspace.inspectionURL)

        let readmeURL = workspace.inspectionURL.appendingPathComponent("README.md")
        try "hello\n".write(to: readmeURL, atomically: true, encoding: .utf8)

        try runGit(arguments: ["add", "README.md"], in: workspace.inspectionURL)
        try runGit(arguments: ["commit", "-m", "init"], in: workspace.inspectionURL)
        return (workspace, baseURL)
    }

    @Test("location derives a stable worktree folder and branch from the project and issue")
    func locationDerivationUsesSanitizedIdentifiers() throws {
        let (workspace, baseURL) = try makeWorkspace(rootName: "Workstation Project")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let service = makeService(runner: StubCommandRunner())
        let location = service.worktreeLocation(for: workspace, issueID: "Workstation-tgc / 123")

        #expect(location.branchName == "agent/workstation-tgc-123")
        #expect(location.worktreeRootURL.lastPathComponent == "workstation-project-worktrees")
        #expect(location.worktreeURL.lastPathComponent == "workstation-project-workstation-tgc-123")
    }

    @Test("createWorktree creates a real worktree and keeps the main tree clean")
    func createWorktreeCreatesIsolatedCheckout() async throws {
        let (workspace, baseURL) = try makeGitRepo()
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let service = GitWorktreeService(commandRunner: ShellCommandRunner(timeout: 10))
        let issue = BeadIssue(
            id: "Workstation-tgc / 123",
            title: "Isolated worktree",
            status: "open",
            priority: 2,
            issueType: "feature"
        )

        let location = service.worktreeLocation(for: workspace, issueID: issue.id)
        let created = try await service.createWorktree(for: issue, in: workspace)

        #expect(created == location)
        #expect(FileManager.default.fileExists(atPath: location.worktreeURL.path))
        #expect(FileManager.default.fileExists(atPath: location.worktreeURL.appendingPathComponent(".beads").path))

        let beadsLinkTarget = try FileManager.default.destinationOfSymbolicLink(
            atPath: location.worktreeURL.appendingPathComponent(".beads").path
        )
        #expect(beadsLinkTarget == workspace.inspectionURL.appendingPathComponent(".beads").path)

        let statusResult = try await ShellCommandRunner(timeout: 10).run(
            command: "git",
            arguments: ["status", "--porcelain"],
            workingDirectory: workspace.inspectionURL
        )
        #expect(statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let branchResult = try await ShellCommandRunner(timeout: 10).run(
            command: "git",
            arguments: ["branch", "--show-current"],
            workingDirectory: location.worktreeURL
        )
        #expect(branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == location.branchName)
    }

    @Test("createWorktree ignores passive Beads export noise in the current tree")
    func createWorktreeIgnoresBeadsExportNoise() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "Beads Noise")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let trackedExportURL = workspace.inspectionURL.appendingPathComponent(".beads/issues.jsonl")
        try "[]\n".write(to: trackedExportURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", ".beads/issues.jsonl"], in: workspace.inspectionURL)
        try runGit(arguments: ["commit", "-m", "track beads export"], in: workspace.inspectionURL)
        try "{\"id\":\"Workstation-noise\"}\n".write(to: trackedExportURL, atomically: true, encoding: .utf8)

        let service = GitWorktreeService(commandRunner: ShellCommandRunner(timeout: 10))
        let issue = BeadIssue(
            id: "Workstation-noise",
            title: "Ignore Beads export noise",
            status: "open",
            priority: 2,
            issueType: "feature"
        )

        let location = service.worktreeLocation(for: workspace, issueID: issue.id)
        let created = try await service.createWorktree(for: issue, in: workspace)

        #expect(created == location)
        #expect(FileManager.default.fileExists(atPath: location.worktreeURL.path))
        #expect(FileManager.default.fileExists(atPath: location.worktreeURL.appendingPathComponent(".beads").path))
    }

    @Test("createWorktree refuses when the current tree is dirty")
    func createWorktreeRefusesWhenDirty() async throws {
        let (workspace, baseURL) = try makeWorkspace(rootName: "Dirty Tree")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["rev-parse", "--is-inside-work-tree"], stdout: "true\n")
        runner.enqueue(
            arguments: ["status", "--porcelain"],
            stdout: """
            M  App/AppViewModel.swift
            ?? Notes to keep.txt
            """
        )
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "main\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "abc123 Dirty tree\n")

        let service = makeService(runner: runner)
        let issue = BeadIssue(
            id: "bd-123",
            title: "Dirty tree",
            status: "open",
            priority: 2,
            issueType: "feature"
        )

        await #expect(throws: GitWorktreeServiceError.self) {
            _ = try await service.createWorktree(for: issue, in: workspace)
        }
    }

    @Test("createWorktree refuses when the target folder already exists")
    func createWorktreeRefusesWhenFolderExists() async throws {
        let (workspace, baseURL) = try makeWorkspace(rootName: "Existing Folder")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["rev-parse", "--is-inside-work-tree"], stdout: "true\n")
        runner.enqueue(arguments: ["status", "--porcelain"], stdout: "")
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "main\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "abc123 Clean tree\n")

        let service = makeService(runner: runner)
        let issue = BeadIssue(
            id: "bd-123",
            title: "Existing folder",
            status: "open",
            priority: 2,
            issueType: "feature"
        )
        let location = service.worktreeLocation(for: workspace, issueID: issue.id)
        try FileManager.default.createDirectory(at: location.worktreeURL, withIntermediateDirectories: true)

        await #expect(throws: GitWorktreeServiceError.self) {
            _ = try await service.createWorktree(for: issue, in: workspace)
        }
        #expect(runner.calls.contains { $0.arguments == ["status", "--porcelain"] })
        #expect(runner.calls.contains { $0.arguments == ["branch", "--show-current"] })
        #expect(!runner.calls.contains { $0.arguments == ["branch", "--list", location.branchName] })
    }

    @Test("createWorktree refuses when the branch already exists")
    func createWorktreeRefusesWhenBranchExists() async throws {
        let (workspace, baseURL) = try makeWorkspace(rootName: "Branch Exists")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["rev-parse", "--is-inside-work-tree"], stdout: "true\n")
        runner.enqueue(arguments: ["status", "--porcelain"], stdout: "")
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "main\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "abc123 Clean tree\n")
        runner.enqueue(arguments: ["branch", "--list", "agent/bd-123"], stdout: "  agent/bd-123\n")

        let service = makeService(runner: runner)
        let issue = BeadIssue(
            id: "bd-123",
            title: "Branch exists",
            status: "open",
            priority: 2,
            issueType: "feature"
        )

        await #expect(throws: GitWorktreeServiceError.self) {
            _ = try await service.createWorktree(for: issue, in: workspace)
        }
        #expect(!runner.calls.contains { $0.arguments == ["worktree", "add", service.worktreeLocation(for: workspace, issueID: issue.id).worktreeURL.path, "-b", "agent/bd-123"] })
    }

    @Test("createWorktree prunes stale worktree registrations before invoking worktree add")
    func createWorktreePrunesBeforeAdd() async throws {
        let (workspace, baseURL) = try makeWorkspace(rootName: "Prune Before Add")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let runner = StubCommandRunner()
        let service = makeService(runner: runner)
        let issue = BeadIssue(
            id: "bd-prune",
            title: "Prune before add",
            status: "open",
            priority: 2,
            issueType: "feature"
        )
        let location = service.worktreeLocation(for: workspace, issueID: issue.id)

        runner.enqueue(arguments: ["rev-parse", "--is-inside-work-tree"], stdout: "true\n")
        runner.enqueue(arguments: ["status", "--porcelain"], stdout: "")
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "main\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "abc123 Clean\n")
        runner.enqueue(arguments: ["branch", "--list", location.branchName], stdout: "")
        runner.enqueue(arguments: ["worktree", "prune"], stdout: "")
        // Force `worktree add` to fail so we exit before symlink creation
        // (which needs a real on-disk worktree folder created by git).
        runner.enqueue(
            arguments: ["worktree", "add", location.worktreeURL.path, "-b", location.branchName],
            stdout: "",
            stderr: "fatal: simulated add failure\n",
            exitCode: 128
        )

        await #expect(throws: GitWorktreeServiceError.self) {
            _ = try await service.createWorktree(for: issue, in: workspace)
        }

        let pruneIndex = runner.calls.firstIndex { $0.arguments == ["worktree", "prune"] }
        let addIndex = runner.calls.firstIndex { call in
            guard call.arguments.count >= 2 else { return false }
            return call.arguments[0] == "worktree" && call.arguments[1] == "add"
        }
        #expect(pruneIndex != nil)
        #expect(addIndex != nil)
        if let pruneIndex, let addIndex {
            #expect(pruneIndex < addIndex)
        }
    }

    @Test("createWorktree skips symlink creation when the source .beads folder is missing")
    func createWorktreeSkipsSymlinkWhenSourceMissing() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "Missing Beads Source")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        // Remove the `.beads` folder created by makeGitRepo so the source is missing.
        try FileManager.default.removeItem(at: workspace.inspectionURL.appendingPathComponent(".beads"))

        let service = GitWorktreeService(commandRunner: ShellCommandRunner(timeout: 10))
        let issue = BeadIssue(
            id: "bd-nobeads",
            title: "No beads source",
            status: "open",
            priority: 2,
            issueType: "feature"
        )

        let location = try await service.createWorktree(for: issue, in: workspace)

        let linkPath = location.worktreeURL.appendingPathComponent(".beads").path
        #expect(!FileManager.default.fileExists(atPath: linkPath))
        // Worktree itself should still be valid.
        let branchResult = try await ShellCommandRunner(timeout: 10).run(
            command: "git",
            arguments: ["branch", "--show-current"],
            workingDirectory: location.worktreeURL
        )
        #expect(branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == location.branchName)
    }

}
