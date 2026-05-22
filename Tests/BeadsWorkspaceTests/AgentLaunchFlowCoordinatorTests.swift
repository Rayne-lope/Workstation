import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("AgentLaunchFlowCoordinator")
struct AgentLaunchFlowCoordinatorTests {
    private final class MutableClock: @unchecked Sendable {
        var now: Date = Date(timeIntervalSince1970: 0)
    }

    private func makeCoordinator(
        clock: MutableClock = MutableClock(),
        runner: StubCommandRunner = StubCommandRunner(),
        launcher: StubTerminalLauncher = StubTerminalLauncher()
    ) -> (AgentLaunchFlowCoordinator, AgentRunHistoryStore, StubCommandRunner, StubTerminalLauncher, URL) {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-launch-flow-coordinator-tests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = baseURL.appendingPathComponent("agent-run-history.json")
        let store = AgentRunHistoryStore(fileURL: fileURL, clock: { clock.now })
        let coordinator = AgentLaunchFlowCoordinator(
            historyStore: store,
            promptGenerator: PromptGenerator(),
            terminalLauncher: launcher,
            commandRunner: runner
        )
        return (coordinator, store, runner, launcher, fileURL)
    }

    private func sampleIssue() -> BeadIssue {
        BeadIssue(
            id: "bd-123",
            title: "Warn before agent launch",
            status: "open",
            priority: 2,
            issueType: "feature",
            description: "Add a git dirty check."
        )
    }

    private func sampleReviewIssue() -> BeadIssue {
        BeadIssue(
            id: "bd-123",
            title: "Warn before agent launch",
            status: "in_progress",
            priority: 2,
            issueType: "feature",
            description: "Add a git dirty check.",
            labels: [KanbanStateMapper.humanReviewLabel]
        )
    }

    private func sampleProfile() -> AgentProfile {
        AgentProfile.builtInProfiles.first { $0.id == AgentProfile.codingExecutorID }!
    }

    private func nonClaimingProfile() -> AgentProfile {
        AgentProfile(
            name: "Local Executor",
            role: .codingExecutor,
            command: "claude",
            commandArgsTemplate: "\"{{prompt}}\"",
            avatarKind: .other,
            canExecuteCode: true,
            shouldClaimIssue: false,
            shouldCloseIssue: false,
            shouldRequestHumanReview: false,
            isBuiltIn: false
        )
    }

    @Test("preflight on a clean tree returns metadata and does not touch history")
    func preflightCleanTreeReturnsMetadata() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("git clean tree \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let (coordinator, store, runner, _, _) = makeCoordinator()
        runner.enqueue(arguments: ["status", "--porcelain"], stdout: "")
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "main\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "abc123 Clean tree\n")

        let summary = try await coordinator.statusSummary(in: folder)

        #expect(summary.isDirty == false)
        #expect(summary.branchName == "main")
        #expect(summary.lastCommitSummary == "abc123 Clean tree")
        #expect(store.records.isEmpty)
    }

    @Test("dirty preflight reports changed files and does not record a run until continue")
    func dirtyPreflightLeavesHistoryEmpty() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("git dirty tree \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let (coordinator, store, runner, launcher, _) = makeCoordinator()
        runner.enqueue(
            arguments: ["status", "--porcelain"],
            stdout: """
            M  App/AppViewModel.swift
            ?? Tests/BeadsWorkspaceTests/New Flow.swift
            """
        )
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "feature/dirty-check\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "feedbeef Dirty tree\n")

        let summary = try await coordinator.statusSummary(in: folder)

        #expect(summary.isDirty == true)
        #expect(summary.changedFiles.count == 2)
        #expect(store.records.isEmpty)
        #expect(launcher.calls.isEmpty)
    }

