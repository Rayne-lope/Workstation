import Foundation

public struct BeadIssue: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let status: String?
    public let priority: Int?
    public let issueType: String?
    public let description: String?
    public let acceptanceCriteria: String?
    public let notes: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let closedAt: String?
    public let labels: [String]?
    public let assignee: String?
    public let blockedBy: [String]?
    public let dependencies: [BeadIssue]?
    public let dependents: [BeadIssue]?
    public let parentID: String?

    public init(
        id: String,
        title: String,
        status: String? = nil,
        priority: Int? = nil,
        issueType: String? = nil,
        description: String? = nil,
        acceptanceCriteria: String? = nil,
        notes: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        closedAt: String? = nil,
        labels: [String]? = nil,
        assignee: String? = nil,
        blockedBy: [String]? = nil,
        dependencies: [BeadIssue]? = nil,
        dependents: [BeadIssue]? = nil,
        parentID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.issueType = issueType
        self.description = description
        self.acceptanceCriteria = acceptanceCriteria
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.closedAt = closedAt
        self.labels = labels
        self.assignee = assignee
        self.blockedBy = blockedBy
        self.dependencies = dependencies
        self.dependents = dependents
        self.parentID = parentID
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case priority
        case issueType = "issue_type"
        case description
        case acceptanceCriteria = "acceptance_criteria"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case labels
        case assignee
        case blockedBy = "blocked_by"
        case dependencies
        case dependents
        case parentID = "parent_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        self.issueType = try container.decodeIfPresent(String.self, forKey: .issueType)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.acceptanceCriteria = try container.decodeIfPresent(String.self, forKey: .acceptanceCriteria)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        self.closedAt = try container.decodeIfPresent(String.self, forKey: .closedAt)
        self.labels = try container.decodeIfPresent([String].self, forKey: .labels)
        self.assignee = try container.decodeIfPresent(String.self, forKey: .assignee)
        self.blockedBy = try container.decodeIfPresent([String].self, forKey: .blockedBy)
        // `bd list`/`bd ready` emit `dependencies` as edge rows ({issue_id, depends_on_id, type}),
        // while `bd show` emits nested BeadIssue objects. Decode tolerantly: only keep the nested
        // shape, ignore the edge shape silently.
        self.dependencies = try? container.decodeIfPresent([BeadIssue].self, forKey: .dependencies)
        self.dependents = try? container.decodeIfPresent([BeadIssue].self, forKey: .dependents)
        self.parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
    }
}
