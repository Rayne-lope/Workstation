import Foundation
import Observation

@MainActor
@Observable
public final class RecentProjectsStore {
    public private(set) var recents: [RecentProject] = []
    public private(set) var errorMessage: String?

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let maxEntries: Int
    private let clock: @Sendable () -> Date

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "com.beads.app.recentProjects",
        maxEntries: Int = 10,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.maxEntries = maxEntries
        self.clock = clock
        load()
    }

    public func record(_ workspace: ProjectWorkspace) {
        let now = clock()
        let entry = RecentProject(
            id: UUID(),
            selectedPath: workspace.selectedPath,
            rootPath: workspace.rootPath,
            name: workspace.name,
            lastOpenedAt: now
        )
        upsert(entry)
    }

    public func record(
        selectedPath: String,
        rootPath: String?,
        name: String
    ) {
        let entry = RecentProject(
            id: UUID(),
            selectedPath: selectedPath,
            rootPath: rootPath,
            name: name,
            lastOpenedAt: clock()
        )
        upsert(entry)
    }

    public func remove(id: UUID) {
        recents.removeAll { $0.id == id }
        persist()
    }

    public func clear() {
        recents.removeAll()
        userDefaults.removeObject(forKey: storageKey)
        errorMessage = nil
    }

    public func clearErrorMessage() {
        errorMessage = nil
    }

    private func upsert(_ entry: RecentProject) {
        if let index = recents.firstIndex(where: { $0.selectedPath == entry.selectedPath }) {
            let existing = recents[index]
            recents[index] = RecentProject(
                id: existing.id,
                selectedPath: entry.selectedPath,
                rootPath: entry.rootPath,
                name: entry.name,
                lastOpenedAt: entry.lastOpenedAt
            )
        } else {
            recents.append(entry)
        }
        recents.sort { $0.lastOpenedAt > $1.lastOpenedAt }
        if recents.count > maxEntries {
            recents = Array(recents.prefix(maxEntries))
        }
        persist()
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            recents = []
            return
        }
        do {
            let decoded = try JSONDecoder().decode([RecentProject].self, from: data)
            recents = decoded.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load recent projects: \(error.localizedDescription)"
            recents = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(recents)
            userDefaults.set(data, forKey: storageKey)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save recent projects: \(error.localizedDescription)"
        }
    }
}