    @Test("continuing after a dirty preflight records the run and opens Terminal")
    func continueLaunchRecordsHistory() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("git dirty continue \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (coordinator, store, runner, launcher, _) = makeCoordinator(clock: clock)
        runner.enqueue(
            arguments: ["status", "--porcelain"],
            stdout: """
            M  App/BoardView.swift
            """
        )
        runner.enqueue(arguments: ["branch", "--show-current"], stdout: "feature/dirty-check\n")
        runner.enqueue(arguments: ["log", "-1", "--pretty=format:%h%x20%s"], stdout: "feedbeef Dirty tree\n")

        let summary = try await coordinator.statusSummary(in: folder)
        #expect(summary.isDirty == true)

        let session = coordinator.prepareLaunch(
            for: sampleIssue(),
            profile: sampleProfile(),
            projectPath: folder.path
        )
        try coordinator.openTerminal(
            for: session,
            projectURL: folder,
            terminalCommand: session.payload.command
        )

        #expect(store.records.count == 1)
        #expect(store.records.first?.status == .terminalOpened)
        #expect(store.records.first?.issueID == sampleIssue().id)
        #expect(launcher.calls.count == 1)
        #expect(launcher.calls.first?.projectURL == folder)
    }

    @Test("preflight failure blocks launch before history or Terminal are touched")
    func preflightFailureBlocksLaunch() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("git preflight failure \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let (coordinator, store, runner, launcher, _) = makeCoordinator()
        runner.enqueue(
            arguments: ["status", "--porcelain"],
            stderr: "fatal: not a git repository",
            exitCode: 1
        )

        await #expect(throws: GitStatusServiceError.self) {
            _ = try await coordinator.statusSummary(in: folder)
        }

