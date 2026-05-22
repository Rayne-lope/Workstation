import Foundation

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general
    case defaults
    case localAI
    case agentProfiles

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .general: return "General"
        case .defaults: return "Defaults"
        case .localAI: return "Local AI"
        case .agentProfiles: return "Agent Profiles"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .defaults: return "list.bullet.clipboard"
        case .localAI: return "cpu"
        case .agentProfiles: return "person.2"
        }
    }
}
