import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("AgentRunHistoryStore")
struct AgentRunHistoryStoreTests {
    private final class MutableClock: @unchecked Sendable {
        var now: Date = Date(timeIntervalSince1970: 0)
    }

    private func makeStore(
        clock: MutableClock = MutableClock()
    ) -> (AgentRunHistoryStore, URL, MutableClock) {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-run-history-tests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = baseURL.appendingPathComponent("agent-run-history.json")
        let store = AgentRunHistoryStore(
            fileURL: fileURL,
            clock: { clock.now }
        )
        return (store, fileURL, clock)
    }

    @Test("recordLaunchAttempt persists and reloads")
    func recordLaunchAttemptPersists() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (store, fileURL, _) = makeStore(clock: clock)

        let record = store.recordLaunchAttempt(
            issueID: "bd-1",
            issueTitle: "Launch history",
            agentProfileID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
            agentName: "Claude Code Executor",
            command: "claude \"prompt\"",
            prompt: "prompt",
            projectPath: "/tmp/workspace",
            status: .prepared
        )

        #expect(store.records.count == 1)
        #expect(store.records.first?.id == record.id)
        #expect(store.records.first?.status == .prepared)
        #expect(store.records.first?.completedAt == nil)

        let reloaded = AgentRunHistoryStore(
            fileURL: fileURL,
            clock: { clock.now }
        )

        #expect(reloaded.records.count == 1)
        #expect(reloaded.records.first?.issueID == "bd-1")
        #expect(reloaded.records.first?.command == "claude \"prompt\"")
        #expect(reloaded.records.first?.projectPath == "/tmp/workspace")
        #expect(reloaded.records.first?.worktree == nil)
    }

    @Test("recordLaunchAttempt persists worktree metadata and reloads")
    func recordLaunchAttemptPersistsWorktreeMetadata() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 120)
        let (store, fileURL, _) = makeStore(clock: clock)
        let sourceRunID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let worktree = AgentRunWorktreeMetadata(
            path: "/tmp/project-worktree",
            branchName: "agent/bd-2",
            sourceRunID: sourceRunID
        )

        _ = store.recordLaunchAttempt(
            issueID: "bd-2",
            issueTitle: "Worktree metadata",
            agentProfileID: nil,
            agentName: "Codex",
            command: "codex",
            prompt: "prompt",
            projectPath: "/tmp/project-worktree",
            worktree: worktree
        )

        #expect(store.records.first?.worktree == worktree)

        let reloaded = AgentRunHistoryStore(
            fileURL: fileURL,
            clock: { clock.now }
        )

        #expect(reloaded.records.first?.worktree == worktree)
        #expect(reloaded.records.first?.launchProjectPath == "/tmp/project-worktree")
    }

    @Test("records sort newest first")
    func sortsNewestFirst() {
        let clock = MutableClock()
        let (store, _, _) = makeStore(clock: clock)

        clock.now = Date(timeIntervalSince1970: 100)
        _ = store.recordLaunchAttempt(
            issueID: "bd-1",
            issueTitle: "First",
            agentProfileID: nil,
            agentName: "Claude",
            command: "claude",
            prompt: "first",
            projectPath: "/tmp/a"
        )

        clock.now = Date(timeIntervalSince1970: 300)
        _ = store.recordLaunchAttempt(
            issueID: "bd-2",
            issueTitle: "Second",
            agentProfileID: nil,
            agentName: "Codex",
            command: "codex exec",
            prompt: "second",
            projectPath: "/tmp/b"
        )

        clock.now = Date(timeIntervalSince1970: 200)
        _ = store.recordLaunchAttempt(
            issueID: "bd-3",
            issueTitle: "Third",
            agentProfileID: nil,
            agentName: "Claude",
            command: "claude",
            prompt: "third",
            projectPath: "/tmp/c"
        )

        #expect(store.records.map(\.issueID) == ["bd-2", "bd-3", "bd-1"])
    }

    @Test("updateNotes persists notes without touching status or completion")
    func updateNotesPersistsNotes() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (store, fileURL, _) = makeStore(clock: clock)

        let record = store.recordLaunchAttempt(
            issueID: "bd-notes",
            issueTitle: "Notes flow",
            agentProfileID: nil,
            agentName: "Claude",
            command: "claude",
            prompt: "prompt",
            projectPath: "/tmp/notes"
        )

        clock.now = Date(timeIntervalSince1970: 400)
        store.updateNotes(id: record.id, notes: "Followed up manually")

        #expect(store.records.first?.notes == "Followed up manually")
        #expect(store.records.first?.status == .prepared)
        #expect(store.records.first?.completedAt == nil)

        store.updateNotes(id: record.id, notes: "   ")
        #expect(store.records.first?.notes == nil)

        let reloaded = AgentRunHistoryStore(
            fileURL: fileURL,
            clock: { clock.now }
        )
        #expect(reloaded.records.first?.notes == nil)
        #expect(reloaded.records.first?.status == .prepared)
    }

    @Test("record(id:) and latestRecord(forIssueID:) lookups")
    func recordLookups() {
        let clock = MutableClock()
        let (store, _, _) = makeStore(clock: clock)

        clock.now = Date(timeIntervalSince1970: 100)
        let first = store.recordLaunchAttempt(
            issueID: "bd-X",
            issueTitle: "First",
            agentProfileID: nil,
            agentName: "Claude",
            command: "claude",
            prompt: "p1",
            projectPath: "/tmp/x"
        )

        clock.now = Date(timeIntervalSince1970: 300)
        let second = store.recordLaunchAttempt(
            issueID: "bd-X",
            issueTitle: "First",
            agentProfileID: nil,
            agentName: "Codex",
            command: "codex",
            prompt: "p2",
            projectPath: "/tmp/x"
        )

        #expect(store.record(id: first.id)?.prompt == "p1")
        #expect(store.record(id: UUID()) == nil)
        #expect(store.latestRecord(forIssueID: "bd-X")?.id == second.id)
        #expect(store.latestRecord(forIssueID: "bd-unknown") == nil)
    }

    @Test("updateStatus persists notes and completion timestamp")
    func updateStatusPersistsCompletion() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (store, fileURL, _) = makeStore(clock: clock)

        let record = store.recordLaunchAttempt(
            issueID: "bd-4",
            issueTitle: "Need review",
            agentProfileID: nil,
            agentName: "Claude",
            command: "claude",
            prompt: "prompt",
            projectPath: "/tmp/d"
        )

        clock.now = Date(timeIntervalSince1970: 250)
        store.updateStatus(id: record.id, status: .failed, notes: "osascript died")

        #expect(store.records.first?.status == .failed)
        #expect(store.records.first?.notes == "osascript died")
        #expect(store.records.first?.completedAt == Date(timeIntervalSince1970: 250))

        let reloaded = AgentRunHistoryStore(
            fileURL: fileURL,
            clock: { clock.now }
        )

        #expect(reloaded.records.first?.status == .failed)
        #expect(reloaded.records.first?.notes == "osascript died")
        #expect(reloaded.records.first?.completedAt == Date(timeIntervalSince1970: 250))
    }
}
