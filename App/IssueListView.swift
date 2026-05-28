import SwiftUI

struct IssueListView: View {
    let appVM: AppViewModel
    let store: IssueStore
    let profiles: [AgentProfile]

    @State private var collapsedColumns: Set<KanbanColumn> = []

    var body: some View {
        VStack(spacing: 0) {
            listInfoBar
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(KanbanColumn.allCases) { column in
                        let items = store.issues(in: column)
                        if !items.isEmpty || !collapsedColumns.contains(column) {
                            ListSectionView(
                                column: column,
                                issues: items,
                                appVM: appVM,
                                store: store,
                                profiles: profiles,
                                isCollapsed: collapsedColumns.contains(column),
                                onToggleCollapse: {
                                    withAnimation(.easeOut(duration: 0.22)) {
                                        if collapsedColumns.contains(column) {
                                            collapsedColumns.remove(column)
                                        } else {
                                            collapsedColumns.insert(column)
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkstationTheme.background)
    }

    // MARK: - Info Bar

    private var listInfoBar: some View {
        HStack(spacing: 12) {
            let total = store.filteredIssues.count
            let completed = store.issues(in: .done).count

            Text("\(total) tasks")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)

            if completed > 0 {
                Text("·")
                    .foregroundStyle(WorkstationTheme.textDisabled)
                Text("\(completed) completed")
                    .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }

            Spacer()

            Text("Group by: Status")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(WorkstationTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }
}

// MARK: - Section View

private struct ListSectionView: View {
    let column: KanbanColumn
    let issues: [BeadIssue]
    let appVM: AppViewModel
    let store: IssueStore
    let profiles: [AgentProfile]
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleCollapse)

            if !isCollapsed {
                if issues.isEmpty {
                    emptyState
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                } else {
                    ForEach(issues) { issue in
                        IssueListRowView(
                            issue: issue,
                            appVM: appVM,
                            store: store,
                            profiles: profiles,
                                columnColor: WorkstationTheme.accent(for: column)
                            )
                    }
                }

                addTaskButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(WorkstationTheme.textDisabled)
                .frame(width: 12)

            Circle()
                .fill(WorkstationTheme.accent(for: column))
                .frame(width: 8, height: 8)

            Text(column.rawValue.uppercased())
                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(WorkstationTheme.textPrimary)

            Text("\(issues.count)")
                .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                .foregroundStyle(WorkstationTheme.textMuted)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(WorkstationTheme.borderSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))

            if !issues.isEmpty {
                sectionProgressBar
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(WorkstationTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(column.rawValue), \(issues.count) issues")
        .accessibilityAddTraits(.isHeader)
    }

    private var sectionProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WorkstationTheme.border)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [WorkstationTheme.accent, WorkstationTheme.accentHover],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, proxy.size.width * sectionProgress))
                    .animation(.spring(response: 0.60, dampingFraction: 0.90), value: sectionProgress)
            }
        }
        .frame(width: 80, height: 3)
    }

    private var sectionProgress: Double {
        guard !issues.isEmpty else { return 0 }
        if column == .done { return 1.0 }
        return 0
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WorkstationTheme.accent(for: column))
            Text("No issues yet")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(WorkstationTheme.borderStrong)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .accessibilityLabel("No issues in \(column.rawValue)")
    }

    // MARK: - Add Task Button

    private var addTaskButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
            Text("Add task to \(column.rawValue)")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
        }
        .foregroundStyle(WorkstationTheme.textDisabled)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

// MARK: - Issue Row

private struct IssueListRowView: View {
    let issue: BeadIssue
    let appVM: AppViewModel
    let store: IssueStore
    let profiles: [AgentProfile]
    let columnColor: Color

    @State private var isHovering = false

    private var isSelected: Bool {
        store.selectedIssue?.id == issue.id
    }

    private var hasUnknownStatus: Bool {
        store.hasUnknownStatus(issue)
    }

    private var isBlocked: Bool {
        store.blockedByDependencyIDs.contains(issue.id)
    }

    /// True while a pending or in-flight agent run exists for this issue.
    private var isAgentRunning: Bool {
        if appVM.pendingAgentLaunch?.issue.id    == issue.id { return true }
        if appVM.pendingWorktreeLaunch?.issue.id == issue.id { return true }
        guard let record = appVM.agentRunHistoryStore.latestRecord(forIssueID: issue.id)
        else { return false }
        return !record.status.isFinalized
    }

