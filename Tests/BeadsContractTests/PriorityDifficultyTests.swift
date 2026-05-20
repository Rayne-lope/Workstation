import Foundation
import Testing
@testable import BeadsContract

@Suite("PriorityDifficulty")
struct PriorityDifficultyTests {
    @Test("Priority 0 maps to Must")
    func priorityZeroMapsToMust() {
        #expect(PriorityDifficulty.from(priority: 0) == .must)
    }

    @Test("Priority 1 maps to Important")
    func priorityOneMapsToImportant() {
        #expect(PriorityDifficulty.from(priority: 1) == .important)
    }

    @Test("Priority 2 maps to High")
    func priorityTwoMapsToHigh() {
        #expect(PriorityDifficulty.from(priority: 2) == .high)
    }

    @Test("Priority 3 maps to Medium")
    func priorityThreeMapsToMedium() {
        #expect(PriorityDifficulty.from(priority: 3) == .medium)
    }

    @Test("Priority 4 maps to Low")
    func priorityFourMapsToLow() {
        #expect(PriorityDifficulty.from(priority: 4) == .low)
    }

    @Test("Nil priority maps to nil")
    func nilPriorityMapsToNil() {
        #expect(PriorityDifficulty.from(priority: nil) == nil)
    }

    @Test("Out-of-range priorities map to nil")
    func outOfRangePriorityMapsToNil() {
        #expect(PriorityDifficulty.from(priority: -1) == nil)
        #expect(PriorityDifficulty.from(priority: 5) == nil)
        #expect(PriorityDifficulty.from(priority: 99) == nil)
        #expect(PriorityDifficulty.from(priority: Int.min) == nil)
        #expect(PriorityDifficulty.from(priority: Int.max) == nil)
    }

    @Test("allCases has 5 cases in stable Must→Low order")
    func allCasesOrder() {
        #expect(PriorityDifficulty.allCases == [.must, .important, .high, .medium, .low])
    }

    @Test("displayName equals rawValue for every case")
    func displayNameMatchesRawValue() {
        for difficulty in PriorityDifficulty.allCases {
            #expect(difficulty.displayName == difficulty.rawValue)
        }
    }

    @Test("Raw values are the user-facing labels")
    func rawValuesMatchExpectedLabels() {
        #expect(PriorityDifficulty.must.rawValue == "Must")
        #expect(PriorityDifficulty.important.rawValue == "Important")
        #expect(PriorityDifficulty.high.rawValue == "High")
        #expect(PriorityDifficulty.medium.rawValue == "Medium")
        #expect(PriorityDifficulty.low.rawValue == "Low")
    }
}
