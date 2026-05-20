import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("Shell Command Runner")
struct ShellCommandRunnerTests {
    @Test("Captures stdout stderr and non-zero exit code")
    func capturesOutputAndExitCode() async throws {
        let runner = ShellCommandRunner(timeout: 5)
        let folder = try makeTemporaryDirectory(named: "runner-output")
        defer { try? FileManager.default.removeItem(at: folder) }

        let result = try await runner.run(
            command: "sh",
            arguments: ["-c", "echo out; echo err 1>&2; exit 7"],
            workingDirectory: folder
        )

        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "out")
        #expect(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines) == "err")
        #expect(result.exitCode == 7)
        #expect(result.durationMs >= 0)
        #expect(runner.history.count == 1)
        #expect(runner.history[0].exitCode == 7)
        #expect(runner.history[0].errorMessage == nil)
    }

    @Test("Uses the requested working directory")
    func usesRequestedWorkingDirectory() async throws {
        let runner = ShellCommandRunner(timeout: 5)
        let folder = try makeTemporaryDirectory(named: "runner-cwd")
        defer { try? FileManager.default.removeItem(at: folder) }

        let result = try await runner.run(
            command: "pwd",
            arguments: [],
            workingDirectory: folder
        )

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(output.contains("runner-cwd"))
        #expect(output.contains(folder.lastPathComponent))
    }

    @Test("Times out long running commands")
    func timesOutLongRunningCommands() async throws {
        let runner = ShellCommandRunner(timeout: 0.1)
        let folder = try makeTemporaryDirectory(named: "runner-timeout")
        defer { try? FileManager.default.removeItem(at: folder) }

        do {
            _ = try await runner.run(
                command: "sh",
                arguments: ["-c", "sleep 2"],
                workingDirectory: folder
            )
            Issue.record("Expected timeout error")
        } catch let error as ShellCommandRunnerError {
            switch error {
            case .timedOut:
                break
            default:
                Issue.record("Unexpected error: \(error.localizedDescription)")
            }
        }
    }

    @Test("Cancels running commands")
    func cancelsRunningCommands() async throws {
        let runner = ShellCommandRunner(timeout: 10)
        let folder = try makeTemporaryDirectory(named: "runner-cancel")
        defer { try? FileManager.default.removeItem(at: folder) }

        let task = Task {
            try await runner.run(
                command: "sh",
                arguments: ["-c", "sleep 5"],
                workingDirectory: folder
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation error")
        } catch let error as ShellCommandRunnerError {
            switch error {
            case .cancelled:
                break
            default:
                Issue.record("Unexpected error: \(error.localizedDescription)")
            }
        }
    }

    @Test("Records history metadata for every run")
    func recordsHistoryMetadataForEveryRun() async throws {
        let runner = ShellCommandRunner(timeout: 5)
        let folder = try makeTemporaryDirectory(named: "runner-history")
        defer { try? FileManager.default.removeItem(at: folder) }

        _ = try await runner.run(
            command: "sh",
            arguments: ["-c", "echo history"],
            workingDirectory: folder
        )

        #expect(runner.history.count == 1)
        let snapshot = runner.history[0]
        #expect(snapshot.command == "sh")
        #expect(snapshot.arguments == ["-c", "echo history"])
        #expect(snapshot.workingDirectory == folder)
        #expect(snapshot.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "history")
        #expect(snapshot.timestamp <= .now)
    }

    @Test("Smoke tests bd and git from repository root")
    func smokeTestsBdAndGitFromRepositoryRoot() async throws {
        let root = repoRoot()
        let runner = ShellCommandRunner(timeout: 10)

        let bdProbe = try await runner.run(
            command: "sh",
            arguments: ["-c", "command -v bd >/dev/null 2>&1"],
            workingDirectory: root
        )

        guard bdProbe.exitCode == 0 else {
            return
        }

        let bdVersion = try await runner.run(
            command: "bd",
            arguments: ["--version"],
            workingDirectory: root
        )
        #expect(bdVersion.exitCode == 0)

        let gitStatus = try await runner.run(
            command: "git",
            arguments: ["status", "--short"],
            workingDirectory: root
        )
        #expect(gitStatus.exitCode == 0)

        let bdList = try await runner.run(
            command: "bd",
            arguments: ["list", "--json"],
            workingDirectory: root
        )
        #expect(bdList.exitCode == 0)
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return URL(fileURLWithPath: url.path, isDirectory: true)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
