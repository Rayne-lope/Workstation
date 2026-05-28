import Foundation

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general
    case defaults
    case board
    case localAI
    case agentProfiles
    case gitWorktrees

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .general: return "General"
        case .defaults: return "Defaults"
        case .board: return "Board"
        case .localAI: return "Local AI"
        case .agentProfiles: return "Agent Profiles"
        case .gitWorktrees: return "Git Worktrees"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .defaults: return "list.bullet.clipboard"
        case .board: return "square.grid.2x2"
        case .localAI: return "cpu"
        case .agentProfiles: return "person.2"
        case .gitWorktrees: return "arrow.triangle.branch"
        }
    }
}
