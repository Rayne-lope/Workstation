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
            WorkspaceTeamView(store: store, profiles: appVM.agentProfileStore.profiles)
        case .activity:
            WorkspaceActivityView(appVM: appVM, store: store, profiles: appVM.agentProfileStore.profiles)
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
                    statCard(
                        label: "Total Issues",
                        count: store.issues.count,
                        sublabel: "Across all workflow columns",
                        color: WorkstationTheme.textSecondary
                    )
                    statCard(
                        label: "In Progress",
                        count: store.issues.filter { $0.status == "in_progress" }.count,
                        sublabel: "Active work happening now",
                        color: WorkstationTheme.accent
                    )
                    statCard(
                        label: "Blocked",
                        count: store.blockedIssues.count,
                        sublabel: "Awaiting blocker resolution",
                        color: WorkstationTheme.orange
                    )
                    statCard(
                        label: "Done",
                        count: store.doneIssues.count,
                        sublabel: "Successfully completed tasks",
                        color: WorkstationTheme.green
                    )
                }

                // Progress breakdown card
                progressBreakdownCard
            }
            .padding(24)
        }
        .background(WorkstationTheme.background)
    }

    private func statCard(label: String, count: Int, sublabel: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(count)")
                .font(WorkstationTheme.Fonts.display(32, weight: .heavy))
                .foregroundStyle(color)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(WorkstationTheme.Fonts.body(13, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                
                Text(sublabel)
                    .font(WorkstationTheme.Fonts.body(10, weight: .regular))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
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
        let totalCount = store.issues.count
        let doneCount = store.doneIssues.count
        let doneRate = totalCount > 0 ? (Double(doneCount) / Double(totalCount)) : 0.0
        let safeRate = doneRate.isNaN || doneRate.isInfinite ? 0.0 : max(0.0, min(1.0, doneRate))

        return HStack(alignment: .top, spacing: 32) {
            progressRingView(doneRate: safeRate)
            
            Divider()
                .overlay(WorkstationTheme.borderSoft)
            
            columnBarChart(total: totalCount)
        }
        .padding(20)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private func progressRingView(doneRate: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle track
                Circle()
                    .stroke(WorkstationTheme.borderSoft, lineWidth: 10)
                    .frame(width: 120, height: 120)
                
                // Progress circle stroke with gold accent
                Circle()
                    .trim(from: 0.0, to: CGFloat(doneRate))
                    .stroke(
                        LinearGradient(
                            colors: [WorkstationTheme.accent, WorkstationTheme.accentHover],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: doneRate)
                
                // Percentage text inside using Display/Syne font
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", doneRate * 100))
                        .font(WorkstationTheme.Fonts.display(24, weight: .heavy))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .monospacedDigit()
                    Text("DONE")
                        .font(WorkstationTheme.Fonts.body(9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
            }
            .frame(width: 120, height: 120)
            
            Text("Workspace Health")
                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
        .frame(width: 160)
    }

    private func columnBarChart(total: Int) -> some View {
        let maxTotal = max(total, 1)
        let columns: [(String, Int, Color)] = [
            ("Backlog",     store.backlogIssues.count,    WorkstationTheme.textMuted),
            ("Ready",       store.readyIssues.count,      WorkstationTheme.accent),
            ("In Progress", store.inProgressIssues.count, WorkstationTheme.accent),
            ("Review",      store.reviewIssues.count,     WorkstationTheme.blue),
            ("Blocked",     store.blockedIssues.count,    WorkstationTheme.orange),
            ("Done",        store.doneIssues.count,       WorkstationTheme.green),
        ]
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Progress Breakdown")
                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                .foregroundStyle(WorkstationTheme.textDisabled)
                .tracking(0.8)
                .textCase(.uppercase)
            
            VStack(spacing: 10) {
                ForEach(columns, id: \.0) { label, count, color in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                        
                        Text(label)
                            .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                            .foregroundStyle(WorkstationTheme.textSecondary)
                            .frame(width: 90, alignment: .leading)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(WorkstationTheme.borderSoft)
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color)
                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxTotal), height: 4)
                                    .animation(.easeOut(duration: 0.3), value: count)
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(count)")
                            .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
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

struct WorkspaceTeamView: View {
    let store: IssueStore
    let profiles: [AgentProfile]

    var body: some View {
        let grouped = Dictionary(grouping: store.issues) { issue in
            issue.assignee?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        
        let sortedAssignees = grouped.keys.sorted { lhs, rhs in
            if lhs.isEmpty { return true }
            if rhs.isEmpty { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if store.issues.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 16)], spacing: 16) {
                        ForEach(sortedAssignees, id: \.self) { assignee in
                            let assigneeIssues = grouped[assignee] ?? []
                            WorkspaceTeamCardView(
                                assignee: assignee.isEmpty ? nil : assignee,
                                issues: assigneeIssues,
                                profiles: profiles
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(WorkstationTheme.background)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(WorkstationTheme.textDisabled)
            VStack(spacing: 6) {
                Text("No team activity")
                    .font(WorkstationTheme.Fonts.display(18, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Assignee statistics will appear once issues are created and claimed.")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .center)
    }
}

struct WorkspaceTeamCardView: View {
    let assignee: String?
    let issues: [BeadIssue]
    let profiles: [AgentProfile]

    @State private var isHovering = false

    var body: some View {
        let resolver = AssigneeAvatarResolver()
        let descriptor = resolver.resolve(assignee: assignee, profiles: profiles)

        let displayName = descriptor?.label ?? (assignee ?? "No assignee")
        let roleName: String = {
            if assignee == nil {
                return "Unassigned"
            }
            if let name = assignee,
               let profile = profiles.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }) {
                return profile.role.displayName
            }
            if let name = assignee, AssigneeAvatarResolver.brandKind(forShortToken: name) != nil {
                return "AI Executor"
            }
            return "Developer"
        }()

        // Stats calculation
        let assignedCount = issues.count
        let doneCount = issues.filter { $0.status == "closed" }.count
        let inProgressCount = issues.filter { $0.status == "in_progress" }.count
        
        let completionRate = assignedCount > 0 ? (Double(doneCount) / Double(assignedCount)) : 0.0
        let safeCompletion = completionRate.isNaN || completionRate.isInfinite ? 0.0 : max(0.0, min(1.0, completionRate))

        VStack(alignment: .leading, spacing: 14) {
            // Header: Avatar + Info (name + role)
            HStack(spacing: 12) {
                if assignee == nil {
                    Circle()
                        .fill(WorkstationTheme.hover)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "person.fill.questionmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(WorkstationTheme.textMuted)
                        )
                } else {
                    AssigneeBadgeView(assignee: assignee, profiles: profiles, compact: false, showName: false)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(WorkstationTheme.Fonts.display(14, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .lineLimit(1)

                    Text(roleName)
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer()
            }

            Divider().overlay(WorkstationTheme.borderSoft)

            // 2x2 grid of mini stats
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                miniStatBlock(label: "Assigned", value: "\(assignedCount)", color: WorkstationTheme.textSecondary)
                miniStatBlock(label: "In Progress", value: "\(inProgressCount)", color: WorkstationTheme.accent)
                miniStatBlock(label: "Done", value: "\(doneCount)", color: WorkstationTheme.green)
                miniStatBlock(label: "Completion", value: String(format: "%.0f%%", safeCompletion * 100), color: WorkstationTheme.blue)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(WorkstationTheme.border)
                            .frame(height: 3)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [WorkstationTheme.accent, WorkstationTheme.accentHover],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(safeCompletion), height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(16)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(isHovering ? WorkstationTheme.borderStrong : WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .offset(y: isHovering ? -2 : 0)
        .shadow(color: isHovering ? Color.black.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
        .animation(.easeOut(duration: 0.18), value: isHovering)
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
    }

    private func miniStatBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(WorkstationTheme.Fonts.display(18, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label.uppercased())
                .font(WorkstationTheme.Fonts.body(9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(WorkstationTheme.textDisabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.cardAlt)
        .cornerRadius(WorkstationTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
    }
}

struct UnifiedActivityItem: Identifiable, Hashable, Sendable {
    enum ActivityType: Hashable, Sendable {
        case shellCommand(CommandSnapshot)
        case agentRun(AgentRunRecord)
    }

    let id: String
    let type: ActivityType
    let timestamp: Date
}

struct WorkspaceActivityView: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore
    let profiles: [AgentProfile]

    var activityItems: [UnifiedActivityItem] {
        let shellSnapshots = appVM.shellRunner.history.map {
            UnifiedActivityItem(
                id: "shell-\($0.timestamp.timeIntervalSince1970)-\($0.command)-\($0.arguments.joined())",
                type: .shellCommand($0),
                timestamp: $0.timestamp
            )
        }

        let agentRecords = appVM.agentRunHistoryStore.records.map {
            UnifiedActivityItem(
                id: "agent-\($0.startedAt.timeIntervalSince1970)-\($0.id)",
                type: .agentRun($0),
                timestamp: $0.startedAt
            )
        }

        return (shellSnapshots + agentRecords).sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let items = activityItems
                if items.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            WorkspaceActivityRowView(item: item, store: store, appVM: appVM, profiles: profiles)
                            
                            if item.id != items.last?.id {
                                Divider()
                                    .overlay(WorkstationTheme.borderSoft)
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .padding(16)
                    .background(WorkstationTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                            .stroke(WorkstationTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
                }
            }
            .padding(24)
        }
        .background(WorkstationTheme.background)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(WorkstationTheme.textDisabled)
            VStack(spacing: 6) {
                Text("No activity yet")
                    .font(WorkstationTheme.Fonts.display(18, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("All shell commands and agent operations will be logged here in real-time.")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .center)
    }
}

struct WorkspaceActivityRowView: View {
    let item: UnifiedActivityItem
    let store: IssueStore
    let appVM: AppViewModel
    let profiles: [AgentProfile]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    headerText
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text(relativeTime(for: item.timestamp))
                            .font(WorkstationTheme.Fonts.body(11))
                            .foregroundStyle(WorkstationTheme.textMuted)
                        
                        statusBadge
                    }
                }

                snippetBox
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.type {
        case .shellCommand(let snapshot):
            let isGit = snapshot.command.lowercased().contains("git")
            let isBd = snapshot.command.lowercased().contains("bd")
            
            Circle()
                .fill(isGit ? WorkstationTheme.purpleBg : (isBd ? WorkstationTheme.accentBg : WorkstationTheme.hover))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: isGit ? "arrow.triangle.pull" : (isBd ? "terminal.fill" : "terminal"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isGit ? WorkstationTheme.purple : (isBd ? WorkstationTheme.accent : WorkstationTheme.textSecondary))
                )
                .overlay(
                    Circle()
                        .stroke(isGit ? WorkstationTheme.purpleBorder : (isBd ? WorkstationTheme.accentBorder : WorkstationTheme.border), lineWidth: 1)
                )

        case .agentRun(let record):
            AssigneeBadgeView(assignee: record.agentName, profiles: profiles, compact: true, showName: false)
                .frame(width: 28, height: 28)
        }
    }

    @ViewBuilder
    private var headerText: some View {
        switch item.type {
        case .shellCommand(let snapshot):
            let cmdString = "\(snapshot.command) \(snapshot.arguments.joined(separator: " "))"
            VStack(alignment: .leading, spacing: 2) {
                Text("Executed Shell Command")
                    .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                
                Text(cmdString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineLimit(1)
            }

        case .agentRun(let record):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Agent Session Launched")
                        .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                    
                    Button {
                        store.selectIssue(id: record.issueID)
                        withAnimation(.easeOut(duration: 0.18)) {
                            appVM.viewMode = .kanban
                        }
                    } label: {
                        Text(record.issueID)
                            .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                            .foregroundStyle(WorkstationTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(WorkstationTheme.accentBg)
                            .cornerRadius(WorkstationTheme.Radius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                                    .stroke(WorkstationTheme.accentBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Go to \(record.issueID) on Kanban board")
                }
                
                Text(record.issueTitle)
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.type {
        case .shellCommand(let snapshot):
            let success = snapshot.exitCode == 0
            Text(success ? "\(snapshot.durationMs)ms" : "Exit \(snapshot.exitCode)")
                .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                .foregroundStyle(success ? WorkstationTheme.green : WorkstationTheme.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(success ? WorkstationTheme.greenBg : WorkstationTheme.redBg)
                .cornerRadius(WorkstationTheme.Radius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                        .stroke(success ? WorkstationTheme.greenBorder : WorkstationTheme.redBorder, lineWidth: 1)
                )

        case .agentRun(let record):
            let status = record.status
            let color = statusColor(status)
            let bgColor = statusBgColor(status)
            let borderColor = statusBorderColor(status)
            
            Text(status.displayName)
                .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bgColor)
                .cornerRadius(WorkstationTheme.Radius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var snippetBox: some View {
        switch item.type {
        case .shellCommand(let snapshot):
            let outputText = !snapshot.stderr.isEmpty ? snapshot.stderr : snapshot.stdout
            let displayString = snapshot.errorMessage ?? outputText
            
            if !displayString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading) {
                    Text(displayString.prefix(400))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(snapshot.exitCode == 0 ? WorkstationTheme.textSecondary : WorkstationTheme.red)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(WorkstationTheme.cardAlt)
                .cornerRadius(WorkstationTheme.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium)
                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                )
            }

        case .agentRun(let record):
            let displayString = record.notes ?? record.prompt
            
            if !displayString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading) {
                    Text(displayString.prefix(400))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(WorkstationTheme.cardAlt)
                .cornerRadius(WorkstationTheme.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium)
                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                )
            }
        }
    }

    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func statusColor(_ status: AgentRunStatus) -> Color {
        switch status {
        case .accepted: return WorkstationTheme.green
        case .failed: return WorkstationTheme.red
        case .needsReview: return WorkstationTheme.blue
        case .abandoned: return WorkstationTheme.textMuted
        default: return WorkstationTheme.accent
        }
    }

    private func statusBgColor(_ status: AgentRunStatus) -> Color {
        switch status {
        case .accepted: return WorkstationTheme.greenBg
        case .failed: return WorkstationTheme.redBg
        case .needsReview: return WorkstationTheme.blueBg
        case .abandoned: return WorkstationTheme.hover
        default: return WorkstationTheme.accentBg
        }
    }

    private func statusBorderColor(_ status: AgentRunStatus) -> Color {
        switch status {
        case .accepted: return WorkstationTheme.greenBorder
        case .failed: return WorkstationTheme.redBorder
        case .needsReview: return WorkstationTheme.blueBorder
        case .abandoned: return WorkstationTheme.borderStrong
        default: return WorkstationTheme.accentBorder
        }
    }
}
