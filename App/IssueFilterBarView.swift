import SwiftUI

struct IssueFilterBarView: View {
    let store: IssueStore
    let onClearAll: () -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 12, weight: .semibold))

                Text("Filter")
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))

                if store.activeFilterCount > 0 {
                    Text("\(store.activeFilterCount)")
                        .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                        .foregroundStyle(WorkstationTheme.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(WorkstationTheme.accent)
                        )
                }
            }
            .foregroundStyle(store.hasActiveFilters ? WorkstationTheme.textPrimary : WorkstationTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(store.hasActiveFilters ? WorkstationTheme.card : WorkstationTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(store.hasActiveFilters ? WorkstationTheme.accent : WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            filterPopover
                .frame(width: 430)
                .background(WorkstationTheme.surface)
        }
    }

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filtering")
                        .font(WorkstationTheme.Fonts.display(18, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)

                    Text("Pick any mix of priorities, types, assignees, and labels.")
                        .font(WorkstationTheme.Fonts.body(12, weight: .regular))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if store.hasActiveFilters {
                    Button("Clear all", action: onClearAll)
                        .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                }
            }

            Divider()
                .overlay(WorkstationTheme.borderSoft)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    filterSection(
                        title: "Recurring",
                        chips: [recurringOnlyChip()]
                    )

                    filterSection(
                        title: "Priority",
                        chips: store.availablePriorities.map { priorityChip($0) }
                    )

                    filterSection(
                        title: "Type",
                        chips: store.availableIssueTypes.map { issueTypeChip($0) }
                    )

                    filterSection(
                        title: "Assignee",
                        chips: store.availableAssigneeKinds.map { assigneeChip($0) }
                    )

                    if !store.availableLabels.isEmpty {
                        filterSection(
                            title: "Label",
                            chips: store.availableLabels.map { labelChip($0) }
                        )
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(16)
    }

    private func filterSection(title: String, chips: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textMuted)
                .tracking(0.8)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 80), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    chip
                }
            }
        }
    }

    private func recurringOnlyChip() -> AnyView {
        let isActive = store.filterState.recurringOnly
        return AnyView(
            Button {
                store.toggleRecurringOnly()
            } label: {
                filterChip(
                    label: "Recurring only",
                    isActive: isActive,
                    accent: WorkstationTheme.purple
                )
            }
            .buttonStyle(.plain)
        )
    }

    private func priorityChip(_ priority: Int) -> AnyView {
        let isActive = store.filterState.priorities.contains(priority)
        return AnyView(
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
        )
    }

    private func issueTypeChip(_ issueType: String) -> AnyView {
        let normalized = issueType.lowercased()
        let isActive = store.filterState.issueTypes.contains(normalized)
        return AnyView(
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
        )
    }

    private func assigneeChip(_ assignee: IssueFilterAssignee) -> AnyView {
        let isActive = store.filterState.assignees.contains(assignee)
        return AnyView(
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
        )
    }

    private func labelChip(_ label: String) -> AnyView {
        let isActive = store.filterState.labels.contains(label.lowercased())
        return AnyView(
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
        )
    }

    private func filterChip(label: String, isActive: Bool, accent: Color) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
            .foregroundStyle(isActive ? WorkstationTheme.background : WorkstationTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .center)
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
