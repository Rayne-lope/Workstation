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
    /// The relationship type of this issue when it appears as a nested dependency in `bd show` output.
    /// e.g. `"parent-child"`, `"blocks"`. Only populated in the `bd show` nested format.
    public let dependencyType: String?

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
        parentID: String? = nil,
        dependencyType: String? = nil
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
        self.dependencyType = dependencyType
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
        case dependencyType = "dependency_type"
    }

    // MARK: - Private helpers for dependency edge row format (bd list / bd ready output)

    /// Dependency edge row emitted by `bd list --json` / `bd ready --json`.
    /// Shape: { "issue_id": "A", "depends_on_id": "B", "type": "parent-child" }
    private struct DependencyEdge: Decodable {
        let issueID: String
        let dependsOnID: String
        let type: String
        enum CodingKeys: String, CodingKey {
            case issueID = "issue_id"
            case dependsOnID = "depends_on_id"
            case type
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        self.id = id
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
        self.dependencyType = try container.decodeIfPresent(String.self, forKey: .dependencyType)

        // `bd show` emits `dependencies`/`dependents` as nested BeadIssue objects.
        // `bd list`/`bd ready` emit them as edge rows ({issue_id, depends_on_id, type, ...}).
        //
        // Strategy:
        //  1. Try decoding as [BeadIssue] (bd show format).
        //     If any entry has dependency_type == "parent-child", derive parentID from it.
        //  2. If [BeadIssue] fails, try decoding as [DependencyEdge] (bd list format).
        //     Find an edge where issue_id == self.id && type == "parent-child" → that's the parent.
        //  3. Fall back to direct parent_id field (future-proof if bd ever emits it at top level).

        if let nestedDeps = try? container.decodeIfPresent([BeadIssue].self, forKey: .dependencies) {
            self.dependencies = nestedDeps
            // In bd show format, the parent of this issue is a dependency with dependency_type "parent-child"
            let parentDep = nestedDeps.first { $0.dependencyType == "parent-child" }
            self.parentID = parentDep?.id
                ?? (try? container.decodeIfPresent(String.self, forKey: .parentID))
                ?? nil
        } else if let edges = try? container.decodeIfPresent([DependencyEdge].self, forKey: .dependencies) {
            self.dependencies = nil
            // In bd list format, find an edge where this issue depends on a parent via parent-child
            let parentEdge = edges.first { $0.issueID == id && $0.type == "parent-child" }
            self.parentID = parentEdge?.dependsOnID
                ?? (try? container.decodeIfPresent(String.self, forKey: .parentID))
                ?? nil
        } else {
            self.dependencies = nil
            self.parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        }

        self.dependents = try? container.decodeIfPresent([BeadIssue].self, forKey: .dependents)
    }
}
