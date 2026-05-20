import Foundation
import Testing
@testable import BeadsWorkspace

@MainActor
@Suite("RecentProjectsStore")
struct RecentProjectsStoreTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "recent-projects-store-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private final class MutableClock: @unchecked Sendable {
        var now: Date = Date(timeIntervalSince1970: 0)
    }

    private func makeWorkspace(path: String, name: String) -> ProjectWorkspace {
        ProjectWorkspace(
            selectedURL: URL(fileURLWithPath: path),
            rootURL: URL(fileURLWithPath: path),
            inspectionURL: URL(fileURLWithPath: path),
            name: name,
            validationState: .valid,
            checks: []
        )
    }

    @Test("Initial load yields no recents")
    func initialLoadEmpty() {
        let (defaults, _) = makeDefaults()
        let store = RecentProjectsStore(userDefaults: defaults)
        #expect(store.recents.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test("record appends a fresh entry")
    func recordAppends() {
        let (defaults, _) = makeDefaults()
        let store = RecentProjectsStore(userDefaults: defaults)
        store.record(makeWorkspace(path: "/tmp/a", name: "a"))
        #expect(store.recents.count == 1)
        #expect(store.recents.first?.selectedPath == "/tmp/a")
    }

    @Test("record dedupes by selectedPath and refreshes lastOpenedAt")
    func recordDedupes() {
        let (defaults, _) = makeDefaults()
        let clock = MutableClock()
        let store = RecentProjectsStore(
            userDefaults: defaults,
            clock: { clock.now }
        )

        clock.now = Date(timeIntervalSince1970: 100)
        store.record(makeWorkspace(path: "/tmp/a", name: "a"))
        let firstID = store.recents.first!.id

        clock.now = Date(timeIntervalSince1970: 200)
        store.record(makeWorkspace(path: "/tmp/a", name: "a-renamed"))

        #expect(store.recents.count == 1)
        #expect(store.recents.first?.id == firstID)
        #expect(store.recents.first?.name == "a-renamed")
        #expect(store.recents.first?.lastOpenedAt == Date(timeIntervalSince1970: 200))
    }

    @Test("Recents sort newest first")
    func sortsByLastOpenedDesc() {
        let (defaults, _) = makeDefaults()
        let clock = MutableClock()
        let store = RecentProjectsStore(
            userDefaults: defaults,
            clock: { clock.now }
        )

        clock.now = Date(timeIntervalSince1970: 100)
        store.record(makeWorkspace(path: "/tmp/a", name: "a"))
        clock.now = Date(timeIntervalSince1970: 200)
        store.record(makeWorkspace(path: "/tmp/b", name: "b"))
        clock.now = Date(timeIntervalSince1970: 150)
        store.record(makeWorkspace(path: "/tmp/c", name: "c"))

        #expect(store.recents.map(\.selectedPath) == ["/tmp/b", "/tmp/c", "/tmp/a"])
    }

    @Test("Trim to maxEntries drops oldest")
    func trimToMax() {
        let (defaults, _) = makeDefaults()
        let clock = MutableClock()
        let store = RecentProjectsStore(
            userDefaults: defaults,
            maxEntries: 3,
            clock: { clock.now }
        )

        for index in 1...5 {
            clock.now = Date(timeIntervalSince1970: Double(index * 100))
            store.record(makeWorkspace(path: "/tmp/\(index)", name: "p\(index)"))
        }

        #expect(store.recents.count == 3)
        #expect(store.recents.map(\.selectedPath) == ["/tmp/5", "/tmp/4", "/tmp/3"])
    }

    @Test("remove(id:) drops the entry and persists")
    func removeAndPersist() {
        let (defaults, _) = makeDefaults()
        let store = RecentProjectsStore(userDefaults: defaults)
        store.record(makeWorkspace(path: "/tmp/a", name: "a"))
        store.record(makeWorkspace(path: "/tmp/b", name: "b"))
        let targetID = store.recents.first { $0.selectedPath == "/tmp/a" }!.id

        store.remove(id: targetID)

        #expect(store.recents.count == 1)
        #expect(store.recents.first?.selectedPath == "/tmp/b")

        let reloaded = RecentProjectsStore(userDefaults: defaults)
        #expect(reloaded.recents.count == 1)
        #expect(reloaded.recents.first?.selectedPath == "/tmp/b")
    }

    @Test("Persistence survives across store instances")
    func persistenceAcrossInstances() {
        let (defaults, _) = makeDefaults()
        let original = RecentProjectsStore(userDefaults: defaults)
        original.record(makeWorkspace(path: "/tmp/a", name: "a"))
        original.record(makeWorkspace(path: "/tmp/b", name: "b"))

        let reloaded = RecentProjectsStore(userDefaults: defaults)
        #expect(reloaded.recents.count == 2)
        #expect(Set(reloaded.recents.map(\.selectedPath)) == ["/tmp/a", "/tmp/b"])
    }

    @Test("clear() drops everything")
    func clearDropsAll() {
        let (defaults, _) = makeDefaults()
        let store = RecentProjectsStore(userDefaults: defaults)
        store.record(makeWorkspace(path: "/tmp/a", name: "a"))
        store.record(makeWorkspace(path: "/tmp/b", name: "b"))

        store.clear()

        #expect(store.recents.isEmpty)
        let reloaded = RecentProjectsStore(userDefaults: defaults)
        #expect(reloaded.recents.isEmpty)
    }

    @Test("Corrupt persisted data surfaces errorMessage and falls back to empty")
    func corruptDataSurfacesError() {
        let (defaults, _) = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "com.beads.app.recentProjects")
        let store = RecentProjectsStore(userDefaults: defaults)
        #expect(store.recents.isEmpty)
        #expect(store.errorMessage != nil)
    }
}