        #expect(store.records.isEmpty)
        #expect(launcher.calls.isEmpty)
    }

    @Test("claimable profiles claim with assignee before a launch session is prepared")
    func claimableProfileClaimsBeforeLaunch() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-claimable \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 200)
        let runner = StubCommandRunner()
        let launcher = StubTerminalLauncher()
        let (coordinator, historyStore, _, _, _) = makeCoordinator(clock: clock, runner: runner, launcher: launcher)
        let issueStore = IssueStore(
            service: BeadsService(commandRunner: runner),
            workingDirectory: folder,
            doneVisibilityWindow: 0,
            now: { clock.now }
        )
        runner.enqueue(
            arguments: ["update", "bd-123", "--claim", "--assignee", "claude", "--json"],
            stdout: #"[{"id":"bd-123","title":"Warn before agent launch","status":"in_progress","assignee":"claude"}]"#
        )
        runner.enqueue(arguments: ["list", "--json"], stdout: AgentLaunchFlowCoordinatorTests.sampleListFixture())
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        let session = await coordinator.prepareLaunchSession(
            for: sampleIssue(),
            profile: sampleProfile(),
            projectPath: folder.path,
            issueStore: issueStore
        )

        #expect(session != nil)
        #expect(runner.calls.first?.arguments == ["update", "bd-123", "--claim", "--assignee", "claude", "--json"])
        #expect(!runner.calls.contains { $0.arguments == ["update", "bd-123", "--remove-label", "human", "--json"] })
        #expect(historyStore.records.count == 1)
        #expect(historyStore.records.first?.status == .prepared)
        #expect(historyStore.records.first?.projectPath == folder.path)
        #expect(launcher.calls.isEmpty)
    }

    @Test("claimable review issue clears human label before launch session is prepared")
    func claimableReviewIssueClearsHumanLabelBeforeLaunch() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-review-takeover \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 225)
        let runner = StubCommandRunner()
        let launcher = StubTerminalLauncher()
        let (coordinator, historyStore, _, _, _) = makeCoordinator(clock: clock, runner: runner, launcher: launcher)
        let issueStore = IssueStore(
            service: BeadsService(commandRunner: runner),
            workingDirectory: folder,
            doneVisibilityWindow: 0,
            now: { clock.now }
        )
        runner.enqueue(
            arguments: ["update", "bd-123", "--claim", "--assignee", "claude", "--json"],
            stdout: #"[{"id":"bd-123","title":"Warn before agent launch","status":"in_progress","assignee":"claude","labels":["human"]}]"#
        )
        runner.enqueue(arguments: ["list", "--json"], stdout: AgentLaunchFlowCoordinatorTests.sampleListFixture(labels: ["human"]))
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")
        runner.enqueue(
            arguments: ["update", "bd-123", "--remove-label", "human", "--json"],
            stdout: #"[{"id":"bd-123","title":"Warn before agent launch","status":"in_progress","assignee":"claude","labels":[]}]"#
        )
        runner.enqueue(arguments: ["list", "--json"], stdout: AgentLaunchFlowCoordinatorTests.sampleListFixture(labels: []))
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        let session = await coordinator.prepareLaunchSession(
            for: sampleReviewIssue(),
            profile: sampleProfile(),
            projectPath: folder.path,
            issueStore: issueStore,
            clearHumanReviewLabel: true
        )

        #expect(session != nil)
        let claimIndex = runner.calls.firstIndex { $0.arguments == ["update", "bd-123", "--claim", "--assignee", "claude", "--json"] }
        let clearIndex = runner.calls.firstIndex { $0.arguments == ["update", "bd-123", "--remove-label", "human", "--json"] }
        #expect(claimIndex != nil)
        #expect(clearIndex != nil)
        if let claimIndex, let clearIndex {
            #expect(claimIndex < clearIndex)
        }
        #expect(historyStore.records.count == 1)
        #expect(historyStore.records.first?.status == .prepared)
        #expect(launcher.calls.isEmpty)
    }

    @Test("claim failure blocks label clearing and launch session for open issues")
    func claimFailureBlocksTakeover() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-claim-failure \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let runner = StubCommandRunner()
        let launcher = StubTerminalLauncher()
        let (coordinator, historyStore, _, _, _) = makeCoordinator(runner: runner, launcher: launcher)
        let issueStore = IssueStore(
            service: BeadsService(commandRunner: runner),
            workingDirectory: folder,
            doneVisibilityWindow: 0
        )
        runner.enqueue(
            arguments: ["update", "bd-123", "--claim", "--assignee", "claude", "--json"],
            stderr: "claim failed",
            exitCode: 1
        )

        // sampleIssue() is status=open, so claim failure should block launch.
        let session = await coordinator.prepareLaunchSession(
            for: sampleIssue(),
            profile: sampleProfile(),
            projectPath: folder.path,
            issueStore: issueStore,
            clearHumanReviewLabel: false
        )

        #expect(session == nil)
        #expect(historyStore.records.isEmpty)
        #expect(launcher.calls.isEmpty)
    }

    @Test("claim failure on in_progress issue falls back to assignee update and launches")
    func claimFailureFallsBackToAssigneeUpdate() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-reassign \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 275)
        let runner = StubCommandRunner()
        let launcher = StubTerminalLauncher()
        let (coordinator, historyStore, _, _, _) = makeCoordinator(clock: clock, runner: runner, launcher: launcher)
        let issueStore = IssueStore(
            service: BeadsService(commandRunner: runner),
            workingDirectory: folder,
            doneVisibilityWindow: 0,
            now: { clock.now }
        )

        // Claim fails because the issue is already in_progress
        runner.enqueue(
            arguments: ["update", "bd-123", "--claim", "--assignee", "claude", "--json"],
            stderr: "Error claiming bd-123: issue not claimable: status in_progress",
            exitCode: 1
        )
        // Fallback: plain assignee update succeeds
        runner.enqueue(
            arguments: ["update", "bd-123", "--assignee", "claude", "--json"],
            stdout: #"[{"id":"bd-123","title":"Warn before agent launch","status":"in_progress","assignee":"claude"}]"#
        )
        runner.enqueue(arguments: ["list", "--json"], stdout: AgentLaunchFlowCoordinatorTests.sampleListFixture())
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        // sampleReviewIssue() has status=in_progress
        let session = await coordinator.prepareLaunchSession(
            for: sampleReviewIssue(),
            profile: sampleProfile(),
            projectPath: folder.path,
            issueStore: issueStore
        )

        #expect(session != nil)
        #expect(runner.calls.contains { $0.arguments == ["update", "bd-123", "--assignee", "claude", "--json"] })
        #expect(historyStore.records.count == 1)
        #expect(historyStore.records.first?.status == .prepared)
    }

    @Test("human label clear failure blocks launch session")
    func clearHumanReviewFailureBlocksLaunch() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-clear-human-failure \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let runner = StubCommandRunner()
        let launcher = StubTerminalLauncher()
        let (coordinator, historyStore, _, _, _) = makeCoordinator(runner: runner, launcher: launcher)
        let issueStore = IssueStore(
            service: BeadsService(commandRunner: runner),
            workingDirectory: folder,
            doneVisibilityWindow: 0
        )
        runner.enqueue(
            arguments: ["update", "bd-123", "--claim", "--assignee", "claude", "--json"],
            stdout: #"[{"id":"bd-123","title":"Warn before agent launch","status":"in_progress","assignee":"claude","labels":["human"]}]"#
        )
        runner.enqueue(arguments: ["list", "--json"], stdout: AgentLaunchFlowCoordinatorTests.sampleListFixture(labels: ["human"]))
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")
        runner.enqueue(
            arguments: ["update", "bd-123", "--remove-label", "human", "--json"],
            stderr: "remove failed",
            exitCode: 1
        )

        let session = await coordinator.prepareLaunchSession(
            for: sampleReviewIssue(),
            profile: sampleProfile(),
            projectPath: folder.path,
            issueStore: issueStore,
            clearHumanReviewLabel: true
        )

        #expect(session == nil)
        #expect(runner.calls.contains { $0.arguments == ["update", "bd-123", "--remove-label", "human", "--json"] })
        #expect(historyStore.records.isEmpty)
        #expect(launcher.calls.isEmpty)
    }

    @Test("non-claimable profiles skip the claim step and still prepare a launch session")
    func nonClaimableProfileSkipsClaim() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-non-claiming \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 300)
        let (coordinator, historyStore, runner, launcher, _) = makeCoordinator(clock: clock)

        let session = await coordinator.prepareLaunchSession(
            for: sampleIssue(),
            profile: nonClaimingProfile(),
            projectPath: folder.path,
            issueStore: nil
        )

        #expect(session != nil)
        #expect(runner.calls.isEmpty)
        #expect(historyStore.records.count == 1)
        #expect(historyStore.records.first?.status == .prepared)

        try coordinator.openTerminal(
            for: session!,
            projectURL: folder,
            terminalCommand: session!.payload.command
        )

        #expect(launcher.calls.count == 1)
        #expect(historyStore.records.first?.status == .terminalOpened)
    }

    @Test("worktree launches persist worktree metadata and source linkage")
    func worktreeLaunchPersistsMetadata() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-worktree-metadata \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 350)
        let (coordinator, historyStore, _, _, _) = makeCoordinator(clock: clock)
        let sourceRunID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        let worktree = AgentRunWorktreeMetadata(
            path: folder.appendingPathComponent("project-worktree").path,
            branchName: "agent/bd-123",
            sourceRunID: sourceRunID
        )

        let session = await coordinator.prepareLaunchSession(
            for: sampleIssue(),
            profile: nonClaimingProfile(),
            projectPath: worktree.path,
            worktree: worktree,
            issueStore: nil
        )

        #expect(session != nil)
        #expect(historyStore.records.count == 1)
        #expect(historyStore.records.first?.worktree == worktree)
        #expect(historyStore.records.first?.launchProjectPath == worktree.path)
    }

    @Test("terminal launch failure still marks the run failed for an explicit profile")
    func explicitProfileTerminalFailureMarksFailed() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-terminal-failure \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 400)
        let launcher = StubTerminalLauncher()
        launcher.enqueueFailure(StubTerminalLauncher.StubError.launchFailed("osascript failed"))
        let (coordinator, historyStore, _, _, _) = makeCoordinator(clock: clock, launcher: launcher)

        let session = await coordinator.prepareLaunchSession(
            for: sampleIssue(),
            profile: nonClaimingProfile(),
            projectPath: folder.path,
            issueStore: nil
        )

        #expect(session != nil)

        #expect(throws: StubTerminalLauncher.StubError.self) {
            try coordinator.openTerminal(
                for: session!,
                projectURL: folder,
                terminalCommand: session!.payload.command
            )
        }

        #expect(historyStore.records.first?.status == .failed)
        #expect(historyStore.records.first?.notes == "osascript failed")
    }
}

private extension AgentLaunchFlowCoordinatorTests {
    static func sampleListFixture(labels: [String] = []) -> String {
        let labelsJSON = labels.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        [
          {"id":"bd-123","title":"Warn before agent launch","status":"in_progress","priority":2,"assignee":"claude","labels":[\(labelsJSON)]}
        ]
        """
    }
}
