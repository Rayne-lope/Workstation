import Foundation
import Testing
@testable import BeadsContract

@Suite("Kanban Drop Resolver")
struct KanbanDropResolverTests {
    @Test("Ready → InProgress = claim")
    func readyToInProgress() {
        #expect(KanbanDropResolver.action(from: .ready, to: .inProgress) == .claim)
    }

    @Test("Backlog → InProgress = claim")
    func backlogToInProgress() {
        #expect(KanbanDropResolver.action(from: .backlog, to: .inProgress) == .claim)
    }

    @Test("InProgress → Review = requestHumanReview")
    func inProgressToReview() {
        #expect(KanbanDropResolver.action(from: .inProgress, to: .review) == .requestHumanReview)
    }

    @Test("InProgress → Done = close")
    func inProgressToDone() {
        #expect(KanbanDropResolver.action(from: .inProgress, to: .done) == .close)
    }

    @Test("Review → Done = close")
    func reviewToDone() {
        #expect(KanbanDropResolver.action(from: .review, to: .done) == .close)
    }

    @Test("Same column = noop")
    func sameColumn() {
        for column in KanbanColumn.allCases {
            #expect(KanbanDropResolver.action(from: column, to: column) == .noop)
        }
    }

    @Test("Done → any non-done = noop (no reverse transitions)")
    func doneToAny() {
        for target in KanbanColumn.allCases where target != .done {
            #expect(KanbanDropResolver.action(from: .done, to: target) == .noop)
        }
    }

    @Test("Blocked → any = noop")
    func blockedToAny() {
        for target in KanbanColumn.allCases where target != .blocked {
            #expect(KanbanDropResolver.action(from: .blocked, to: target) == .noop)
        }
    }

    @Test("Backlog → Review = noop (must claim first)")
    func backlogToReview() {
        #expect(KanbanDropResolver.action(from: .backlog, to: .review) == .noop)
    }

    @Test("Ready → Done = noop (must claim first)")
    func readyToDone() {
        #expect(KanbanDropResolver.action(from: .ready, to: .done) == .noop)
    }

    @Test("Review → InProgress = noop (reverse not supported)")
    func reviewToInProgress() {
        #expect(KanbanDropResolver.action(from: .review, to: .inProgress) == .noop)
    }

    @Test("Drop on Ready / Backlog / Blocked targets always noop")
    func nonActionableTargets() {
        let nonActionable: [KanbanColumn] = [.ready, .backlog, .blocked]
        for target in nonActionable {
            for source in KanbanColumn.allCases where source != target {
                #expect(
                    KanbanDropResolver.action(from: source, to: target) == .noop,
                    "from=\(source) to=\(target)"
                )
            }
        }
    }
}
