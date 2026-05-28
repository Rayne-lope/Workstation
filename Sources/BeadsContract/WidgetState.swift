import Foundation

public struct WidgetState: Codable, Sendable, Equatable {
    public struct ColumnStats: Codable, Sendable, Equatable {
        public var backlog: Int
        public var ready: Int
        public var inProgress: Int
        public var review: Int
        public var blocked: Int
        public var done: Int

        public init(
            backlog: Int = 0,
            ready: Int = 0,
            inProgress: Int = 0,
            review: Int = 0,
            blocked: Int = 0,
            done: Int = 0
        ) {
            self.backlog = backlog
            self.ready = ready
            self.inProgress = inProgress
            self.review = review
            self.blocked = blocked
            self.done = done
        }
    }

    public struct ActiveRun: Codable, Sendable, Equatable {
        public var issueID: String
        public var issueTitle: String
        public var assignee: String
        public var status: String // e.g. "running", "waiting_approval", "success", "failed"
        public var startedAt: Date

        public init(issueID: String, issueTitle: String, assignee: String, status: String, startedAt: Date) {
            self.issueID = issueID
            self.issueTitle = issueTitle
            self.assignee = assignee
            self.status = status
            self.startedAt = startedAt
        }
    }

    public struct NeedsReviewIssue: Codable, Sendable, Equatable {
        public var id: String
        public var title: String
        public var priority: Int
        public var updatedAt: String

        public init(id: String, title: String, priority: Int, updatedAt: String) {
            self.id = id
            self.title = title
            self.priority = priority
            self.updatedAt = updatedAt
        }
    }

    public var lastUpdated: Date
    public var workspaceName: String?
    public var workspacePath: String?
    public var stats: ColumnStats
    public var activeRun: ActiveRun?
    public var needsReviewIssues: [NeedsReviewIssue]

    public init(
        lastUpdated: Date = Date(),
        workspaceName: String? = nil,
        workspacePath: String? = nil,
        stats: ColumnStats = ColumnStats(),
        activeRun: ActiveRun? = nil,
        needsReviewIssues: [NeedsReviewIssue] = []
    ) {
        self.lastUpdated = lastUpdated
        self.workspaceName = workspaceName
        self.workspacePath = workspacePath
        self.stats = stats
        self.activeRun = activeRun
        self.needsReviewIssues = needsReviewIssues
    }
}
