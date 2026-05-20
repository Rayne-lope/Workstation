import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("Workspace Validator")
struct WorkspaceValidatorTests {
    @Test("Warns when Beads marker is missing")
    func warnsWhenBeadsMarkerIsMissing() async throws {
        let folder = try makeTemporaryDirectory(named: "git-only")
        defer { try? FileManager.default.removeItem(at: folder) }

        FileManager.default.createFile(atPath: folder.appendingPathComponent(".git").path, contents: Data(), attributes: nil)
        FileManager.default.createFile(atPath: folder.appendingPathComponent("AGENTS.md").path, contents: Data(), attributes: nil)

        let runner = MockCommandRunner(responses: [
            "bd|--version": .success(command: "bd", arguments: ["--version"], cwd: folder, stdout: "bd 1.0.0", stderr: "", exitCode: 0),
            "bd|list|--json": .failure(command: "bd", arguments: ["list", "--json"], cwd: folder, stdout: "", stderr: "should not run", exitCode: 1)
        ])

        let workspace = try await WorkspaceValidator(commandRunner: runner).validate(selection: folder)

        #expect(workspace.validationState == .missing)
        #expect(workspace.suggestion?.contains("bd init") == true)
        #expect(workspace.checks.first(where: { $0.id == ".beads" })?.state == .missing)
        #expect(workspace.checks.first(where: { $0.id == "bd-list" })?.state == .missing)
        #expect(runner.invocations.map(\.key) == ["bd|--version"])
    }

    @Test("Marks bd missing without crashing")
    func marksBdMissingWithoutCrashing() async throws {
        let folder = try makeTemporaryDirectory(named: "missing-bd")
        defer { try? FileManager.default.removeItem(at: folder) }

        FileManager.default.createFile(atPath: folder.appendingPathComponent(".git").path, contents: Data(), attributes: nil)
        FileManager.default.createFile(atPath: folder.appendingPathComponent(".beads").path, contents: Data(), attributes: nil)

        let runner = MockCommandRunner(responses: [
            "bd|--version": .failure(command: "bd", arguments: ["--version"], cwd: folder, stdout: "", stderr: "bd: not found", exitCode: 127)
        ])

        let workspace = try await WorkspaceValidator(commandRunner: runner).validate(selection: folder)

        #expect(workspace.validationState == .missing)
        #expect(workspace.checks.first(where: { $0.id == "bd-cli" })?.state == .missing)
        #expect(workspace.checks.first(where: { $0.id == "bd-list" })?.state == .missing)
    }

    @Test("Marks bd list failure when probe fails")
    func marksBdListFailureWhenProbeFails() async throws {
        let folder = try makeTemporaryDirectory(named: "probe-failure")
        defer { try? FileManager.default.removeItem(at: folder) }

        FileManager.default.createFile(atPath: folder.appendingPathComponent(".git").path, contents: Data(), attributes: nil)
        FileManager.default.createFile(atPath: folder.appendingPathComponent(".beads").path, contents: Data(), attributes: nil)

        let runner = MockCommandRunner(responses: [
            "bd|--version": .success(command: "bd", arguments: ["--version"], cwd: folder, stdout: "bd 1.0.0", stderr: "", exitCode: 0),
            "bd|list|--json": .failure(command: "bd", arguments: ["list", "--json"], cwd: folder, stdout: "", stderr: "bad json", exitCode: 1)
        ])

        let workspace = try await WorkspaceValidator(commandRunner: runner).validate(selection: folder)

        #expect(workspace.validationState == .failed)
        #expect(workspace.checks.first(where: { $0.id == "bd-list" })?.state == .failed)
    }

    @Test("Unreachable folder maps to invalidProjectFolder")
    func unreachableFolderMapsToInvalidProjectFolder() async throws {
        let folder = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString)", isDirectory: true)
        let runner = MockCommandRunner(responses: [:])

        do {
            _ = try await WorkspaceValidator(commandRunner: runner).validate(selection: folder)
            Issue.record("Expected invalidProjectFolder error")
        } catch let error as BeadsError {
            switch error {
            case .invalidProjectFolder:
                break
            default:
                Issue.record("Unexpected BeadsError case: \(error)")
            }
        }
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return URL(fileURLWithPath: url.path, isDirectory: true)
    }
}

private final class MockCommandRunner: CommandRunning, @unchecked Sendable {
    struct Invocation: Hashable {
        let key: String
        let workingDirectory: String
    }

    enum Response {
        case success(command: String, arguments: [String], cwd: URL, stdout: String, stderr: String, exitCode: Int32)
        case failure(command: String, arguments: [String], cwd: URL, stdout: String, stderr: String, exitCode: Int32)

        var result: CommandResult {
            switch self {
            case let .success(command, arguments, cwd, stdout, stderr, exitCode),
                 let .failure(command, arguments, cwd, stdout, stderr, exitCode):
                return CommandResult(
                    command: command,
                    arguments: arguments,
                    workingDirectory: cwd,
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: exitCode,
                    durationMs: 1
                )
            }
        }
    }

    let responses: [String: Response]
    private(set) var invocations: [Invocation] = []

    init(responses: [String: Response]) {
        self.responses = responses
    }

    func run(command: String, arguments: [String], workingDirectory: URL) async throws -> CommandResult {
        let key = ([command] + arguments).joined(separator: "|")
        invocations.append(Invocation(key: key, workingDirectory: workingDirectory.path))
        guard let response = responses[key] else {
            return CommandResult(command: command, arguments: arguments, workingDirectory: workingDirectory, stdout: "", stderr: "", exitCode: 0, durationMs: 1)
        }
        return response.result
    }
}
