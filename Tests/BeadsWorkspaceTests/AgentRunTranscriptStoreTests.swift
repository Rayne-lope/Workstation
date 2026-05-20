import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("AgentRunTranscriptStore")
struct AgentRunTranscriptStoreTests {
    private final class MutableClock: @unchecked Sendable {
        var now: Date = Date(timeIntervalSince1970: 0)
    }

    private func makeStore(
        clock: MutableClock = MutableClock()
    ) -> (AgentRunTranscriptStore, URL, MutableClock) {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-run-transcript-tests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = baseURL.appendingPathComponent("agent-run-transcripts.json")
        let store = AgentRunTranscriptStore(
            fileURL: fileURL,
            clock: { clock.now }
        )
        return (store, fileURL, clock)
    }

    @Test("append persists and reloads")
    func appendPersists() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (store, fileURL, _) = makeStore(clock: clock)
        let runID = UUID()

        let m1 = store.append(runID: runID, role: .user, content: "First instruction")
        clock.now = Date(timeIntervalSince1970: 200)
        let m2 = store.append(runID: runID, role: .agent, content: "Pasted agent reply")

        #expect(m1 != nil)
        #expect(m2 != nil)
        #expect(store.messages.count == 2)

        let reloaded = AgentRunTranscriptStore(fileURL: fileURL, clock: { clock.now })
        let entries = reloaded.messages(forRunID: runID)
        #expect(entries.count == 2)
        #expect(entries.map(\.role) == [.user, .agent])
        #expect(entries.map(\.content) == ["First instruction", "Pasted agent reply"])
    }

    @Test("append ignores blank content")
    func appendIgnoresBlank() {
        let (store, _, _) = makeStore()
        let runID = UUID()

        let result = store.append(runID: runID, role: .note, content: "   \n\t  ")
        #expect(result == nil)
        #expect(store.messages.isEmpty)
    }

    @Test("messages(forRunID:) filters and orders chronologically")
    func messagesForRunFilters() {
        let clock = MutableClock()
        let (store, _, _) = makeStore(clock: clock)
        let runA = UUID()
        let runB = UUID()

        clock.now = Date(timeIntervalSince1970: 100)
        _ = store.append(runID: runA, role: .user, content: "A1")
        clock.now = Date(timeIntervalSince1970: 50)
        _ = store.append(runID: runA, role: .agent, content: "A0")
        clock.now = Date(timeIntervalSince1970: 75)
        _ = store.append(runID: runB, role: .user, content: "B1")

        let aMessages = store.messages(forRunID: runA)
        #expect(aMessages.map(\.content) == ["A0", "A1"])
        let bMessages = store.messages(forRunID: runB)
        #expect(bMessages.map(\.content) == ["B1"])
    }

    @Test("updateContent edits existing message and persists")
    func updateContentEdits() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (store, fileURL, _) = makeStore(clock: clock)
        let runID = UUID()

        guard let message = store.append(runID: runID, role: .agent, content: "draft") else {
            Issue.record("append returned nil")
            return
        }

        store.updateContent(id: message.id, content: "final summary")
        #expect(store.messages.first?.content == "final summary")

        store.updateContent(id: message.id, content: "   ")
        #expect(store.messages.first?.content == "final summary", "blank update should be ignored")

        let reloaded = AgentRunTranscriptStore(fileURL: fileURL, clock: { clock.now })
        #expect(reloaded.messages.first?.content == "final summary")
    }

    @Test("updateRole changes role and persists")
    func updateRoleChanges() {
        let clock = MutableClock()
        clock.now = Date(timeIntervalSince1970: 100)
        let (store, fileURL, _) = makeStore(clock: clock)
        let runID = UUID()

        guard let message = store.append(runID: runID, role: .user, content: "follow-up") else {
            Issue.record("append returned nil")
            return
        }

        store.updateRole(id: message.id, role: .note)
        #expect(store.messages.first?.role == .note)

        let reloaded = AgentRunTranscriptStore(fileURL: fileURL, clock: { clock.now })
        #expect(reloaded.messages.first?.role == .note)
    }

    @Test("delete removes a single message")
    func deleteRemoves() {
        let (store, fileURL, _) = makeStore()
        let runID = UUID()

        guard let m1 = store.append(runID: runID, role: .user, content: "one"),
              let m2 = store.append(runID: runID, role: .agent, content: "two") else {
            Issue.record("append returned nil")
            return
        }

        store.delete(id: m1.id)
        #expect(store.messages.map(\.id) == [m2.id])

        let reloaded = AgentRunTranscriptStore(fileURL: fileURL)
        #expect(reloaded.messages.map(\.id) == [m2.id])
    }

    @Test("deleteAll removes messages for one run only")
    func deleteAllForRun() {
        let (store, _, _) = makeStore()
        let runA = UUID()
        let runB = UUID()

        _ = store.append(runID: runA, role: .user, content: "A1")
        _ = store.append(runID: runA, role: .agent, content: "A2")
        _ = store.append(runID: runB, role: .user, content: "B1")

        store.deleteAll(forRunID: runA)
        #expect(store.messages.count == 1)
        #expect(store.messages.first?.runID == runB)
    }
}
