import Foundation

public enum KanbanDropAction: Equatable, Sendable {
    case noop
    case claim
    case requestHumanReview
    case close
}

public enum KanbanDropResolver {
    public static func action(
        from source: KanbanColumn,
        to target: KanbanColumn
    ) -> KanbanDropAction {
        if source == target { return .noop }
        switch target {
        case .inProgress:
            return (source == .backlog || source == .ready) ? .claim : .noop
        case .review:
            return source == .inProgress ? .requestHumanReview : .noop
        case .done:
            return (source == .inProgress || source == .review) ? .close : .noop
        case .ready, .backlog, .blocked:
            return .noop
        }
    }
}
