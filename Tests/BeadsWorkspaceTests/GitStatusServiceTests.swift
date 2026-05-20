import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("GitStatusService")
struct GitStatusServiceTests {
    private func makeService(runner: StubCommandRunner) -> GitStatusService {
        GitStatusService(commandRunner: runner)
    }

    @Test("statusSummary returns a clean tree with branch and last commit context")
    func cleanTreeIncludesOptionalMetadata() async throws {
        let folder = makeTemporaryDirectory(named: "git-clean tree")
        defer { try? FileManager.default.removeItem(at: folder) }

        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["status", "--porcelain"], stdout: "")
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "main\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "abc123 Fix launch path\n")

        let summary = try await makeService(runner: runner).statusSummary(in: folder)

        #expect(summary.isDirty == false)
        #expect(summary.changedFiles.isEmpty)
        #expect(summary.branchName == "main")
        #expect(summary.lastCommitSummary == "abc123 Fix launch path")
        #expect(runner.calls.map(\.arguments) == [
            ["status", "--porcelain"],
            ["branch", "--show-current"],
            ["log", "-1", "--pretty=format:%h%x20%s"]
        ])
        #expect(runner.calls[0].workingDirectory.path == folder.path)
    }

    @Test("statusSummary parses changed files from a dirty tree")
    func dirtyTreeParsesChangedFiles() async throws {
        let folder = makeTemporaryDirectory(named: "git-dirty-tree")
        defer { try? FileManager.default.removeItem(at: folder) }

        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: ["status", "--porcelain"],
            stdout: """
            M  App/AppViewModel.swift
            ?? Tests/New File.swift
            R  Old Name.swift -> New Name.swift
            """
        )
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "feature/dirty-check\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "feedbeef WIP dirty-check\n")

        let summary = try await makeService(runner: runner).statusSummary(in: folder)

        #expect(summary.isDirty == true)
        #expect(summary.changedFiles == [
            GitChangedFile(path: "App/AppViewModel.swift", status: "M"),
            GitChangedFile(path: "Tests/New File.swift", status: "??"),
            GitChangedFile(path: "Old Name.swift -> New Name.swift", status: "R")
        ])
        #expect(summary.branchName == "feature/dirty-check")
        #expect(summary.lastCommitSummary == "feedbeef WIP dirty-check")
    }

    @Test("statusSummary preserves folders with spaces")
    func workingDirectoryWithSpacesIsPassedThrough() async throws {
        let folder = makeTemporaryDirectory(named: "folder with spaces")
        defer { try? FileManager.default.removeItem(at: folder) }

        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["status", "--porcelain"], stdout: "")
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "")

        _ = try await makeService(runner: runner).statusSummary(in: folder)

        #expect(runner.calls.first?.workingDirectory.path == folder.path)
    }

    @Test("statusSummary blocks launch when git status cannot be probed")
    func probeFailureBlocksLaunch() async throws {
        let folder = makeTemporaryDirectory(named: "git-probe-failure")
        defer { try? FileManager.default.removeItem(at: folder) }

        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: ["status", "--porcelain"],
            stderr: "fatal: not a git repository (or any of the parent directories): .git",
            exitCode: 1
        )

        await #expect(throws: GitStatusServiceError.self) {
            _ = try await makeService(runner: runner).statusSummary(in: folder)
        }
    }

    private func makeTemporaryDirectory(named name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
