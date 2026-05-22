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
            WorkspaceIssuesPlaceholder(store: store)
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

private struct WorkspaceIssuesPlaceholder: View {
    let store: IssueStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(WorkstationTheme.textDisabled)
            VStack(spacing: 6) {
                Text("Issues Tab")
                    .font(WorkstationTheme.Fonts.display(20, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Grouped by status — coming in Workstation-0pf")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkstationTheme.background)
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
