import Foundation

public enum IssueFilterAssignee: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case claude
    case codex
    case other
    case me

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .other:
            return "Other"
        case .me:
            return "Me"
        }
    }
}

public struct FilterState: Codable, Equatable, Sendable {
    public var priorities: Set<Int>
    public var issueTypes: Set<String>
    public var assignees: Set<IssueFilterAssignee>
    public var labels: Set<String>

    public init(
        priorities: Set<Int> = [],
        issueTypes: Set<String> = [],
        assignees: Set<IssueFilterAssignee> = [],
        labels: Set<String> = []
    ) {
        self.priorities = priorities
        self.issueTypes = Self.normalize(issueTypes)
        self.assignees = assignees
        self.labels = Self.normalize(labels)
    }

    public var isEmpty: Bool {
        priorities.isEmpty && issueTypes.isEmpty && assignees.isEmpty && labels.isEmpty
    }

    public mutating func clear() {
        priorities.removeAll()
        issueTypes.removeAll()
        assignees.removeAll()
        labels.removeAll()
    }

    public mutating func togglePriority(_ priority: Int) {
        if priorities.contains(priority) {
            priorities.remove(priority)
        } else {
            priorities.insert(priority)
        }
    }

    public mutating func toggleIssueType(_ issueType: String) {
        let normalized = Self.normalize(issueType)
        if issueTypes.contains(normalized) {
            issueTypes.remove(normalized)
        } else {
            issueTypes.insert(normalized)
        }
    }

    public mutating func toggleAssignee(_ assignee: IssueFilterAssignee) {
        if assignees.contains(assignee) {
            assignees.remove(assignee)
        } else {
            assignees.insert(assignee)
        }
    }

    public mutating func toggleLabel(_ label: String) {
        let normalized = Self.normalize(label)
        if labels.contains(normalized) {
            labels.remove(normalized)
        } else {
            labels.insert(normalized)
        }
    }

    public func normalizedCopy() -> FilterState {
        FilterState(
            priorities: priorities,
            issueTypes: issueTypes,
            assignees: assignees,
            labels: labels
        )
    }

    private static func normalize(_ values: Set<String>) -> Set<String> {
        Set(values.map { normalize($0) })
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
