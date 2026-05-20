import Foundation

public enum AgentRunStatus: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case prepared
    case terminalOpened
    case needsReview
    case accepted
    case failed
    case abandoned

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .prepared:
            return "Prepared"
        case .terminalOpened:
            return "Terminal Opened"
        case .needsReview:
            return "Needs Review"
        case .accepted:
            return "Accepted"
        case .failed:
            return "Failed"
        case .abandoned:
            return "Abandoned"
        }
    }

    public var isFinalized: Bool {
        switch self {
        case .prepared, .terminalOpened:
            return false
        case .needsReview, .accepted, .failed, .abandoned:
            return true
        }
    }
}
