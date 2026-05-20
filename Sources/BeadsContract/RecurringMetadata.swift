import Foundation

public struct RecurringHistoryEntry: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let completedAt: Date
    public let completedBy: String?
    public let notes: String?

    public init(id: UUID = UUID(), completedAt: Date, completedBy: String? = nil, notes: String? = nil) {
        self.id = id
        self.completedAt = completedAt
        self.completedBy = completedBy
        self.notes = notes
    }
}

public struct RecurringMetadata: Codable, Hashable, Sendable, Identifiable {
    public let issueID: String
    public var isRecurring: Bool
    public var cadenceDays: Int?
    public var history: [RecurringHistoryEntry]

    public var id: String { issueID }

    public init(
        issueID: String,
        isRecurring: Bool = true,
        cadenceDays: Int? = nil,
        history: [RecurringHistoryEntry] = []
    ) {
        self.issueID = issueID
        self.isRecurring = isRecurring
        self.cadenceDays = cadenceDays
        self.history = history
    }

    public var completionCount: Int { history.count }

    public var lastCompletedAt: Date? {
        history.max(by: { $0.completedAt < $1.completedAt })?.completedAt
    }

    /// Number of days the issue is overdue against its cadence target.
    /// Returns 0 (not overdue) when there is no cadence set, no history yet, or still within cadence window.
    public func overdueDays(now: Date) -> Int {
        guard let cadence = cadenceDays, cadence > 0 else { return 0 }
        guard let last = lastCompletedAt else { return 0 }
        let elapsed = now.timeIntervalSince(last)
        let cadenceSeconds = TimeInterval(cadence) * 86_400
        let overflow = elapsed - cadenceSeconds
        guard overflow > 0 else { return 0 }
        return Int(overflow / 86_400)
    }

    public func isOverdue(now: Date) -> Bool {
        overdueDays(now: now) > 0
    }
}

public enum CadenceTarget: Hashable, Sendable, CaseIterable {
    case none
    case weekly
    case monthly
    case quarterly

    public var days: Int? {
        switch self {
        case .none: return nil
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 90
        }
    }

    public var displayName: String {
        switch self {
        case .none: return "No cadence"
        case .weekly: return "Weekly · 7d"
        case .monthly: return "Monthly · 30d"
        case .quarterly: return "Quarterly · 90d"
        }
    }

    public static func from(days: Int?) -> CadenceTarget {
        guard let days else { return .none }
        switch days {
        case 7: return .weekly
        case 30: return .monthly
        case 90: return .quarterly
        default: return .none
        }
    }
}
