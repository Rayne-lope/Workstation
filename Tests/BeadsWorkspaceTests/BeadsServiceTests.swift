import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@Suite("BeadsService typed API")
struct BeadsServiceTests {
    private let workingDirectory = URL(fileURLWithPath: "/tmp/beads-service-tests", isDirectory: true)

    // MARK: - Read

    @Test("listIssues decodes a top-level array")
    func listIssuesDecodesArray() async throws {
        let stdout = """
        [
          {"id": "bd-1", "title": "First"},
          {"id": "bd-2", "title": "Second"}
        ]
        """
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issues = try await service.listIssues(in: workingDirectory)

        #expect(issues.count == 2)
        #expect(issues[0].id == "bd-1")
        #expect(issues[1].title == "Second")
        #expect(runner.calls.count == 1)
        #expect(runner.calls[0].arguments == ["list", "--json"])
        #expect(runner.calls[0].command == "bd")
    }

    @Test("addLabel calls bd update --add-label and parses the response")
    func addLabelCallsUpdateAddLabel() async throws {
        let stdout = #"[{"id":"bd-7","title":"Needs review","status":"in_progress","labels":["human"]}]"#
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["update", "bd-7", "--add-label", "human", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issue = try await service.addLabel(id: "bd-7", label: "human", in: workingDirectory)

        #expect(issue.labels?.contains("human") == true)
        #expect(runner.calls[0].arguments == ["update", "bd-7", "--add-label", "human", "--json"])
    }

    @Test("addLabel rejects blank label")
    func addLabelRejectsBlankLabel() async throws {
        let runner = StubCommandRunner()
        let service = BeadsService(commandRunner: runner)

        await #expect(throws: BeadsError.self) {
            _ = try await service.addLabel(id: "bd-1", label: "   ", in: workingDirectory)
        }
        #expect(runner.calls.isEmpty)
    }

    @Test("blockedIssues calls bd blocked --json and parses blocked_by array")
    func blockedIssuesPassesArgsAndParsesBlockedBy() async throws {
        let stdout = """
        [
          {"id":"bd-down","title":"Downstream","status":"open","blocked_by":["bd-up"],"blocked_by_count":1}
        ]
        """
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["blocked", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issues = try await service.blockedIssues(in: workingDirectory)

        #expect(issues.count == 1)
        #expect(issues[0].id == "bd-down")
        #expect(issues[0].blockedBy == ["bd-up"])
        #expect(runner.calls[0].arguments == ["blocked", "--json"])
    }

    @Test("blockedIssues returns an empty array when bd blocked yields no items")
    func blockedIssuesHandlesEmpty() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["blocked", "--json"], stdout: "[]")
        let service = BeadsService(commandRunner: runner)

        let issues = try await service.blockedIssues(in: workingDirectory)

