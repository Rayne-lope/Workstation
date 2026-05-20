import Foundation

public enum KanbanStateMapper {
    public static let knownStatuses: Set<String> = [
        "open",
        "ready",
        "in_progress",
        "blocked",
        "closed",
        "reopened"
    ]

    public static let humanReviewLabel = "human"

    public static func column(
        for issue: BeadIssue,
        readyIDs: Set<String>,
        blockedIDs: Set<String> = []
    ) -> KanbanColumn {
        if issue.status == "closed" {
            return .done
        }
        if issue.labels?.contains(humanReviewLabel) == true {
            return .review
        }
        if blockedIDs.contains(issue.id) {
            return .blocked
        }
        switch issue.status {
        case "in_progress":
            return .inProgress
        case "blocked":
            return .blocked
        case "ready":
            return .ready
        default:
            if readyIDs.contains(issue.id) {
                return .ready
            }
            return .backlog
        }
    }

    public static func isKnownStatus(_ status: String?) -> Bool {
        guard let status, !status.isEmpty else { return true }
        return knownStatuses.contains(status)
    }
}
