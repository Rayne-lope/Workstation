import Foundation

public struct CreateIssueInput: Sendable, Hashable {
    public let title: String
    public let description: String?
    public let designNotes: String?
    public let issueType: String?
    public let priority: Int?
    public let acceptanceCriteria: String?
    public let labels: [String]?

    public init(
        title: String,
        description: String? = nil,
        designNotes: String? = nil,
        issueType: String? = nil,
        priority: Int? = nil,
        acceptanceCriteria: String? = nil,
        labels: [String]? = nil
    ) {
        self.title = title
        self.description = description
        self.designNotes = designNotes
        self.issueType = issueType
        self.priority = priority
        self.acceptanceCriteria = acceptanceCriteria
        self.labels = labels
    }
}
