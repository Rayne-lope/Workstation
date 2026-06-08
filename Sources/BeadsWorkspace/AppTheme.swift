import Foundation

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system
    case obsidianDark
    case beadsDark
    case workly
    case light

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .obsidianDark: return "Obsidian Dark"
        case .beadsDark: return "Beads Dark"
        case .workly: return "Workly"
        case .light: return "Light"
        }
    }
}
