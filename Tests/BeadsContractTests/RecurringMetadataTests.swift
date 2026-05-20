import Foundation
import Testing
@testable import BeadsContract

@Suite("RecurringMetadata")
struct RecurringMetadataTests {
    @Test("Completion count equals history length")
    func completionCount() {
        let now = Date()
        let metadata = RecurringMetadata(
            issueID: "bd-1",
            history: [
                RecurringHistoryEntry(completedAt: now.addingTimeInterval(-86_400 * 2)),
                RecurringHistoryEntry(completedAt: now.addingTimeInterval(-86_400)),
            ]
        )
        #expect(metadata.completionCount == 2)
    }

    @Test("lastCompletedAt returns latest history entry")
    func lastCompletedAt() {
        let now = Date()
        let oldest = now.addingTimeInterval(-86_400 * 10)
        let newest = now.addingTimeInterval(-3_600)
        let metadata = RecurringMetadata(
            issueID: "bd-1",
            history: [
                RecurringHistoryEntry(completedAt: oldest),
                RecurringHistoryEntry(completedAt: newest),
            ]
        )
        #expect(metadata.lastCompletedAt == newest)
    }

    @Test("overdueDays returns 0 with no cadence")
    func overdueWithoutCadence() {
        let metadata = RecurringMetadata(
            issueID: "bd-1",
            cadenceDays: nil,
            history: [RecurringHistoryEntry(completedAt: Date(timeIntervalSinceNow: -86_400 * 30))]
        )
        #expect(metadata.overdueDays(now: Date()) == 0)
        #expect(metadata.isOverdue(now: Date()) == false)
    }

    @Test("overdueDays returns 0 when within cadence window")
    func overdueWithinWindow() {
        let now = Date()
        let metadata = RecurringMetadata(
            issueID: "bd-1",
            cadenceDays: 7,
            history: [RecurringHistoryEntry(completedAt: now.addingTimeInterval(-86_400 * 3))]
        )
        #expect(metadata.overdueDays(now: now) == 0)
    }

    @Test("overdueDays returns days past cadence target")
    func overduePastTarget() {
        let now = Date()
        let metadata = RecurringMetadata(
            issueID: "bd-1",
            cadenceDays: 7,
            history: [RecurringHistoryEntry(completedAt: now.addingTimeInterval(-86_400 * 12))]
        )
        #expect(metadata.overdueDays(now: now) == 5)
        #expect(metadata.isOverdue(now: now) == true)
    }

    @Test("overdueDays returns 0 with no history yet")
    func overdueWithoutHistory() {
        let metadata = RecurringMetadata(issueID: "bd-1", cadenceDays: 7, history: [])
        #expect(metadata.overdueDays(now: Date()) == 0)
    }

    @Test("CadenceTarget maps to days correctly")
    func cadenceTargetDays() {
        #expect(CadenceTarget.none.days == nil)
        #expect(CadenceTarget.weekly.days == 7)
        #expect(CadenceTarget.monthly.days == 30)
        #expect(CadenceTarget.quarterly.days == 90)
    }

    @Test("CadenceTarget.from(days:) round-trips known cadences")
    func cadenceFromDays() {
        #expect(CadenceTarget.from(days: 7) == .weekly)
        #expect(CadenceTarget.from(days: 30) == .monthly)
        #expect(CadenceTarget.from(days: 90) == .quarterly)
        #expect(CadenceTarget.from(days: nil) == .none)
        #expect(CadenceTarget.from(days: 14) == .none) // unknown maps to none
    }
}
