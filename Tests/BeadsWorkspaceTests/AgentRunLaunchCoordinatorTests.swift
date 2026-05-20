import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("AgentRunLaunchCoordinator")
struct AgentRunLaunchCoordinatorTests {
    private final class MutableClock: @unchecked Sendable {
        var now: Date = Date(timeIntervalSince1970: 0)
    }

    private func makeCoordinator(
        clock: MutableClock = MutableClock(),
        launcher: StubTerminalLauncher = StubTerminalLauncher()
    ) -> (AgentRunLaunchCoordinator, AgentRunHistoryStore, StubTerminalLauncher, URL) {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-run-launch-coordinator-tests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = baseURL.appendingPathComponent("agent-run-history.json")
        let store = AgentRunHistoryStore(fileURL: fileURL, clock: { clock.now })
        let coordinator = AgentRunLaunchCoordinator(
            historyStore: store,
            promptGenerator: PromptGenerator(),
            terminalLauncher: launcher
        )
        return (coordinator, store, launcher, fileURL)
    }

    private func sampleIssue() -> BeadIssue {
        BeadIssue(
            id: "bd-123",
            title: "Implement history",
            status: "open",
            priority: 2,
            issueType: "feature",
            description: "Add agent run history."
        )
    }

    private func sampleProfile() -> AgentProfile {
        AgentProfile.builtInProfiles.first { $0.id == AgentProfile.codingExecutorID }!
    }

    @Test("prepareLaunch records a prepared run and exposes prompt and command")
    func prepareLaunchRecordsPreparedRun() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (coordinator, store, _, _) = makeCoordinator(clock: clock)

        let session = coordinator.prepareLaunch(
            for: sampleIssue(),
            profile: sampleProfile(),
            projectPath: "/tmp/project"
        )

        #expect(session.payload.prompt.contains("Implement history"))
        #expect(session.payload.command.contains("claude"))
        #expect(store.records.count == 1)
        #expect(store.records.first?.status == .prepared)
        #expect(store.records.first?.projectPath == "/tmp/project")
    }

    @Test("openTerminal success advances the run to terminalOpened")
    func openTerminalSuccessMarksTerminalOpened() throws {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (coordinator, store, launcher, _) = makeCoordinator(clock: clock)

        let session = coordinator.prepareLaunch(
            for: sampleIssue(),
            profile: sampleProfile(),
            projectPath: "/tmp/project"
        )
        try coordinator.openTerminal(
            for: session,
            projectURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true),
            terminalCommand: session.payload.command
        )

        #expect(launcher.calls.count == 1)
        #expect(launcher.calls.first?.projectURL.path == "/tmp/project")
        #expect(launcher.calls.first?.command == session.payload.command)
        #expect(store.records.first?.status == .terminalOpened)
        #expect(store.records.first?.completedAt == nil)
    }

    @Test("openTerminal failure marks the run failed and stores notes")
    func openTerminalFailureMarksFailed() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let launcher = StubTerminalLauncher()
        launcher.enqueueFailure(StubTerminalLauncher.StubError.launchFailed("osascript failed"))
        let (coordinator, store, _, _) = makeCoordinator(clock: clock, launcher: launcher)

        let session = coordinator.prepareLaunch(
            for: sampleIssue(),
            profile: sampleProfile(),
            projectPath: "/tmp/project"
        )

        #expect(throws: StubTerminalLauncher.StubError.self) {
            try coordinator.openTerminal(
                for: session,
                projectURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true),
                terminalCommand: sampleProfile().command
            )
        }

        #expect(store.records.first?.status == .failed)
        #expect(store.records.first?.notes == "osascript failed")
        #expect(store.records.first?.completedAt != nil)
    }
}
