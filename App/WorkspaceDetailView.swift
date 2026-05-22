import SwiftUI

// MARK: - Tab Enum

enum WorkspaceDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case issues = "Issues"
    case team = "Team"
    case activity = "Activity"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: return "chart.bar.xaxis"
        case .issues: return "list.bullet.rectangle"
        case .team: return "person.2"
        case .activity: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Main View

/// Container view for the Workspace Detail section. Provides header, tab bar, and
/// swappable tab body. Downstream issues (Workstation-964, -3se, -0pf, -6ky, -795)
/// will fill in the actual tab content.
struct WorkspaceDetailView: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore

    @State private var selectedTab: WorkspaceDetailTab = .overview

    private var workspace: ProjectWorkspace? { appVM.activeWorkspace }

    // MARK: – body

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            tabBar
            Divider().overlay(WorkstationTheme.borderSoft)
            tabBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkstationTheme.background)
    }

    // MARK: – Header

    private var detailHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                // Breadcrumb
                HStack(spacing: 4) {
                    Text("Beads")
                        .font(WorkstationTheme.Fonts.label)
                        .foregroundStyle(WorkstationTheme.textDisabled)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textDisabled)
                    Text(workspace?.name ?? "Workspace")
                        .font(WorkstationTheme.Fonts.label)
                        .foregroundStyle(WorkstationTheme.textDisabled)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }

                // Title + health badge
                HStack(spacing: 10) {
                    Text(workspace?.name ?? "Workspace")
                        .font(WorkstationTheme.Fonts.display(26, weight: .heavy))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .lineLimit(1)

                    healthBadge
                }
            }

            Spacer()

            actionButtons
        }
        .padding(.top, 16)
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .background(WorkstationTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var healthBadge: some View {
        let total = store.issues.count
        let blocked = store.blockedIssues.count
        let isHealthy = blocked == 0 && total > 0

        HStack(spacing: 5) {
            Circle()
                .fill(isHealthy ? WorkstationTheme.green : (blocked > 0 ? WorkstationTheme.orange : WorkstationTheme.textMuted))
                .frame(width: 7, height: 7)

            Text(isHealthy ? "Healthy" : (total == 0 ? "Empty" : "\(blocked) Blocked"))
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(isHealthy ? WorkstationTheme.green : (blocked > 0 ? WorkstationTheme.orange : WorkstationTheme.textMuted))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .fill(isHealthy ? WorkstationTheme.greenBg : (blocked > 0 ? WorkstationTheme.orangeBg : WorkstationTheme.card))
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(isHealthy ? WorkstationTheme.greenBorder : (blocked > 0 ? WorkstationTheme.orangeBorder : WorkstationTheme.border), lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(WorkstationTheme.accent)
            }

            if let workspace {
                Button {
                    appVM.openTerminal(at: workspace.inspectionURL)
                } label: {
                    Label("Terminal", systemImage: "terminal")
                }
                .buttonStyle(WorkstationGhostButtonStyle())
                .help("Open workspace in Terminal")
            }

            Button {
                appVM.reloadIssues()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .buttonStyle(WorkstationGhostButtonStyle())
            .disabled(store.isLoading)
            .help("Reload issues")
        }
    }

    // MARK: – Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(WorkspaceDetailTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .frame(height: 44)
        .background(WorkstationTheme.surface)
    }

    private func tabButton(_ tab: WorkspaceDetailTab) -> some View {
        let isActive = selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                Text(tab.rawValue)
                    .font(WorkstationTheme.Fonts.display(14, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? WorkstationTheme.textPrimary : WorkstationTheme.textDisabled)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? WorkstationTheme.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: – Tab Body

    @ViewBuilder
    private var tabBody: some View {
        switch selectedTab {
        case .overview:
            WorkspaceOverviewPlaceholder(store: store)
        case .issues:
            WorkspaceIssuesView(appVM: appVM, store: store)
        case .team:
            WorkspaceTeamPlaceholder(store: store)
        case .activity:
            WorkspaceActivityPlaceholder(store: store)
        }
    }
}

// MARK: - Placeholder Tab Bodies
// These stubs will be replaced by the dependent issues:
// - Overview stats (Workstation-964) + about (Workstation-3se)
// - Issues grouped list (Workstation-0pf)
// - Team breakdown (Workstation-6ky)
// - Activity feed (Workstation-795)

private struct WorkspaceOverviewPlaceholder: View {
    let store: IssueStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Stat cards quick summary
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    statCard(label: "Total", count: store.issues.count, color: WorkstationTheme.textSecondary)
                    statCard(label: "In Progress", count: store.inProgressIssues.count, color: WorkstationTheme.accent)
                    statCard(label: "Blocked", count: store.blockedIssues.count, color: WorkstationTheme.orange)
                    statCard(label: "Done", count: store.doneIssues.count, color: WorkstationTheme.green)
                }

                // Progress breakdown
                progressBreakdownCard
            }
            .padding(24)
        }
        .background(WorkstationTheme.background)
    }

    private func statCard(label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(count)")
                .font(WorkstationTheme.Fonts.display(32, weight: .heavy))
                .foregroundStyle(color)
                .monospacedDigit()

            Text(label)
                .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private var progressBreakdownCard: some View {
        let total = max(store.issues.count, 1)
        let columns: [(String, Int, Color)] = [
            ("Backlog",     store.backlogIssues.count,    WorkstationTheme.textMuted),
            ("Ready",       store.readyIssues.count,      WorkstationTheme.accent),
            ("In Progress", store.inProgressIssues.count, WorkstationTheme.accent),
            ("Review",      store.reviewIssues.count,     WorkstationTheme.blue),
            ("Blocked",     store.blockedIssues.count,    WorkstationTheme.orange),
            ("Done",        store.doneIssues.count,       WorkstationTheme.green),
        ]

        return VStack(alignment: .leading, spacing: 14) {
            Text("PROGRESS BREAKDOWN")
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(columns, id: \.0) { label, count, color in
                HStack(spacing: 10) {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)

                    Text(label)
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .frame(width: 90, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(WorkstationTheme.borderStrong)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(
                                    width: geo.size.width * CGFloat(count) / CGFloat(total),
                                    height: 4
                                )
                                .animation(.easeOut(duration: 0.5), value: count)
                        }
                    }
                    .frame(height: 4)

                    Text("\(count)")
                        .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding(18)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }
}

struct WorkspaceIssuesView: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore

    private var profiles: [AgentProfile] {
        appVM.agentProfileStore.profiles
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                let columnsWithIssues = KanbanColumn.allCases.filter { column in
                    !store.issues(in: column).isEmpty
                }

                if columnsWithIssues.isEmpty {
                    emptyState
                } else {
                    ForEach(columnsWithIssues) { column in
                        let columnIssues = store.issues(in: column)
                        issuesSection(column: column, issues: columnIssues)
                    }
                }
            }
            .padding(24)
        }
        .background(WorkstationTheme.background)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(WorkstationTheme.textDisabled)
            VStack(spacing: 6) {
                Text("No issues in this workspace")
                    .font(WorkstationTheme.Fonts.display(18, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Get started by creating your first issue.")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .center)
    }

    // MARK: - Section View
    private func issuesSection(column: KanbanColumn, issues: [BeadIssue]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: dot warna + label + count badge
            HStack(spacing: 8) {
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

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)

            // Issues list under the header
            VStack(spacing: 0) {
                ForEach(issues) { issue in
                    WorkspaceIssueRowView(
                        issue: issue,
                        column: column,
                        profiles: profiles,
                        onSelect: {
                            store.selectIssue(id: issue.id)
                            withAnimation(.easeOut(duration: 0.18)) {
                                appVM.viewMode = .kanban
                            }
                        }
                    )
                    
                    if issue.id != issues.last?.id {
                        Divider()
                            .overlay(WorkstationTheme.borderSoft)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        }
    }
}

struct WorkspaceIssueRowView: View {
    let issue: BeadIssue
    let column: KanbanColumn
    let profiles: [AgentProfile]
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
                // Status dot
                Circle()
                    .fill(WorkstationTheme.accent(for: column))
                    .frame(width: 6, height: 6)

                // Title (Syne bold/semibold) + ID
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

                    // Thin progress bar for Active statuses
                    if issue.status == "in_progress" || issue.status == "review" {
                        thinProgressBar(for: issue.status)
                    }

                    // Assignee avatar (showName: false makes it only render the glyph/avatar)
                    if issue.assignee?.isEmpty == false {
                        AssigneeBadgeView(assignee: issue.assignee, profiles: profiles, compact: true, showName: false)
                    }

                    // Due/updated date
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isHovering ? WorkstationTheme.hover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.easeOut(duration: 0.1), value: isHovering)
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

private struct WorkspaceTeamPlaceholder: View {
    let store: IssueStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(WorkstationTheme.textDisabled)
            VStack(spacing: 6) {
                Text("Team Tab")
                    .font(WorkstationTheme.Fonts.display(20, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Assignee breakdown cards — coming in Workstation-6ky")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkstationTheme.background)
    }
}

private struct WorkspaceActivityPlaceholder: View {
    let store: IssueStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(WorkstationTheme.textDisabled)
            VStack(spacing: 6) {
                Text("Activity Tab")
                    .font(WorkstationTheme.Fonts.display(20, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Shell command & bd operation feed — coming in Workstation-795")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkstationTheme.background)
    }
}
