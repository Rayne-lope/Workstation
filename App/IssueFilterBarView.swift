import SwiftUI

struct IssueFilterBarView: View {
    let store: IssueStore
    let onClearAll: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    filterGroup(title: "Priority") {
                        HStack(spacing: 8) {
                            ForEach(store.availablePriorities, id: \.self) { priority in
                                priorityChip(priority)
                            }
                        }
                    }

                    filterGroup(title: "Type") {
                        HStack(spacing: 8) {
                            ForEach(store.availableIssueTypes, id: \.self) { issueType in
                                issueTypeChip(issueType)
                            }
                        }
                    }

                    filterGroup(title: "Assignee") {
                        HStack(spacing: 8) {
                            ForEach(store.availableAssigneeKinds) { assignee in
                                assigneeChip(assignee)
                            }
                        }
                    }

                    if !store.availableLabels.isEmpty {
                        filterGroup(title: "Label") {
                            HStack(spacing: 8) {
                                ForEach(store.availableLabels, id: \.self) { label in
                                    labelChip(label)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
            }

            if store.hasActiveFilters {
                Button(action: onClearAll) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Clear all")
                            .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    }
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(WorkstationTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 28)
            }
        }
        .background(WorkstationTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    private func filterGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title.uppercased())
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textMuted)
                .tracking(0.8)

            content()
        }
    }

    @ViewBuilder
    private func priorityChip(_ priority: Int) -> some View {
        let isActive = store.filterState.priorities.contains(priority)
        Button {
            store.togglePriority(priority)
        } label: {
            filterChip(
                label: "P\(priority)",
                isActive: isActive,
                accent: WorkstationTheme.difficultyColor(priority)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func issueTypeChip(_ issueType: String) -> some View {
        let normalized = issueType.lowercased()
        let isActive = store.filterState.issueTypes.contains(normalized)
        Button {
            store.toggleIssueType(issueType)
        } label: {
            filterChip(
                label: issueType.capitalized,
                isActive: isActive,
                accent: WorkstationTheme.accent
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func assigneeChip(_ assignee: IssueFilterAssignee) -> some View {
        let isActive = store.filterState.assignees.contains(assignee)
        Button {
            store.toggleAssignee(assignee)
        } label: {
            filterChip(
                label: assignee.displayName,
                isActive: isActive,
                accent: assigneeAccent(assignee)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func labelChip(_ label: String) -> some View {
        let isActive = store.filterState.labels.contains(label.lowercased())
        Button {
            store.toggleLabel(label)
        } label: {
            filterChip(
                label: label,
                isActive: isActive,
                accent: WorkstationTheme.accent
            )
        }
        .buttonStyle(.plain)
    }

    private func filterChip(label: String, isActive: Bool, accent: Color) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
            .foregroundStyle(isActive ? WorkstationTheme.background : WorkstationTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .fill(isActive ? accent : WorkstationTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(isActive ? accent : WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func assigneeAccent(_ assignee: IssueFilterAssignee) -> Color {
        switch assignee {
        case .claude:
            return WorkstationTheme.accent
        case .codex:
            return WorkstationTheme.blue
        case .other:
            return WorkstationTheme.purple
        case .me:
            return WorkstationTheme.green
        }
    }
}