        #expect(issues.isEmpty)
    }

    @Test("addDependency calls bd dep add with positional args and no --json")
    func addDependencyPassesCorrectArgs() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["dep", "add", "bd-1", "bd-2"], stdout: "")
        let service = BeadsService(commandRunner: runner)

        try await service.addDependency(id: "bd-1", dependsOn: "bd-2", in: workingDirectory)

        #expect(runner.calls.count == 1)
        #expect(runner.calls[0].arguments == ["dep", "add", "bd-1", "bd-2"])
    }

    @Test("removeDependency calls bd dep remove with positional args")
    func removeDependencyPassesCorrectArgs() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["dep", "remove", "bd-1", "bd-2"], stdout: "")
        let service = BeadsService(commandRunner: runner)

        try await service.removeDependency(id: "bd-1", dependsOn: "bd-2", in: workingDirectory)

        #expect(runner.calls.count == 1)
        #expect(runner.calls[0].arguments == ["dep", "remove", "bd-1", "bd-2"])
    }

    @Test("addDependency rejects self-dependency before invoking bd")
    func addDependencyRejectsSelfDependency() async throws {
        let runner = StubCommandRunner()
        let service = BeadsService(commandRunner: runner)

        await #expect(throws: BeadsAppError.self) {
            try await service.addDependency(id: "bd-1", dependsOn: "bd-1", in: workingDirectory)
        }
        #expect(runner.calls.isEmpty)
    }

    @Test("addDependency rejects empty IDs without invoking bd")
    func addDependencyValidatesEmptyIDs() async throws {
        let runner = StubCommandRunner()
        let service = BeadsService(commandRunner: runner)

        await #expect(throws: BeadsAppError.self) {
            try await service.addDependency(id: "  ", dependsOn: "bd-2", in: workingDirectory)
        }
        await #expect(throws: BeadsAppError.self) {
            try await service.addDependency(id: "bd-1", dependsOn: "", in: workingDirectory)
        }
        #expect(runner.calls.isEmpty)
    }

    @Test("addDependency surfaces CLI error (e.g. cycle detected)")
    func addDependencyPropagatesCLIError() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: ["dep", "add", "bd-1", "bd-2"],
            stderr: "cycle detected: bd-1 -> bd-2 -> bd-1",
            exitCode: 1
        )
        let service = BeadsService(commandRunner: runner)

        await #expect(throws: BeadsAppError.self) {
            try await service.addDependency(id: "bd-1", dependsOn: "bd-2", in: workingDirectory)
        }
    }

    @Test("closedIssues calls bd list with --status=closed")
    func closedIssuesPassesStatusFilter() async throws {
        let stdout = #"[{"id":"bd-9","title":"Done","status":"closed","closed_at":"2026-05-19T08:00:00Z"}]"#
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--status=closed", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issues = try await service.closedIssues(in: workingDirectory)

        #expect(issues.count == 1)
        #expect(issues[0].id == "bd-9")
        #expect(issues[0].closedAt == "2026-05-19T08:00:00Z")
        #expect(runner.calls[0].arguments == ["list", "--status=closed", "--json"])
    }

    @Test("readyIssues passes --json to bd ready")
    func readyIssuesPassesJsonFlag() async throws {
        let stdout = #"[{"id":"bd-2","title":"Ready"}]"#
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["ready", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issues = try await service.readyIssues(in: workingDirectory)

        #expect(issues.count == 1)
        #expect(issues[0].id == "bd-2")
        #expect(runner.calls[0].arguments == ["ready", "--json"])
    }

    @Test("showIssue decodes the array-of-one shape returned by real bd")
    func showIssueHandlesArrayOfOne() async throws {
        let stdout = """
        [
          {"id": "bd-2", "title": "Draft", "status": "in_progress"}
        ]
        """
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["show", "bd-2", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issue = try await service.showIssue(id: "bd-2", in: workingDirectory)

        #expect(issue.id == "bd-2")
        #expect(issue.status == "in_progress")
    }

    // MARK: - Mutations

    @Test("createIssue serializes flags and parses single-object response")
    func createIssueSerializesFlags() async throws {
        let stdout = """
        {"id": "bd-9", "title": "New", "issue_type": "feature", "priority": 1}
        """
        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: [
                "create", "New",
                "-t", "feature",
                "-p", "1",
                "-d", "Some description",
                "--acceptance", "Done when X",
                "--json"
            ],
            stdout: stdout
        )
        let service = BeadsService(commandRunner: runner)

        let input = CreateIssueInput(
            title: "New",
            description: "Some description",
            issueType: "feature",
            priority: 1,
            acceptanceCriteria: "Done when X"
        )
        let issue = try await service.createIssue(input, in: workingDirectory)

        #expect(issue.id == "bd-9")
        #expect(issue.issueType == "feature")
        #expect(issue.priority == 1)
    }

    @Test("createIssue with only required title still works")
    func createIssueMinimalArguments() async throws {
        let stdout = #"{"id":"bd-10","title":"Bare"}"#
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["create", "Bare", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issue = try await service.createIssue(CreateIssueInput(title: "Bare"), in: workingDirectory)

        #expect(issue.id == "bd-10")
        #expect(runner.calls[0].arguments == ["create", "Bare", "--json"])
    }

    @Test("createIssue rejects blank titles")
    func createIssueRejectsBlankTitle() async throws {
        let runner = StubCommandRunner()
        let service = BeadsService(commandRunner: runner)

        await #expect(throws: BeadsError.self) {
            _ = try await service.createIssue(CreateIssueInput(title: "   "), in: workingDirectory)
        }
        #expect(runner.calls.isEmpty)
    }

    @Test("claimIssue invokes update --claim and parses the issue")
    func claimIssueInvokesUpdateClaim() async throws {
        let stdout = """
        [{"id":"bd-3","title":"Implement","status":"in_progress","assignee":"me"}]
        """
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["update", "bd-3", "--claim", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issue = try await service.claimIssue(id: "bd-3", in: workingDirectory)

        #expect(issue.status == "in_progress")
        #expect(issue.assignee == "me")
    }

    @Test("claimIssue can include an assignee token")
    func claimIssueInvokesUpdateClaimWithAssignee() async throws {
        let stdout = """
        [{"id":"bd-3","title":"Implement","status":"in_progress","assignee":"claude"}]
        """
        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: ["update", "bd-3", "--claim", "--assignee", "claude", "--json"],
            stdout: stdout
        )
        let service = BeadsService(commandRunner: runner)

        let issue = try await service.claimIssue(id: "bd-3", assignee: "claude", in: workingDirectory)

        #expect(issue.status == "in_progress")
        #expect(issue.assignee == "claude")
        #expect(runner.calls[0].arguments == ["update", "bd-3", "--claim", "--assignee", "claude", "--json"])
    }

    @Test("updateIssue passes only non-nil flags")
    func updateIssuePassesOnlyProvidedFlags() async throws {
        let stdout = #"[{"id":"bd-4","title":"Renamed","priority":0,"assignee":"codex"}]"#
        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: ["update", "bd-4", "--title", "Renamed", "-p", "0", "--assignee", "codex", "--json"],
            stdout: stdout
        )
        let service = BeadsService(commandRunner: runner)

        let input = UpdateIssueInput(title: "Renamed", priority: 0, assignee: "codex")
        let issue = try await service.updateIssue(id: "bd-4", input: input, in: workingDirectory)

        #expect(issue.title == "Renamed")
        #expect(issue.priority == 0)
        #expect(issue.assignee == "codex")
    }

    @Test("updateIssue passes assignee flag by itself")
    func updateIssuePassesAssigneeOnly() async throws {
        let stdout = #"[{"id":"bd-4","title":"Task","assignee":"me"}]"#
        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: ["update", "bd-4", "--assignee", "me", "--json"],
            stdout: stdout
        )
        let service = BeadsService(commandRunner: runner)

        let issue = try await service.updateIssue(id: "bd-4", input: UpdateIssueInput(assignee: "me"), in: workingDirectory)

        #expect(issue.assignee == "me")
        #expect(runner.calls[0].arguments == ["update", "bd-4", "--assignee", "me", "--json"])
    }

    @Test("updateIssue rejects empty input")
    func updateIssueRejectsEmptyInput() async throws {
        let runner = StubCommandRunner()
        let service = BeadsService(commandRunner: runner)

        await #expect(throws: BeadsError.self) {
            _ = try await service.updateIssue(id: "bd-4", input: UpdateIssueInput(), in: workingDirectory)
        }
        #expect(runner.calls.isEmpty)
    }

    @Test("closeIssue passes reason and parses response")
    func closeIssuePassesReason() async throws {
        let stdout = #"[{"id":"bd-5","title":"Done","status":"closed"}]"#
        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: ["close", "bd-5", "--reason", "shipped", "--json"],
            stdout: stdout
        )
        let service = BeadsService(commandRunner: runner)

        let issue = try await service.closeIssue(id: "bd-5", reason: "shipped", in: workingDirectory)

        #expect(issue.status == "closed")
    }

    @Test("closeIssue rejects blank reason")
    func closeIssueRejectsBlankReason() async throws {
        let runner = StubCommandRunner()
        let service = BeadsService(commandRunner: runner)

        await #expect(throws: BeadsError.self) {
            _ = try await service.closeIssue(id: "bd-5", reason: "  ", in: workingDirectory)
        }
        #expect(runner.calls.isEmpty)
    }

    @Test("reopenIssue invokes bd reopen --json")
    func reopenIssueInvokesReopen() async throws {
        let stdout = #"[{"id":"bd-5","title":"Back","status":"open"}]"#
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["reopen", "bd-5", "--json"], stdout: stdout)
        let service = BeadsService(commandRunner: runner)

        let issue = try await service.reopenIssue(id: "bd-5", in: workingDirectory)

        #expect(issue.status == "open")
    }

    @Test("Mutations by id reject empty/blank id without invoking the runner")
    func mutationsRejectBlankID() async throws {
        let runner = StubCommandRunner()
        let service = BeadsService(commandRunner: runner)

        await #expect(throws: BeadsError.self) {
            _ = try await service.showIssue(id: "", in: workingDirectory)
        }
        await #expect(throws: BeadsError.self) {
            _ = try await service.claimIssue(id: "  ", in: workingDirectory)
        }
        await #expect(throws: BeadsError.self) {
            _ = try await service.updateIssue(id: "", input: UpdateIssueInput(title: "x"), in: workingDirectory)
        }
        await #expect(throws: BeadsError.self) {
            _ = try await service.closeIssue(id: "  ", reason: "done", in: workingDirectory)
        }
        await #expect(throws: BeadsError.self) {
            _ = try await service.reopenIssue(id: "", in: workingDirectory)
        }

        #expect(runner.calls.isEmpty)
    }

    // MARK: - Error taxonomy

    @Test("Non-zero exit code is surfaced as BeadsError.commandFailed")
    func nonZeroExitMapsToCommandFailed() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(
            arguments: ["list", "--json"],
            stderr: "unexpected failure",
            exitCode: 2
        )
        let service = BeadsService(commandRunner: runner)

        do {
            _ = try await service.listIssues(in: workingDirectory)
            Issue.record("Expected BeadsError.commandFailed")
        } catch let error as BeadsError {
            switch error {
            case let .commandFailed(command, stderr, exitCode):
                #expect(command == "bd list --json")
                #expect(stderr == "unexpected failure")
                #expect(exitCode == 2)
            default:
                Issue.record("Unexpected BeadsError case: \(error)")
            }
        }
    }

    @Test("bd missing is surfaced as BeadsError.bdNotInstalled")
    func missingBdMapsToBdNotInstalled() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], stderr: "bd: command not found", exitCode: 127)
        let service = BeadsService(commandRunner: runner)

        do {
            _ = try await service.listIssues(in: workingDirectory)
            Issue.record("Expected BeadsError.bdNotInstalled")
        } catch let error as BeadsError {
            switch error {
            case .bdNotInstalled:
                break
            default:
                Issue.record("Unexpected BeadsError case: \(error)")
            }
        }
    }

    @Test("Uninitialized workspace is surfaced as BeadsError.beadsNotInitialized")
    func uninitializedWorkspaceMapsToBeadsNotInitialized() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], stderr: "no beads workspace found", exitCode: 1)
        let service = BeadsService(commandRunner: runner)

        do {
            _ = try await service.listIssues(in: workingDirectory)
            Issue.record("Expected BeadsError.beadsNotInitialized")
        } catch let error as BeadsError {
            switch error {
            case .beadsNotInitialized:
                break
            default:
                Issue.record("Unexpected BeadsError case: \(error)")
            }
        }
    }

    @Test("Timeouts are surfaced as BeadsError.timeout")
    func timeoutMapsToTimeout() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], error: ShellCommandRunnerError.timedOut(command: "bd", timeout: 0.1))
        let service = BeadsService(commandRunner: runner)

        do {
            _ = try await service.listIssues(in: workingDirectory)
            Issue.record("Expected BeadsError.timeout")
        } catch let error as BeadsError {
            switch error {
            case let .timeout(command):
                #expect(command == "bd list --json")
            default:
                Issue.record("Unexpected BeadsError case: \(error)")
            }
        }
    }

    @Test("Permission denied exits are surfaced as BeadsError.permissionDenied")
    func permissionDeniedMapsToPermissionDenied() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], stderr: "permission denied", exitCode: 126)
        let service = BeadsService(commandRunner: runner)

        do {
            _ = try await service.listIssues(in: workingDirectory)
            Issue.record("Expected BeadsError.permissionDenied")
        } catch let error as BeadsError {
            switch error {
            case let .permissionDenied(path):
                #expect(path == workingDirectory.path)
            default:
                Issue.record("Unexpected BeadsError case: \(error)")
            }
        }
    }

    @Test("Invalid JSON is surfaced as BeadsError.jsonDecodeFailed")
    func invalidJsonMapsToDecodeFailed() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["ready", "--json"], stdout: "not json at all")
        let service = BeadsService(commandRunner: runner)

        do {
            _ = try await service.readyIssues(in: workingDirectory)
            Issue.record("Expected BeadsError.jsonDecodeFailed")
        } catch let error as BeadsError {
            switch error {
            case let .jsonDecodeFailed(raw):
                #expect(raw == "not json at all")
            default:
                Issue.record("Unexpected BeadsError case: \(error)")
            }
        }
    }

    @Test("Runner thrown generic errors fall back to commandFailed")
    func runnerErrorFallsBackToCommandFailed() async throws {
        struct Boom: Error, LocalizedError { var errorDescription: String? { "boom" } }
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], error: Boom())
        let service = BeadsService(commandRunner: runner)

        do {
            _ = try await service.listIssues(in: workingDirectory)
            Issue.record("Expected BeadsError.commandFailed")
        } catch let error as BeadsError {
            switch error {
            case let .commandFailed(command, stderr, exitCode):
                #expect(command == "bd list --json")
                #expect(stderr == "boom")
                #expect(exitCode == -1)
            default:
                Issue.record("Unexpected BeadsError case: \(error)")
            }
        }
    }
}
