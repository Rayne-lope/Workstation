import Foundation
import Observation

@MainActor
@Observable
public final class PreferencesStore {
    public private(set) var preferences: AppPreferences = AppPreferences()
    public private(set) var errorMessage: String?

    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "com.beads.app.preferences"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        load()
    }

    public func update(_ mutate: (inout AppPreferences) -> Void) {
        var copy = preferences
        mutate(&copy)
        guard copy != preferences else { return }
        preferences = copy
        persist()
    }

    public func resetToDefaults() {
        preferences = AppPreferences()
        userDefaults.removeObject(forKey: storageKey)
        errorMessage = nil
    }

    public func clearErrorMessage() {
        errorMessage = nil
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            preferences = AppPreferences()
            return
        }
        do {
            preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load preferences: \(error.localizedDescription)"
            preferences = AppPreferences()
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(preferences)
            userDefaults.set(data, forKey: storageKey)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save preferences: \(error.localizedDescription)"
        }
    }
}
