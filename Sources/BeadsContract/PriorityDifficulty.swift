import Foundation

public enum PriorityDifficulty: String, CaseIterable, Sendable {
    case must = "Must"
    case important = "Important"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    public static func from(priority: Int?) -> PriorityDifficulty? {
        guard let priority else { return nil }
        switch priority {
        case 0: return .must
        case 1: return .important
        case 2: return .high
        case 3: return .medium
        case 4: return .low
        default: return nil
        }
    }

    public var displayName: String { rawValue }
}
