import Foundation

public struct UpdateIssueInput: Sendable, Hashable {
    public let title: String?
    public let description: String?
    public let priority: Int?
    public let status: String?
    public let assignee: String?

    public init(
        title: String? = nil,
        description: String? = nil,
        priority: Int? = nil,
        status: String? = nil,
        assignee: String? = nil
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        self.status = status
        self.assignee = assignee
    }

    public var isEmpty: Bool {
        title == nil && description == nil && priority == nil && status == nil && assignee == nil
    }
}
