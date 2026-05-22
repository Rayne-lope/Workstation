import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("AgentProfileStore")
struct AgentProfileStoreTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "agent-profile-store-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @Test("Initial load exposes all built-in profiles")
    func initialLoadExposesBuiltIns() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)
        #expect(store.profiles.count == 10)
        let allBuiltIn = store.profiles.allSatisfy { $0.isBuiltIn }
        #expect(allBuiltIn)
    }

    @Test("Adding a custom profile persists across store instances")
    func addCustomProfilePersists() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)

        let custom = AgentProfile(
            name: "My Tester",
            role: .custom,
            command: "mytool",
            defaultPromptTemplate: "do {{issue_id}}"
        )
        store.addProfile(custom)

        #expect(store.profiles.count == 11)
        #expect(store.profiles.contains { $0.id == custom.id })

        let reloaded = AgentProfileStore(userDefaults: defaults)
        #expect(reloaded.profiles.count == 11)
        #expect(reloaded.profiles.contains { $0.id == custom.id && !$0.isBuiltIn })
    }

    @Test("Deleting a built-in profile is a no-op")
    func deletingBuiltInIsNoOp() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)
        let builtIn = store.profiles.first { $0.isBuiltIn }!

        store.deleteProfile(id: builtIn.id)

        #expect(store.profiles.contains { $0.id == builtIn.id })
        #expect(store.profiles.count == 10)
    }

    @Test("Deleting a custom profile removes it and clears persistence")
    func deletingCustomRemovesAndPersists() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)
        let custom = AgentProfile(name: "Temp", role: .custom, command: "x")
        store.addProfile(custom)

        store.deleteProfile(id: custom.id)
        #expect(!store.profiles.contains { $0.id == custom.id })

        let reloaded = AgentProfileStore(userDefaults: defaults)
        #expect(!reloaded.profiles.contains { $0.id == custom.id })
        #expect(reloaded.profiles.count == 10)
    }

    @Test("Updating a built-in profile mutates in-memory but does not persist")
    func updatingBuiltInIsInMemoryOnly() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)
        var builtIn = store.profiles.first { $0.isBuiltIn }!
        let originalName = builtIn.name
        builtIn.name = "Renamed"
        store.updateProfile(builtIn)

        #expect(store.profiles.first { $0.id == builtIn.id }?.name == "Renamed")
        #expect(store.profiles.first { $0.id == builtIn.id }?.isBuiltIn == true)

        let reloaded = AgentProfileStore(userDefaults: defaults)
        #expect(reloaded.profiles.first { $0.id == builtIn.id }?.name == originalName)
    }

    @Test("Updating a custom profile mutates and persists")
    func updatingCustomPersists() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)
        var custom = AgentProfile(name: "Original", role: .custom, command: "x")
        store.addProfile(custom)

        custom.name = "Renamed"
        store.updateProfile(custom)

        #expect(store.profiles.first { $0.id == custom.id }?.name == "Renamed")

        let reloaded = AgentProfileStore(userDefaults: defaults)
        #expect(reloaded.profiles.first { $0.id == custom.id }?.name == "Renamed")
    }

    @Test("resetToDefaults drops all custom profiles")
    func resetToDefaultsClearsCustom() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)
        store.addProfile(AgentProfile(name: "C1", role: .custom, command: "x"))
        store.addProfile(AgentProfile(name: "C2", role: .custom, command: "y"))
        #expect(store.profiles.count == 12)

        store.resetToDefaults()

        #expect(store.profiles.count == 10)
        let allBuiltIn = store.profiles.allSatisfy { $0.isBuiltIn }
        #expect(allBuiltIn)

        let reloaded = AgentProfileStore(userDefaults: defaults)
        #expect(reloaded.profiles.count == 10)
    }

    @Test("loadProfiles dedupes persisted entries whose id collides with a built-in")
    func loadProfilesFiltersBuiltInIDCollision() throws {
        let (defaults, _) = makeDefaults()
        let collidingCustom = AgentProfile(
            id: AgentProfile.specWriterID,
            name: "Imposter",
            role: .custom,
            command: "x",
            isBuiltIn: false
        )
        let extra = AgentProfile(name: "Real custom", role: .custom, command: "y")
        let data = try JSONEncoder().encode([collidingCustom, extra])
        defaults.set(data, forKey: "customAgentProfiles")

        let store = AgentProfileStore(userDefaults: defaults)

        #expect(store.profiles.count == 11)
        let withSpecWriterID = store.profiles.filter { $0.id == AgentProfile.specWriterID }
        #expect(withSpecWriterID.count == 1)
        #expect(withSpecWriterID.first?.isBuiltIn == true)
        #expect(store.profiles.contains { $0.id == extra.id })
    }

    @Test("loadProfiles dedupes duplicate ids within persisted custom list")
    func loadProfilesFiltersDuplicateCustomIDs() throws {
        let (defaults, _) = makeDefaults()
        let sharedID = UUID()
        let first = AgentProfile(id: sharedID, name: "First", role: .custom, command: "a")
        let second = AgentProfile(id: sharedID, name: "Second", role: .custom, command: "b")
        let data = try JSONEncoder().encode([first, second])
        defaults.set(data, forKey: "customAgentProfiles")

        let store = AgentProfileStore(userDefaults: defaults)

        #expect(store.profiles.count == 11)
        let withSharedID = store.profiles.filter { $0.id == sharedID }
        #expect(withSharedID.count == 1)
        #expect(withSharedID.first?.name == "First")
    }

    @Test("addProfile with built-in id is rejected (does not overwrite the built-in)")
    func addProfileRejectsBuiltInIDOverwrite() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)
        let imposter = AgentProfile(
            id: AgentProfile.specWriterID,
            name: "Imposter",
            role: .custom,
            command: "x"
        )
        store.addProfile(imposter)

        let matches = store.profiles.filter { $0.id == AgentProfile.specWriterID }
        #expect(matches.count == 1)
        #expect(matches.first?.isBuiltIn == true)
        #expect(matches.first?.name == "Codex Spec Writer")
    }

    @Test("Corrupt persisted data is reported via errorMessage and falls back to built-ins")
    func corruptDataSurfacesErrorMessage() {
        let (defaults, _) = makeDefaults()
        let bogus = Data("not even json".utf8)
        defaults.set(bogus, forKey: "customAgentProfiles")

        let store = AgentProfileStore(userDefaults: defaults)

        #expect(store.profiles.count == 10)
        let allBuiltIn = store.profiles.allSatisfy { $0.isBuiltIn }
        #expect(allBuiltIn)
        #expect(store.errorMessage != nil)
    }

    @Test("Successful save clears a previous errorMessage")
    func successfulSaveClearsError() {
        let (defaults, _) = makeDefaults()
        let bogus = Data("not even json".utf8)
        defaults.set(bogus, forKey: "customAgentProfiles")

        let store = AgentProfileStore(userDefaults: defaults)
        #expect(store.errorMessage != nil)

        store.addProfile(AgentProfile(name: "Recovered", role: .custom, command: "x"))

        #expect(store.errorMessage == nil)
    }

    @Test("addProfile with existing custom id updates in place instead of duplicating")
    func addProfileWithExistingCustomIDUpdates() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)
        let original = AgentProfile(name: "Original", role: .custom, command: "x")
        store.addProfile(original)

        var replacement = original
        replacement.name = "Replaced"
        store.addProfile(replacement)

        let matches = store.profiles.filter { $0.id == original.id }
        #expect(matches.count == 1)
        #expect(matches.first?.name == "Replaced")
    }

    @Test("Legacy storage key data is migrated to namespaced key on init")
    func migratesLegacyKeyToNamespacedKey() throws {
        let (defaults, _) = makeDefaults()
        let legacyKey = "customAgentProfiles"
        let newKey = "com.beads.app.customAgentProfiles"
        let custom = AgentProfile(name: "Legacy", role: .custom, command: "x")
        let data = try JSONEncoder().encode([custom])
        defaults.set(data, forKey: legacyKey)

        let store = AgentProfileStore(
            userDefaults: defaults,
            storageKey: newKey,
            legacyStorageKey: legacyKey
        )

        #expect(store.profiles.contains { $0.id == custom.id && !$0.isBuiltIn })
        #expect(defaults.data(forKey: legacyKey) == nil)
        #expect(defaults.data(forKey: newKey) != nil)
    }

    @Test("Migration is idempotent when re-initialized")
    func migrationIsIdempotent() throws {
        let (defaults, _) = makeDefaults()
        let legacyKey = "customAgentProfiles"
        let newKey = "com.beads.app.customAgentProfiles"
        let custom = AgentProfile(name: "Legacy", role: .custom, command: "x")
        let data = try JSONEncoder().encode([custom])
        defaults.set(data, forKey: legacyKey)

        _ = AgentProfileStore(
            userDefaults: defaults,
            storageKey: newKey,
            legacyStorageKey: legacyKey
        )
        let reloaded = AgentProfileStore(
            userDefaults: defaults,
            storageKey: newKey,
            legacyStorageKey: legacyKey
        )

        #expect(reloaded.profiles.contains { $0.id == custom.id })
        #expect(defaults.data(forKey: legacyKey) == nil)
    }

    @Test("Persisted JSON without new capability fields still decodes with defaults")
    func loadProfilesDecodesLegacyJSONWithoutNewFields() {
        let (defaults, _) = makeDefaults()
        let legacy = """
        [
          {
            "id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            "name": "Legacy Custom",
            "role": "custom",
            "command": "old-cli",
            "defaultPromptTemplate": "hi",
            "isBuiltIn": false
          }
        ]
        """
        defaults.set(Data(legacy.utf8), forKey: "com.beads.app.customAgentProfiles")

        let store = AgentProfileStore(userDefaults: defaults)
        let custom = store.profiles.first { !$0.isBuiltIn }
        #expect(custom?.name == "Legacy Custom")
        #expect(custom?.commandArgsTemplate == "")
        #expect(custom?.systemInstructions == "")
        #expect(custom?.cadenceDays == nil)
        #expect(custom?.canExecuteCode == false)
        #expect(custom?.shouldClaimIssue == false)
        #expect(custom?.shouldCloseIssue == false)
        #expect(store.errorMessage == nil)
    }

    @Test("executorProfile resolves all AI tokens to built-in executors")
    func executorProfileResolvesAIAssignees() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)

        let claude = store.executorProfile(forAssignee: "claude")
        #expect(claude?.id == AgentProfile.codingExecutorID)
        #expect(claude?.canExecuteCode == true)

        let codex = store.executorProfile(forAssignee: "Codex")
        #expect(codex?.id == AgentProfile.codexExecutorID)

        let kimi = store.executorProfile(forAssignee: "kimi")
        #expect(kimi?.id == AgentProfile.kimiExecutorID)

        let zhipu = store.executorProfile(forAssignee: "zhipu")
        #expect(zhipu?.id == AgentProfile.zhipuExecutorID)

        let gemini = store.executorProfile(forAssignee: "gemini")
        #expect(gemini?.id == AgentProfile.geminiExecutorID)

        let deepseek = store.executorProfile(forAssignee: "deepseek")
        #expect(deepseek?.id == AgentProfile.deepseekExecutorID)

        let minimax = store.executorProfile(forAssignee: "minimax")
        #expect(minimax?.id == AgentProfile.minimaxExecutorID)

        let other = store.executorProfile(forAssignee: "other")
        #expect(other?.canExecuteCode == true)
        #expect(other?.avatarKind == .claude || other?.avatarKind == .other)
    }

    @Test("executorProfile returns nil for human assignees")
    func executorProfileReturnsNilForHumans() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)

        #expect(store.executorProfile(forAssignee: "me") == nil)
        #expect(store.executorProfile(forAssignee: "rapi") == nil)
        #expect(store.executorProfile(forAssignee: "") == nil)
        #expect(store.executorProfile(forAssignee: "   ") == nil)
    }

    @Test("executorProfile resolved profile is claim-capable")
    func executorProfileIsClaimCapable() {
        let (defaults, _) = makeDefaults()
        let store = AgentProfileStore(userDefaults: defaults)

        let claude = store.executorProfile(forAssignee: "claude")
        #expect(claude?.shouldClaimIssue == true)
        #expect(claude?.claimAssigneeToken == "claude")

        let deepseek = store.executorProfile(forAssignee: "deepseek")
        #expect(deepseek?.shouldClaimIssue == true)
        #expect(deepseek?.claimAssigneeToken == "deepseek")

        let gemini = store.executorProfile(forAssignee: "gemini")
        #expect(gemini?.shouldClaimIssue == true)
        #expect(gemini?.claimAssigneeToken == "gemini")
    }
}
