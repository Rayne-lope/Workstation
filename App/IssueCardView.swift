import SwiftUI

struct IssueCardView: View {
    let issue: BeadIssue
    let appVM: AppViewModel
    let profiles: [AgentProfile]
    let isSelected: Bool
    let hasUnknownStatus: Bool
    var isBlockedByDependency: Bool = false
    var isCompact: Bool = false

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isSelected {
                LinearGradient(
                    colors: [WorkstationTheme.accent, WorkstationTheme.accentHover],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 2)
                .padding(.horizontal, -16)
                .padding(.top, -14)
                .padding(.bottom, 12)
            }

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(issue.id)
                            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                            .foregroundStyle(WorkstationTheme.textDisabled)
                            .monospaced()
                        
                        if let priority = issue.priority {
                            Circle()
                                .fill(WorkstationTheme.difficultyColor(priority))
                                .frame(width: 5, height: 5)
                        }
                        
                        if let type = issue.issueType, !type.isEmpty {
                            typeBadge(type)
                        }
                    }
                    
                    Text(issue.title)
                        .font(WorkstationTheme.Fonts.display(13, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .lineLimit(isCompact ? 2 : 3)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer(minLength: 8)
                
                HStack(spacing: 4) {
                    if issue.status == "in_progress" {
                        AgentRunSpinnerView(size: 14)
                    }
                    
                    if let store = appVM.issueStore {
                        Menu {
                            IssueActionsContextMenu(issue: issue, store: store, appVM: appVM)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(WorkstationTheme.textMuted)
                                .frame(width: 20, height: 20)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                }
            }

            if !isCompact, let description = issue.description, !description.isEmpty {
                markdownPreview(description)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .lineLimit(2)
                    .lineSpacing(4)
                    .padding(.top, 8)
            }

            if hasUnknownStatus, let status = issue.status {
                unknownStatusBadge(status)
                    .padding(.top, isCompact ? 6 : 10)
            }

            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
                .padding(.top, 12)
                .padding(.bottom, 10)

            footer
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.vertical, isCompact ? 10 : 14)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(isSelected ? WorkstationTheme.accent : (isHovering ? WorkstationTheme.borderStrong : WorkstationTheme.border), lineWidth: isSelected ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .shadow(
            color: isSelected ? WorkstationTheme.accent.opacity(0.08) : (isHovering ? WorkstationTheme.textPrimary.opacity(0.10) : .clear),
            radius: isSelected || isHovering ? 16 : 0,
            x: 0,
            y: 8
        )
        .offset(y: isHovering ? -2 : 0)
        .contentShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Issue \(issue.id), \(issue.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isHovering)
        .animation(.spring(response: 0.30, dampingFraction: 0.6), value: isSelected)
    }

    // MARK: - Tag Row (Option C)
    // ID: plain muted text · Priority: colored dot · Type: one badge pill
    // Recurring / focus / blocked: icon-only with .help tooltips

    private var tagRow: some View {
        HStack(spacing: 6) {
            // ID — muted mono text, no pill wrapper
            Text(issue.id)
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textDisabled)
                .lineLimit(1)
                .truncationMode(.middle)

            // Priority — small colored dot, tooltip shows label
            if let priority = issue.priority {
                Circle()
                    .fill(WorkstationTheme.difficultyColor(priority))
                    .frame(width: 5, height: 5)
                    .help(priorityLabel(priority))
            }

            // Type — single badge pill (unchanged)
            if let type = issue.issueType, !type.isEmpty {
                typeBadge(type)
            }

            // Blocked — warning triangle icon only
            if isBlockedByDependency {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WorkstationTheme.orange)
                    .help("This issue has open blockers")
            }

            // Recurring — loop icon only (orange if overdue)
            if let recurringMeta = appVM.recurringMetadata(for: issue.id), recurringMeta.isRecurring {
                let overdue = recurringMeta.overdueDays(now: Date())
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(overdue > 0 ? WorkstationTheme.orange : WorkstationTheme.textMuted)
                    .help(recurringHelp(for: recurringMeta, overdue: overdue))
            }

            // Focus — eye icon only
            if appVM.activeFocusIssueID == issue.id {
                Image(systemName: "eye.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WorkstationTheme.accent)
                    .help("Currently in focus mode")
            }

            // Epic progress — compact badge kept (carries numeric context)
            if issue.issueType?.lowercased() == "epic", let progress = appVM.epicProgress(for: issue.id) {
                epicProgressBadge(done: progress.done, total: progress.total)
            }

            // Child of epic — compact badge kept (hierarchy context)
            if let parentID = issue.parentID, let title = appVM.epicTitle(for: parentID) {
                childOfBadge(epicTitle: title)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private func priorityLabel(_ priority: Int) -> String {
        switch priority {
        case 0: return "P0 Must"
        case 1: return "P1 Important"
        case 2: return "P2 High"
        case 3: return "P3 Medium"
        default: return "P4 Backlog"
        }
    }

    private func recurringHelp(for metadata: RecurringMetadata, overdue: Int) -> String {
        var parts: [String] = ["Recurring task"]
        if metadata.completionCount > 0 {
            parts.append("completed \(metadata.completionCount)x")
        }
        if let cadence = metadata.cadenceDays {
            parts.append("cadence \(cadence)d")
        }
        if overdue > 0 {
            parts.append("overdue \(overdue)d")
        }
        return parts.joined(separator: " · ")
    }

    private func epicProgressBadge(done: Int, total: Int) -> some View {
        BadgeView(style: .epic, horizontalPadding: 6, verticalPadding: 2) {
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(total == 0 ? "Epic" : "\(done)/\(total)")
            }
            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
            .lineLimit(1)
        }
        .help(total == 0 ? "Epic — no children yet" : "Epic: \(done) of \(total) done")
    }

    private func childOfBadge(epicTitle: String) -> some View {
        BadgeView(style: .childOf, horizontalPadding: 6, verticalPadding: 2) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.square.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(epicTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 72)
            }
            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
        }
        .help("Part of Epic: \(epicTitle)")
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 8) {
            if let created = issue.createdAt, !created.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "pin")
                        .font(.system(size: 10))
                    Text("Created: \(shortDate(created))")
                }
                .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                .foregroundStyle(Color(hex: "FB7185")) // Pinkish color for created as in the screenshot
            } else if let updated = issue.updatedAt, !updated.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("Due: \(shortDate(updated))")
                }
                .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                .foregroundStyle(WorkstationTheme.blue) // Blue color for due/updated
            }

            Spacer(minLength: 4)

            if issue.assignee?.isEmpty == false {
                AssigneeBadgeView(assignee: issue.assignee, profiles: profiles, compact: true)
            } else {
                Text("Unassigned")
                    .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textDisabled)
            }
        }
    }

    private func typeBadge(_ label: String) -> some View {
        BadgeView(style: .info) {
            Text(label)
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .lineLimit(1)
        }
    }

    private func unknownStatusBadge(_ status: String) -> some View {
        BadgeView(style: .warning, verticalPadding: 4) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .semibold))
                Text("status: \(status)")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
        }
    }

    private func shortDate(_ raw: String) -> String {
        raw.split(separator: "T").first.map(String.init) ?? raw
    }

    @ViewBuilder
    private func markdownPreview(_ body: String) -> some View {
        if let rendered = MarkdownTextRenderer.attributedString(from: body, mode: .preview) {
            Text(rendered)
        } else {
            Text(body)
        }
    }
}

