import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("AppTheme")
struct AppThemeTests {
    @Test("All cases have display names")
    func allCasesHaveDisplayNames() {
        for theme in AppTheme.allCases {
            #expect(!theme.displayName.isEmpty)
        }
    }

    @Test("Raw values match expected strings")
    func rawValues() {
        #expect(AppTheme.system.rawValue == "system")
        #expect(AppTheme.obsidianDark.rawValue == "obsidianDark")
        #expect(AppTheme.beadsDark.rawValue == "beadsDark")
        #expect(AppTheme.light.rawValue == "light")
    }

    @Test("Codable roundtrip preserves value")
    func codableRoundtrip() throws {
        let theme = AppTheme.beadsDark
        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(AppTheme.self, from: data)
        #expect(decoded == theme)
    }
}

@Suite("AppPreferences Theme")
struct AppPreferencesThemeTests {
    @Test("Default theme is system")
    func defaultTheme() {
        let prefs = AppPreferences()
        #expect(prefs.theme == .system)
    }

    @Test("Theme can be set and encoded")
    func themeSetAndEncoded() throws {
        var prefs = AppPreferences()
        prefs.theme = .obsidianDark
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(decoded.theme == .obsidianDark)
    }

    @Test("Legacy JSON without theme decodes with system default")
    func legacyJSONWithoutTheme() throws {
        let json = """
        {
            "autoRestoreOnLaunch": true,
            "autoReloadEnabled": true,
            "defaultIssueType": "task",
            "defaultIssuePriority": 2,
            "defaultCloseReasonTemplate": "",
            "doneVisibilityWindowSeconds": 86400,
            "filterState": {},
            "localAI": {
                "isEnabled": false,
                "provider": "ollama",
                "baseURL": "http://localhost:11434",
                "fastModel": "qwen2.5-coder:3b",
                "strongModel": "qwen2.5-coder:7b"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(decoded.theme == .system)
    }
}

@Suite("SettingsTab")
struct SettingsTabTests {
    @Test("All cases have labels and icons")
    func allCasesHaveLabelsAndIcons() {
        for tab in SettingsTab.allCases {
            #expect(!tab.label.isEmpty)
            #expect(!tab.icon.isEmpty)
        }
    }

    @Test("ID matches rawValue")
    func idMatchesRawValue() {
        for tab in SettingsTab.allCases {
            #expect(tab.id == tab.rawValue)
        }
    }
}
