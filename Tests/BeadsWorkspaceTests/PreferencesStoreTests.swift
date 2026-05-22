import Foundation
import Testing
@testable import BeadsWorkspace

@MainActor
@Suite("PreferencesStore")
struct PreferencesStoreTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "preferences-store-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @Test("Initial preferences match the defaults")
    func initialMatchesDefaults() {
        let (defaults, _) = makeDefaults()
        let store = PreferencesStore(userDefaults: defaults)
        #expect(store.preferences == AppPreferences())
        #expect(store.errorMessage == nil)
    }

    @Test("update mutates and persists")
    func updatePersists() {
        let (defaults, _) = makeDefaults()
        let store = PreferencesStore(userDefaults: defaults)

        store.update {
            $0.defaultIssueType = "feature"
            $0.defaultIssuePriority = 1
            $0.lastSelectedPath = "/tmp/x"
        }

        #expect(store.preferences.defaultIssueType == "feature")
        #expect(store.preferences.defaultIssuePriority == 1)
        #expect(store.preferences.lastSelectedPath == "/tmp/x")

        let reloaded = PreferencesStore(userDefaults: defaults)
        #expect(reloaded.preferences.defaultIssueType == "feature")
        #expect(reloaded.preferences.defaultIssuePriority == 1)
        #expect(reloaded.preferences.lastSelectedPath == "/tmp/x")
    }

    @Test("resetToDefaults clears stored data")
    func resetClears() {
        let (defaults, _) = makeDefaults()
        let store = PreferencesStore(userDefaults: defaults)
        store.update { $0.defaultIssueType = "feature" }

        store.resetToDefaults()

        #expect(store.preferences == AppPreferences())

        let reloaded = PreferencesStore(userDefaults: defaults)
        #expect(reloaded.preferences == AppPreferences())
    }

    @Test("Corrupt persisted data surfaces errorMessage and falls back to defaults")
    func corruptDataSurfacesError() {
        let (defaults, _) = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "com.beads.app.preferences")
        let store = PreferencesStore(userDefaults: defaults)
        #expect(store.preferences == AppPreferences())
        #expect(store.errorMessage != nil)
    }

    @Test("Decoding missing fields falls back to defaults")
    func partialDecodeFallsBackToDefaults() throws {
        let (defaults, _) = makeDefaults()
        let partialJSON = """
        { "lastSelectedPath": "/tmp/y" }
        """
        defaults.set(Data(partialJSON.utf8), forKey: "com.beads.app.preferences")

        let store = PreferencesStore(userDefaults: defaults)
        #expect(store.preferences.lastSelectedPath == "/tmp/y")
        #expect(store.preferences.defaultIssueType == "task")
        #expect(store.preferences.defaultIssuePriority == 2)
        #expect(store.preferences.autoRestoreOnLaunch == true)
        #expect(store.preferences.localAI == LocalAISettings())
    }

    @Test("filterState persists per workspace key")
    func filterStatePersists() {
        let (defaults, _) = makeDefaults()
        let store = PreferencesStore(userDefaults: defaults)

        store.update {
            $0.filterState["/tmp/workspace"] = FilterState(
                priorities: [0, 1],
                issueTypes: ["bug"],
                assignees: [.claude, .me],
                labels: ["human"]
            )
        }

        let reloaded = PreferencesStore(userDefaults: defaults)
        let restored = reloaded.preferences.filterState["/tmp/workspace"]

        #expect(restored?.priorities == [0, 1])
        #expect(restored?.issueTypes == ["bug"])
        #expect(restored?.assignees == [.claude, .me])
        #expect(restored?.labels == ["human"])
    }

    @Test("localAI settings persist and reload")
    func localAISettingsPersist() {
        let (defaults, _) = makeDefaults()
        let store = PreferencesStore(userDefaults: defaults)

        store.update {
            $0.localAI = LocalAISettings(
                isEnabled: true,
                provider: .opencode,
                baseURL: "https://opencode.ai/zen/go/v1",
                fastModel: "opencode-go/deepseek-v4-flash",
                strongModel: "opencode-go/deepseek-v4-flash",
                apiKey: "local-key"
            )
        }

        let reloaded = PreferencesStore(userDefaults: defaults)
        #expect(reloaded.preferences.localAI == LocalAISettings(
            isEnabled: true,
            provider: .opencode,
            baseURL: "https://opencode.ai/zen/go/v1",
            fastModel: "opencode-go/deepseek-v4-flash",
            strongModel: "opencode-go/deepseek-v4-flash",
            apiKey: "local-key"
        ))
    }
}
