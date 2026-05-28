import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("WorktreeDiscovery")
struct WorktreeDiscoveryTests {

    // MARK: - Helpers

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
                domain: "WorktreeDiscoveryTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }
    }

    private func makeGitRepo(name: String = "Discovery Project") throws -> (ProjectWorkspace, URL) {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("worktree-discovery-tests-\(UUID().uuidString)", isDirectory: true)
        let workspaceURL = baseURL.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: workspaceURL.appendingPathComponent(".beads", isDirectory: true),
            withIntermediateDirectories: true
        )
        try runGit(arguments: ["init", "-q"], in: workspaceURL)
        try runGit(arguments: ["config", "user.name", "Test User"], in: workspaceURL)
        try runGit(arguments: ["config", "user.email", "test@example.com"], in: workspaceURL)
        let readmeURL = workspaceURL.appendingPathComponent("README.md")
        try "hello\n".write(to: readmeURL, atomically: true, encoding: .utf8)
        try runGit(arguments: ["add", "README.md"], in: workspaceURL)
        try runGit(arguments: ["commit", "-m", "init"], in: workspaceURL)
        let workspace = ProjectWorkspace(
            selectedURL: workspaceURL,
            rootURL: workspaceURL,
            inspectionURL: workspaceURL,
            name: name,
            validationState: .valid,
            checks: []
        )
        return (workspace, baseURL)
    }

    private func makeIssue(id: String, status: String = "open") -> BeadIssue {
        BeadIssue(id: id, title: "Test \(id)", status: status, priority: 2, issueType: "task")
    }

    private let service = GitWorktreeService(commandRunner: ShellCommandRunner(timeout: 15))

    // MARK: - Tests

    @Test("Returns empty array when worktrees root does not exist")
    func discoverNoRoot() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "No Root")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let result = await service.discoverWorktrees(in: workspace, issues: [makeIssue(id: "Proj-abc")])
        #expect(result.isEmpty)
    }

    @Test("Returns empty array when worktrees root is empty")
    func discoverEmptyRoot() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "Empty Root")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        // Create root dir but leave it empty
        let rootURL = service.worktreeLocation(for: workspace, issueID: "x").worktreeRootURL
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let result = await service.discoverWorktrees(in: workspace, issues: [])
        #expect(result.isEmpty)
    }

    @Test("Classifies open-issue worktree as active")
    func discoverActiveWorktree() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "Active Worktree")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let issue = makeIssue(id: "Proj-111", status: "open")
        let location = try await service.createWorktree(for: issue, in: workspace)

        let result = await service.discoverWorktrees(in: workspace, issues: [issue])

        #expect(result.count == 1)
        let discovered = try #require(result.first)
        #expect(discovered.status == .active)
        #expect(discovered.issueID == issue.id)
        #expect(discovered.issue?.id == issue.id)
        let resolvedPath = location.worktreeURL.resolvingSymlinksInPath().path
        #expect(discovered.location.worktreeURL.resolvingSymlinksInPath().path == resolvedPath)
    }

    @Test("Classifies closed-issue worktree as stale")
    func discoverStaleWorktree() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "Stale Worktree")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        // Create worktree with an open issue, then simulate it being closed
        let openIssue = makeIssue(id: "Proj-222", status: "open")
        _ = try await service.createWorktree(for: openIssue, in: workspace)

        let closedIssue = makeIssue(id: "Proj-222", status: "closed")
        let result = await service.discoverWorktrees(in: workspace, issues: [closedIssue])

        #expect(result.count == 1)
        let discovered = try #require(result.first)
        #expect(discovered.status == .stale)
        #expect(discovered.issueID == closedIssue.id)
    }

    @Test("Classifies worktree with no matching issue as orphan")
    func discoverOrphanWorktree() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "Orphan Worktree")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let issue = makeIssue(id: "Proj-333", status: "open")
        let location = service.worktreeLocation(for: workspace, issueID: issue.id)
        _ = try await service.createWorktree(for: issue, in: workspace)

        // Provide empty issue list — no match possible
        let result = await service.discoverWorktrees(in: workspace, issues: [])

        #expect(result.count == 1)
        let discovered = try #require(result.first)
        #expect(discovered.status == .orphan)
        #expect(discovered.issue == nil)
        // issueID extracted from branch name (the slug)
        let expectedSlug = location.branchName.hasPrefix("agent/")
            ? String(location.branchName.dropFirst("agent/".count))
            : nil
        #expect(discovered.issueID == expectedSlug)
    }

    @Test("Classifies mixed worktrees correctly in one pass")
    func discoverMixedWorktrees() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "Mixed Worktrees")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let activeIssue = makeIssue(id: "Proj-aaa", status: "open")
        let closedIssue = makeIssue(id: "Proj-bbb", status: "closed")
        let orphanIssue = makeIssue(id: "Proj-ccc", status: "open")

        _ = try await service.createWorktree(for: activeIssue, in: workspace)
        _ = try await service.createWorktree(for: closedIssue, in: workspace)
        _ = try await service.createWorktree(for: orphanIssue, in: workspace)

        // Only provide active + closed issues; ccc is absent → orphan
        let result = await service.discoverWorktrees(
            in: workspace,
            issues: [activeIssue, closedIssue]
        )

        #expect(result.count == 3)

        let statuses = Set(result.map(\.status))
        #expect(statuses.contains(.active))
        #expect(statuses.contains(.stale))
        #expect(statuses.contains(.orphan))

        let active = try #require(result.first { $0.status == .active })
        #expect(active.issueID == activeIssue.id)

        let stale = try #require(result.first { $0.status == .stale })
        #expect(stale.issueID == closedIssue.id)

        let orphan = try #require(result.first { $0.status == .orphan })
        #expect(orphan.issue == nil)
    }

    @Test("Branch with refs/heads/ prefix is correctly stripped by listWorktrees")
    func porcelainBranchPrefixStripping() async throws {
        let (workspace, baseURL) = try makeGitRepo(name: "Branch Prefix")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let issue = makeIssue(id: "Proj-pfx", status: "open")
        _ = try await service.createWorktree(for: issue, in: workspace)

        // listWorktrees is used internally by discoverWorktrees;
        // verify it strips refs/heads/ so the branch is plain "agent/proj-pfx"
        let worktrees = try await service.listWorktrees(in: workspace.inspectionURL)
        let agentWorktree = worktrees.first { $0.branchName?.hasPrefix("agent/") == true }
        let branchName = try #require(agentWorktree?.branchName)
        #expect(!branchName.hasPrefix("refs/heads/"))
        #expect(branchName.hasPrefix("agent/"))
    }
}
