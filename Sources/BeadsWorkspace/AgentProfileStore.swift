#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation
import Observation

@MainActor
@Observable
public final class AgentProfileStore {
    public private(set) var profiles: [AgentProfile] = []
    public private(set) var errorMessage: String?

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let legacyStorageKey: String?

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "com.beads.app.customAgentProfiles",
        legacyStorageKey: String? = "customAgentProfiles"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.legacyStorageKey = legacyStorageKey
        migrateLegacyKeyIfNeeded()
        loadProfiles()
    }

    private func migrateLegacyKeyIfNeeded() {
        guard let legacyStorageKey, legacyStorageKey != storageKey else { return }
        if userDefaults.data(forKey: storageKey) != nil { return }
        guard let legacyData = userDefaults.data(forKey: legacyStorageKey) else { return }
        userDefaults.set(legacyData, forKey: storageKey)
        userDefaults.removeObject(forKey: legacyStorageKey)
    }

    public func loadProfiles() {
        let builtIns = AgentProfile.builtInProfiles
        let builtInIDs = Set(builtIns.map(\.id))
        var seen = builtInIDs
        let custom = decodeCustomProfiles().compactMap { profile -> AgentProfile? in
            var entry = profile
            if entry.isBuiltIn { entry.isBuiltIn = false }
            guard seen.insert(entry.id).inserted else { return nil }
            return entry
        }
        profiles = builtIns + custom
    }

    public func addProfile(_ profile: AgentProfile) {
        var inserted = profile
        if inserted.isBuiltIn {
            inserted.isBuiltIn = false
        }
        if let index = profiles.firstIndex(where: { $0.id == inserted.id }) {
            if profiles[index].isBuiltIn { return }
            profiles[index] = inserted
        } else {
            profiles.append(inserted)
        }
        saveCustomProfiles()
    }

    public func updateProfile(_ profile: AgentProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let existing = profiles[index]
        if existing.isBuiltIn {
            var updated = profile
            updated.isBuiltIn = true
            profiles[index] = updated
            return
        }
        profiles[index] = profile
        saveCustomProfiles()
    }

    public func deleteProfile(id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        if profiles[index].isBuiltIn { return }
        profiles.remove(at: index)
        saveCustomProfiles()
    }

    public func resetToDefaults() {
        userDefaults.removeObject(forKey: storageKey)
        profiles = AgentProfile.builtInProfiles
        errorMessage = nil
    }

    public func clearErrorMessage() {
        errorMessage = nil
    }

    /// Map an assignee token (e.g. "claude", "codex", "other") to an executor profile.
    /// Returns nil for human/unknown assignees so callers can fall back to plain assignment.
    public func executorProfile(forAssignee token: String) -> AgentProfile? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let brand = AssigneeAvatarResolver.brandKind(forShortToken: trimmed) else {
            return nil
        }
        if let match = profiles.first(where: { $0.canExecuteCode && $0.avatarKind == brand }) {
            return match
        }
        return AgentProfile.builtInExecutor(forBrand: brand)
    }

    private func decodeCustomProfiles() -> [AgentProfile] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        do {
            let decoded = try JSONDecoder().decode([AgentProfile].self, from: data)
            return decoded
        } catch {
            errorMessage = "Failed to load custom agent profiles: \(error.localizedDescription)"
            return []
        }
    }

    private func saveCustomProfiles() {
        let custom = profiles.filter { !$0.isBuiltIn }
        do {
            let data = try JSONEncoder().encode(custom)
            userDefaults.set(data, forKey: storageKey)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save custom agent profiles: \(error.localizedDescription)"
        }
    }
}
