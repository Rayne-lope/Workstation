import SwiftUI

/// Renders acceptance-criteria markdown as interactive checkboxes.
/// Lines that aren't checkboxes are shown as plain text above the list.
struct GoalChecklistView: View {
    let source: String
    /// Called with the full updated markdown string after a toggle.
    var onToggle: (String) -> Void

    private var goals: [GoalItem] { GoalParser.parse(source) }

    private var preamble: String? {
        let allLines = source.components(separatedBy: "\n")
        let checkboxIndices = Set(goals.map(\.lineIndex))
        let plain = allLines
            .enumerated()
            .filter { !checkboxIndices.contains($0.offset) }
            .map(\.element)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? nil : plain
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let preamble {
                Text(preamble)
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .padding(.bottom, 4)
            }
            ForEach(goals, id: \.lineIndex) { goal in
                GoalRow(goal: goal) {
                    let updated = GoalParser.toggle(source, at: goal.lineIndex)
                    onToggle(updated)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GoalRow: View {
    let goal: GoalItem
    var onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: goal.isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14, weight: goal.isChecked ? .semibold : .regular))
                    .foregroundStyle(goal.isChecked ? WorkstationTheme.green : WorkstationTheme.textMuted)
                    .frame(width: 16, height: 16)
                    .animation(.easeOut(duration: 0.15), value: goal.isChecked)

                Text(goal.text)
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(
                        goal.isChecked
                            ? WorkstationTheme.textMuted
                            : WorkstationTheme.textPrimary
                    )
                    .strikethrough(goal.isChecked, color: WorkstationTheme.textMuted)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(isHovering ? WorkstationTheme.hover : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