extension View {
    func issueContextMenu(
        issue: BeadIssue,
        store: IssueStore,
        appVM: AppViewModel
    ) -> some View {
        contextMenu {
            IssueActionsContextMenu(
                issue: issue,
                store: store,
                appVM: appVM
            )
        }
    }
}

private struct IssueActionsContextMenu: View {
    let issue: BeadIssue
    let store: IssueStore
    let appVM: AppViewModel

    private var status: String {
        issue.status ?? "open"
    }

    private var canEditLifecycle: Bool {
        status != "closed"
    }

    var body: some View {
        if status == "open" {
            Button("Claim") {
                Task { await store.claim(id: issue.id) }
            }
        }

        if status == "in_progress" {
            Button("Flag for Review") {
                Task { await store.requestHumanReview(id: issue.id) }
            }
        }

        if canEditLifecycle {
            Button("Close...") {
                appVM.presentCloseSheet(for: issue)
            }
        }

        Divider()

        Button("Copy Prompt") {
            appVM.copyPrompt(for: issue)
        }

        Button("Copy Agent Command") {
            appVM.copyAgentCommand(for: issue)
        }

        if canEditLifecycle {
            Button("Add Blocker...") {
                appVM.presentBlockerPicker(
                    for: issue.id,
                    existingBlockerIDs: Set(store.blockersMap[issue.id] ?? [])
                )
            }
        }

        Divider()

        Menu("Change Priority") {
            ForEach([(0, "P0 Must"), (1, "P1 Important"), (2, "P2 High"), (3, "P3 Medium"), (4, "P4 Backlog")], id: \.0) { priority, label in
                Button(label) {
                    Task {
                        await store.update(id: issue.id, UpdateIssueInput(priority: priority))
                    }
                }
            }
        }

        Menu("Assign…") {
            ForEach(appVM.agentProfileStore.profiles.filter { $0.role == .codingExecutor && $0.canExecuteCode }, id: \.id) { profile in
                Button("\(profile.name) (assign + launch)") {
                    appVM.assignAndLaunchIfExecutor(for: issue, assignee: profile.claimAssigneeToken)
                }
            }
            Divider()
            Button("Me") {
                Task {
                    await store.update(id: issue.id, UpdateIssueInput(assignee: "me"))
                }
            }
            Button("Clear") {
                Task {
                    await store.update(id: issue.id, UpdateIssueInput(assignee: ""))
                }
            }
        }

        Divider()

        let isFocused = appVM.activeFocusIssueID == issue.id
        Button(isFocused ? "End Focus" : "Focus") {
            appVM.focusToggle(for: issue.id)
        }
    }
}
