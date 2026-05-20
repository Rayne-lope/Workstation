import Foundation
import Testing
@testable import BeadsContract

@Suite("Kanban State Mapper")
struct KanbanStateMapperTests {
    private func issue(id: String = "bd-1", status: String? = nil, labels: [String]? = nil) -> BeadIssue {
        BeadIssue(id: id, title: "Test", status: status, labels: labels)
    }

    @Test("Maps closed → done")
    func mapsClosedToDone() {
        let column = KanbanStateMapper.column(for: issue(status: "closed"), readyIDs: [])
        #expect(column == .done)
    }

    @Test("Maps in_progress → inProgress")
    func mapsInProgress() {
        let column = KanbanStateMapper.column(for: issue(status: "in_progress"), readyIDs: [])
        #expect(column == .inProgress)
    }

    @Test("Maps blocked → blocked")
    func mapsBlocked() {
        let column = KanbanStateMapper.column(for: issue(status: "blocked"), readyIDs: [])
        #expect(column == .blocked)
    }

    @Test("Maps open issue present in readyIDs → ready")
    func mapsReadyByID() {
        let target = issue(id: "bd-2", status: "open")
        let column = KanbanStateMapper.column(for: target, readyIDs: ["bd-2"])
        #expect(column == .ready)
    }

    @Test("Maps open issue not in readyIDs → backlog")
    func mapsOpenToBacklog() {
        let column = KanbanStateMapper.column(for: issue(status: "open"), readyIDs: [])
        #expect(column == .backlog)
    }

    @Test("Closed issue still maps to done even if present in readyIDs (anti-leak)")
    func closedIssueDoesNotLeakIntoReady() {
        let target = issue(id: "bd-9", status: "closed")
        let column = KanbanStateMapper.column(for: target, readyIDs: ["bd-9"])
        #expect(column == .done)
    }

    @Test("Unknown status falls back to backlog without crashing")
    func unknownStatusFallsBackToBacklog() {
        let column = KanbanStateMapper.column(for: issue(status: "phantom-state"), readyIDs: [])
        #expect(column == .backlog)
    }

    @Test("Unknown status is detected by isKnownStatus")
    func detectsUnknownStatus() {
        #expect(KanbanStateMapper.isKnownStatus("open"))
        #expect(KanbanStateMapper.isKnownStatus("in_progress"))
        #expect(KanbanStateMapper.isKnownStatus("reopened"))
        #expect(KanbanStateMapper.isKnownStatus(nil))
        #expect(!KanbanStateMapper.isKnownStatus("phantom-state"))
        #expect(!KanbanStateMapper.isKnownStatus("WIP"))
    }

    @Test("Reopened status maps to backlog when not in readyIDs, ready when in set")
    func reopenedMapsCorrectly() {
        let reopened = issue(id: "bd-5", status: "reopened")
        #expect(KanbanStateMapper.column(for: reopened, readyIDs: []) == .backlog)
        #expect(KanbanStateMapper.column(for: reopened, readyIDs: ["bd-5"]) == .ready)
    }

    @Test("Status \"ready\" maps to ready column even when not present in readyIDs")
    func readyStatusMapsToReady() {
        let target = issue(id: "bd-7", status: "ready")
        #expect(KanbanStateMapper.column(for: target, readyIDs: []) == .ready)
        #expect(KanbanStateMapper.column(for: target, readyIDs: ["bd-7"]) == .ready)
    }

    @Test("KanbanColumn enum covers all six columns in stable order")
    func columnOrder() {
        #expect(KanbanColumn.allCases == [.backlog, .ready, .inProgress, .review, .blocked, .done])
    }

    @Test("Open issue listed in blockedIDs routes to blocked")
    func dependencyBlockedMapsToBlocked() {
        let target = issue(id: "bd-dep", status: "open")
        #expect(KanbanStateMapper.column(for: target, readyIDs: [], blockedIDs: ["bd-dep"]) == .blocked)
    }

    @Test("Dependency-blocked beats readyIDs membership")
    func dependencyBlockedBeatsReady() {
        let target = issue(id: "bd-dep", status: "open")
        #expect(KanbanStateMapper.column(for: target, readyIDs: ["bd-dep"], blockedIDs: ["bd-dep"]) == .blocked)
    }

    @Test("Closed issue stays in done even when listed in blockedIDs")
    func closedBeatsBlockedIDs() {
        let target = issue(id: "bd-dep", status: "closed")
        #expect(KanbanStateMapper.column(for: target, readyIDs: [], blockedIDs: ["bd-dep"]) == .done)
    }

    @Test("Human label beats blockedIDs — review wins over dependency-blocked")
    func humanLabelBeatsBlockedIDs() {
        let target = issue(id: "bd-dep", status: "open", labels: ["human"])
        #expect(KanbanStateMapper.column(for: target, readyIDs: [], blockedIDs: ["bd-dep"]) == .review)
    }

    @Test("Default blockedIDs parameter preserves prior behavior")
    func defaultBlockedIDsPreservesBehavior() {
        let target = issue(id: "bd-x", status: "open")
        #expect(KanbanStateMapper.column(for: target, readyIDs: ["bd-x"]) == .ready)
        #expect(KanbanStateMapper.column(for: target, readyIDs: []) == .backlog)
    }

    @Test("Open issue with 'human' label maps to review column")
    func humanLabelMapsToReview() {
        let target = issue(id: "bd-h", status: "in_progress", labels: ["human"])
        #expect(KanbanStateMapper.column(for: target, readyIDs: []) == .review)
    }

    @Test("Human label on a closed issue is overridden — closed stays in done")
    func closedWithHumanLabelStaysDone() {
        let target = issue(id: "bd-h", status: "closed", labels: ["human"])
        #expect(KanbanStateMapper.column(for: target, readyIDs: []) == .done)
    }

    @Test("Human label outranks readyIDs — open + ready + human → review")
    func humanLabelBeatsReadyIDs() {
        let target = issue(id: "bd-h", status: "open", labels: ["human"])
        #expect(KanbanStateMapper.column(for: target, readyIDs: ["bd-h"]) == .review)
    }
}