    var body: some View {
        Button {
            store.selectIssue(id: issue.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // Status dot — swaps to animated spinner while agent runs
                if isAgentRunning {
                    AgentRunSpinnerView(size: 12)
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(columnColor)
                        .frame(width: 6, height: 6)
                }

                // Title + ID
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(issue.title)
                            .font(WorkstationTheme.Fonts.display(13, weight: .bold))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(issue.id)
                            .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.textDisabled)
                    }
                    
                    if let desc = issue.description, !desc.isEmpty {
                        Text(desc)
                            .font(WorkstationTheme.Fonts.body(11))
                            .foregroundStyle(WorkstationTheme.textMuted)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 16)

                // Row metadata / badges
                HStack(spacing: 12) {
                    // Priority tag
                    if let priority = issue.priority,
                       let difficulty = PriorityDifficulty.from(priority: priority) {
                        priorityBadge(difficulty.displayName, priority: priority)
                    }

                    // Type badge
                    if let type = issue.issueType, !type.isEmpty {
                        typeBadge(type)
                    }

                    // Blocked badge
                    if isBlocked {
                        blockedBadge
                    }

                    // Unknown status badge
                    if hasUnknownStatus, let status = issue.status {
                        unknownStatusBadge(status)
                    }

                    // Thin progress bar for Active statuses
                    if issue.status == "in_progress" || issue.status == "review" {
                        thinProgressBar(for: issue.status)
                    }

                    // Assignee avatar
                    if issue.assignee?.isEmpty == false {
                        AssigneeBadgeView(assignee: issue.assignee, profiles: profiles, compact: true, showName: false)
                    }

                    // Calendar date
                    if let updated = issue.updatedAt, !updated.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9.5, weight: .medium))
                            Text(shortDate(updated))
                                .font(WorkstationTheme.Fonts.body(9.5, weight: .medium))
                        }
                        .foregroundStyle(WorkstationTheme.textDisabled)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WorkstationTheme.borderSoft)
                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                    }

                    // Ready indicator
                    if store.readyIssueIDs.contains(issue.id) {
                        Circle()
                            .fill(WorkstationTheme.green)
                            .frame(width: 6, height: 6)
                            .help("Ready to work")
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? WorkstationTheme.active
                    : (isHovering ? WorkstationTheme.hover : Color.clear)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(WorkstationTheme.accentBorder, lineWidth: 1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(WorkstationTheme.borderSoft)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .issueContextMenu(issue: issue, store: store, appVM: appVM)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Issue \(issue.id), \(issue.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Row Helpers

    private func priorityBadge(_ label: String, priority: Int) -> some View {
        let color = WorkstationTheme.difficultyColor(priority)
        return BadgeView(style: .priority(priority)) {
            HStack(spacing: 3) {
                if priority <= 1 {
                    Circle()
                        .fill(color)
                        .frame(width: 4.5, height: 4.5)
                }
                Text(label)
            }
            .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
            .lineLimit(1)
        }
    }

    private func typeBadge(_ label: String) -> some View {
        BadgeView(style: .info) {
            Text(label)
                .font(WorkstationTheme.Fonts.body(9.5, weight: .semibold))
                .lineLimit(1)
        }
    }

    private var blockedBadge: some View {
        ViewThatFits(in: .horizontal) {
            blockedBadgeLabel(text: "Blocked", iconSize: 9, spacing: 4)
            blockedBadgeLabel(text: "Block", iconSize: 8.5, spacing: 3)
            BadgeView(style: .blocked, horizontalPadding: 5, verticalPadding: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8.5, weight: .bold))
            }
        }
        .help("This issue has open blockers")
    }

    private func blockedBadgeLabel(text: String, iconSize: CGFloat, spacing: CGFloat) -> some View {
        BadgeView(style: .blocked, horizontalPadding: 6, verticalPadding: 2) {
            HStack(spacing: spacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: iconSize, weight: .bold))
                Text(text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
        }
    }

    private func unknownStatusBadge(_ status: String) -> some View {
        BadgeView(style: .warning) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .semibold))
                Text("status: \(status)")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(WorkstationTheme.Fonts.body(9.5, weight: .semibold))
        }
    }

    private func thinProgressBar(for status: String?) -> some View {
        let progress: Double = status == "review" ? 0.8 : 0.4
        
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(WorkstationTheme.border)
                .frame(width: 36, height: 3)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [WorkstationTheme.accent, WorkstationTheme.accentHover],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 36 * progress, height: 3)
        }
    }

    private func shortDate(_ raw: String) -> String {
        raw.split(separator: "T").first.map(String.init) ?? raw
    }
}
