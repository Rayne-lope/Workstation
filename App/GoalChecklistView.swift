import SwiftUI

/// Renders acceptance-criteria markdown as interactive checkboxes.
/// Lines that aren't checkboxes are shown as plain text above the list.
///
/// Uses an optimistic local copy of the source so checkbox state updates
/// immediately on tap without waiting for the async `bd update` round-trip.
/// A guard prevents concurrent writes if the user taps rapidly.
struct GoalChecklistView: View {
    let source: String
    /// Called with the full updated markdown string after a toggle.
    var onToggle: (String) -> Void

    /// Optimistic copy shown in the UI; synced from `source` once a write completes.
    @State private var displaySource: String
    /// Prevents a second tap from firing before the first `bd update` completes.
    @State private var isUpdating = false

    init(source: String, onToggle: @escaping (String) -> Void) {
        self.source = source
        self.onToggle = onToggle
        self._displaySource = State(initialValue: source)
    }

    var body: some View {
        // Parse once per render — shared by preamble + checklist rows.
        let goals = GoalParser.parse(displaySource)
        let checkboxIndices = Set(goals.map(\.lineIndex))
        let allLines = displaySource.components(separatedBy: "\n")
        let preamble: String? = {
            let plain = allLines
                .enumerated()
                .filter { !checkboxIndices.contains($0.offset) }
                .map(\.element)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return plain.isEmpty ? nil : plain
        }()

        VStack(alignment: .leading, spacing: 6) {
            if let preamble {
                Text(preamble)
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .padding(.bottom, 4)
            }
            ForEach(goals, id: \.lineIndex) { goal in
                GoalRow(goal: goal, isDisabled: isUpdating) {
                    handleToggle(at: goal.lineIndex)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Sync displaySource once a store reload delivers fresh data.
        .onChange(of: source) { _, newValue in
            displaySource = newValue
            isUpdating = false
        }
    }

    private func handleToggle(at lineIndex: Int) {
        guard !isUpdating else { return }
        let updated = GoalParser.toggle(displaySource, at: lineIndex)
        guard updated != displaySource else { return } // no-op (line wasn't a checkbox)
        displaySource = updated   // optimistic UI update
        isUpdating = true
        onToggle(updated)
    }
}

private struct GoalRow: View {
    let goal: GoalItem
    let isDisabled: Bool
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
            .background(isHovering && !isDisabled ? WorkstationTheme.hover : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isDisabled)
    }
}
