import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("RecurringStore")
struct RecurringStoreTests {
    private func freshTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recurring-store-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("load() on empty workspace yields empty store")
    func loadEmpty() {
        let dir = freshTempDir()
        let store = RecurringStore(workingDirectory: dir)
        store.load()
        #expect(store.metadataByID.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test("markRecurring persists sidecar and exposes via isRecurring")
    func markRecurring() {
        let dir = freshTempDir()
        let store = RecurringStore(workingDirectory: dir)
        store.markRecurring(id: "bd-1", cadenceDays: 7)

        #expect(store.isRecurring(id: "bd-1") == true)
        #expect(store.metadata(id: "bd-1")?.cadenceDays == 7)

        let fileURL = dir
            .appendingPathComponent(".beads/recurring/bd-1.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("appendHistory increments count and updates lastCompletedAt")
    func appendHistory() {
        let dir = freshTempDir()
        let store = RecurringStore(workingDirectory: dir)
        store.markRecurring(id: "bd-1")

        let now = Date()
        store.appendHistory(id: "bd-1", entry: RecurringHistoryEntry(completedAt: now, completedBy: "claude", notes: "first run"))

        let metadata = store.metadata(id: "bd-1")
        #expect(metadata?.completionCount == 1)
        #expect(metadata?.lastCompletedAt == now)
        #expect(metadata?.history.first?.completedBy == "claude")
    }

    @Test("appendHistory on unknown issue creates new recurring metadata")
    func appendHistoryCreatesNew() {
        let dir = freshTempDir()
        let store = RecurringStore(workingDirectory: dir)

        store.appendHistory(id: "bd-2", entry: RecurringHistoryEntry(completedAt: Date()))

        #expect(store.isRecurring(id: "bd-2") == true)
        #expect(store.metadata(id: "bd-2")?.completionCount == 1)
    }

    @Test("load() reads back persisted metadata after re-instantiation")
    func roundTripLoad() {
        let dir = freshTempDir()
        let writer = RecurringStore(workingDirectory: dir)
        writer.markRecurring(id: "bd-1", cadenceDays: 30)
        writer.appendHistory(id: "bd-1", entry: RecurringHistoryEntry(completedAt: Date(), completedBy: "me", notes: "audit done"))

        let reader = RecurringStore(workingDirectory: dir)
        reader.load()

        let metadata = reader.metadata(id: "bd-1")
        #expect(metadata?.isRecurring == true)
        #expect(metadata?.cadenceDays == 30)
        #expect(metadata?.completionCount == 1)
        #expect(metadata?.history.first?.notes == "audit done")
    }

    @Test("unmarkRecurring keeps history but flips flag")
    func unmark() {
        let dir = freshTempDir()
        let store = RecurringStore(workingDirectory: dir)
        store.markRecurring(id: "bd-1", cadenceDays: 7)
        store.appendHistory(id: "bd-1", entry: RecurringHistoryEntry(completedAt: Date()))

        store.unmarkRecurring(id: "bd-1")
        #expect(store.isRecurring(id: "bd-1") == false)
        #expect(store.metadata(id: "bd-1")?.completionCount == 1)
    }

    @Test("removeMetadata deletes sidecar and forgets the entry")
    func removeMetadata() {
        let dir = freshTempDir()
        let store = RecurringStore(workingDirectory: dir)
        store.markRecurring(id: "bd-1")

        let fileURL = dir.appendingPathComponent(".beads/recurring/bd-1.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        store.removeMetadata(id: "bd-1")
        #expect(store.metadataByID["bd-1"] == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("setCadence updates cadenceDays and turns on recurring flag")
    func setCadence() {
        let dir = freshTempDir()
        let store = RecurringStore(workingDirectory: dir)
        store.setCadence(id: "bd-1", days: 30)
        #expect(store.metadata(id: "bd-1")?.cadenceDays == 30)
        #expect(store.isRecurring(id: "bd-1") == true)
    }

    @Test("recurringIDs returns only active recurring issues")
    func recurringIDs() {
        let dir = freshTempDir()
        let store = RecurringStore(workingDirectory: dir)
        store.markRecurring(id: "bd-1")
        store.markRecurring(id: "bd-2")
        store.unmarkRecurring(id: "bd-2")

        #expect(store.recurringIDs == ["bd-1"])
    }
}
