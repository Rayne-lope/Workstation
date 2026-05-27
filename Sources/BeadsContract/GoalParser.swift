import Foundation

/// A single `- [ ]` or `- [x]` checkbox line parsed from a markdown string.
public struct GoalItem: Sendable, Equatable {
    public let text: String       // label after the checkbox prefix
    public let isChecked: Bool
    public let lineIndex: Int     // 0-based index in the original newline-split array
}

/// Stateless parser for markdown task-list lines (`- [ ] text` / `- [x] text`).
public enum GoalParser: Sendable {

    /// Parse all checkbox lines from `source`. Non-checkbox lines are skipped.
    public static func parse(_ source: String) -> [GoalItem] {
        // Matches:  - [ ] text  OR  - [x] / - [X] text  (also * and +)
        let checkboxRegex = /^[-*+]\s+\[([ xX])\]\s+(.+)$/
        return source
            .components(separatedBy: "\n")
            .enumerated()
            .compactMap { (index, line) -> GoalItem? in
                guard let match = line.firstMatch(of: checkboxRegex) else { return nil }
                let checked = match.output.1 != " "
                let text = String(match.output.2)
                return GoalItem(text: text, isChecked: checked, lineIndex: index)
            }
    }

    /// Toggle the checkbox at `lineIndex` in `source`. Returns the modified string unchanged if
    /// the line isn't a checkbox or the index is out of bounds.
    ///
    /// Uses a regex anchored to the start of the line so that bracket patterns in the goal
    /// *text* (e.g. `[X]code`) are never accidentally replaced.
    public static func toggle(_ source: String, at lineIndex: Int) -> String {
        var lines = source.components(separatedBy: "\n")
        guard lineIndex < lines.count else { return source }
        let line = lines[lineIndex]
        // Capture: (1) "- [" prefix, (2) checkbox char (space / x / X), (3) "] rest"
        lines[lineIndex] = line.replacing(
            /^([-*+]\s+\[)([ xX])(\].+)$/
        ) { match in
            let prefix = String(match.output.1)
            let current = match.output.2
            let suffix = String(match.output.3)
            let toggled: Character = current == " " ? "x" : " "
            return "\(prefix)\(toggled)\(suffix)"
        }
        return lines.joined(separator: "\n")
    }

    /// `true` if `source` contains at least one valid checkbox line.
    /// Uses the same regex as `parse()` — the two can never diverge.
    public static func hasGoals(_ source: String?) -> Bool {
        guard let s = source, !s.isEmpty else { return false }
        return !parse(s).isEmpty
    }

    /// How many goals are checked vs total.
    public static func progress(_ source: String) -> (done: Int, total: Int) {
        let items = parse(source)
        return (items.filter(\.isChecked).count, items.count)
    }
}
