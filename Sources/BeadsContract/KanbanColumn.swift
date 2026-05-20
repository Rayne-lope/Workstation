import Foundation

public enum KanbanColumn: String, CaseIterable, Identifiable, Sendable, Hashable {
    case backlog = "Backlog"
    case ready = "Ready"
    case inProgress = "In Progress"
    case review = "Review"
    case blocked = "Blocked"
    case done = "Done"

    public var id: String { rawValue }
}
