import Foundation
import Testing
@testable import BeadsContract

@Suite("GoalParser")
struct GoalParserTests {

    // MARK: - parse

    @Test("Parses unchecked and checked items from acceptance criteria")
    func parseMixed() {
        let src = """
        - [ ] First goal
        - [x] Second goal done
        - [X] Third also done
        """
        let items = GoalParser.parse(src)
        #expect(items.count == 3)
        #expect(items[0].text == "First goal")
        #expect(items[0].isChecked == false)
        #expect(items[0].lineIndex == 0)
        #expect(items[1].text == "Second goal done")
        #expect(items[1].isChecked == true)
        #expect(items[1].lineIndex == 1)
        #expect(items[2].isChecked == true)
    }

    @Test("Skips non-checkbox lines and reports correct lineIndex")
    func parsesWithPreamble() {
        let src = """
        Must satisfy the following:
        - [ ] Goal A
        - [x] Goal B
        """
        let items = GoalParser.parse(src)
        #expect(items.count == 2)
        #expect(items[0].lineIndex == 1)
        #expect(items[1].lineIndex == 2)
    }

    @Test("Returns empty array for string with no checkboxes")
    func parseNoGoals() {
        let items = GoalParser.parse("Just a description with no tasks.")
        #expect(items.isEmpty)
    }

    @Test("Supports asterisk and plus list markers")
    func parseAlternativeMarkers() {
        let src = """
        * [ ] Star item
        + [x] Plus item
        """
        let items = GoalParser.parse(src)
        #expect(items.count == 2)
        #expect(items[0].text == "Star item")
        #expect(items[1].isChecked == true)
    }

    // MARK: - toggle

    @Test("Toggles unchecked to checked")
    func toggleUnchecked() {
        let src = "- [ ] Do the thing"
        let result = GoalParser.toggle(src, at: 0)
        #expect(result == "- [x] Do the thing")
    }

    @Test("Toggles checked to unchecked")
    func toggleChecked() {
        let src = "- [x] Done"
        let result = GoalParser.toggle(src, at: 0)
        #expect(result == "- [ ] Done")
    }

    @Test("Toggle only affects the target line")
    func toggleDoesNotAffectOtherLines() {
        let src = """
        - [ ] Line 0
        - [ ] Line 1
        - [x] Line 2
        """
        let result = GoalParser.toggle(src, at: 1)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "- [ ] Line 0")
        #expect(lines[1] == "- [x] Line 1")
        #expect(lines[2] == "- [x] Line 2")
    }

    @Test("Toggle with out-of-bounds index returns source unchanged")
    func toggleOutOfBounds() {
        let src = "- [ ] Single"
        let result = GoalParser.toggle(src, at: 99)
        #expect(result == src)
    }

    @Test("Toggle does not corrupt [X] or [x] patterns in goal text itself")
    func toggleDoesNotCorruptTextBrackets() {
        // The checkbox marker is [x] at start; text contains "[X]code" — must not be replaced
        let src = "- [x] Install [X]code editor"
        let result = GoalParser.toggle(src, at: 0)
        #expect(result == "- [ ] Install [X]code editor")
    }

    @Test("Toggle does not corrupt [ ] in goal text body")
    func toggleDoesNotCorruptUncheckedTextBrackets() {
        // Checkbox is unchecked; text contains "[ ]" as part of prose
        let src = "- [ ] Array has [ ] default value"
        let result = GoalParser.toggle(src, at: 0)
        // Only the leading checkbox flips; prose [ ] survives
        #expect(result == "- [x] Array has [ ] default value")
    }

    // MARK: - hasGoals

    @Test("hasGoals returns true when checkboxes present")
    func hasGoalsTrue() {
        #expect(GoalParser.hasGoals("- [ ] something") == true)
        #expect(GoalParser.hasGoals("- [x] done") == true)
        #expect(GoalParser.hasGoals("text\n- [ ] item\nmore") == true)
    }

    @Test("hasGoals returns false for plain text or nil")
    func hasGoalsFalse() {
        #expect(GoalParser.hasGoals(nil) == false)
        #expect(GoalParser.hasGoals("") == false)
        #expect(GoalParser.hasGoals("Just a description.") == false)
        // "[x]" or "[ ]" appearing only in prose (not as a list item) must not trigger
        #expect(GoalParser.hasGoals("Use [x] to mark done in Jira.") == false)
    }

    @Test("hasGoals handles all three list markers")
    func hasGoalsAllMarkers() {
        #expect(GoalParser.hasGoals("+ [ ] Plus marker") == true)
        #expect(GoalParser.hasGoals("+ [x] Plus checked") == true)
        #expect(GoalParser.hasGoals("* [X] Star uppercase") == true)
    }

    // MARK: - progress

    @Test("progress counts done vs total correctly")
    func progressCounting() {
        let src = """
        - [ ] A
        - [x] B
        - [X] C
        - [ ] D
        """
        let (done, total) = GoalParser.progress(src)
        #expect(done == 2)
        #expect(total == 4)
    }

    @Test("progress returns (0, 0) for string with no checkboxes")
    func progressEmpty() {
        let (done, total) = GoalParser.progress("No checkboxes here.")
        #expect(done == 0)
        #expect(total == 0)
    }
}
