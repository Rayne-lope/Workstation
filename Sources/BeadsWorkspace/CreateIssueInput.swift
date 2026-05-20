import Foundation

public struct CreateIssueInput: Sendable, Hashable {
    public let title: String
    public let description: String?
    public let issueType: String?
    public let priority: Int?
    public let acceptanceCriteria: String?

    public init(
        title: String,
        description: String? = nil,
        issueType: String? = nil,
        priority: Int? = nil,
        acceptanceCriteria: String? = nil
    ) {
        self.title = title
        self.description = description
        self.issueType = issueType
        self.priority = priority
        self.acceptanceCriteria = acceptanceCriteria
    }
}
