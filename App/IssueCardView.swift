import SwiftUI

struct IssueCardView: View {
    let issue: BeadIssue
    let appVM: AppViewModel
    let profiles: [AgentProfile]
    let isSelected: Bool
    let hasUnknownStatus: Bool
    var isBlockedByDependency: Bool = false

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

            tagRow
                .padding(.bottom, 10)

            Text(issue.title)
                .font(WorkstationTheme.Fonts.display(13, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .lineLimit(3)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            if let description = issue.description, !description.isEmpty {
                markdownPreview(description)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .lineLimit(2)
                    .lineSpacing(4)
                    .padding(.top, 6)
            }

            if hasUnknownStatus, let status = issue.status {
                unknownStatusBadge(status)
                    .padding(.top, 10)
            }

            footer
                .padding(.top, 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(isSelected ? WorkstationTheme.accent : (isHovering ? WorkstationTheme.borderStrong : WorkstationTheme.border), lineWidth: isSelected ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .shadow(
            color: isSelected ? WorkstationTheme.accent.opacity(0.08) : (isHovering ? Color.black.opacity(0.40) : .clear),
            radius: isSelected || isHovering ? 16 : 0,
            x: 0,
            y: 8
        )
        .contentShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Issue \(issue.id), \(issue.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    private var tagRow: some View {
        HStack(spacing: 6) {
            BadgeView(style: .id) {
                Text(issue.id)
                    .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let priority = issue.priority,
               let difficulty = PriorityDifficulty.from(priority: priority) {
                difficultyBadge(difficulty.displayName, priority: priority)
            }

            if let type = issue.issueType, !type.isEmpty {
                typeBadge(type)
            }

            if isBlockedByDependency {
                blockerBadge
            }

            if let recurringMeta = appVM.recurringMetadata(for: issue.id), recurringMeta.isRecurring {
                recurringBadge(for: recurringMeta)
            }

            Spacer(minLength: 0)
        }
    }

    private func recurringBadge(for metadata: RecurringMetadata) -> some View {
        let overdue = metadata.overdueDays(now: Date())
        let isOverdue = overdue > 0
        return BadgeView(style: .recurring(isOverdue: isOverdue)) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9, weight: .bold))
                if isOverdue {
                    Text("Overdue \(overdue)d")
                } else if metadata.completionCount > 0 {
                    Text("#\(metadata.completionCount)")
                } else {
                    Text("New")
                }
            }
            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
            .lineLimit(1)
        }
        .help(recurringHelp(for: metadata, overdue: overdue))
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

    private var blockerBadge: some View {
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
            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 8) {
            if issue.assignee?.isEmpty == false {
                AssigneeBadgeView(assignee: issue.assignee, profiles: profiles, compact: true)
                    .frame(maxWidth: 160, alignment: .leading)
            } else {
                Text("Unassigned")
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textDisabled)
            }

            Spacer(minLength: 0)

            if let updated = issue.updatedAt, !updated.isEmpty {
                Label(shortDate(updated), systemImage: "clock")
                    .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }
        }
    }

    private func difficultyBadge(_ label: String, priority: Int) -> some View {
        let color = WorkstationTheme.difficultyColor(priority)
        return BadgeView(style: .priority(priority)) {
            HStack(spacing: 4) {
                if priority <= 1 {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                }
                Text(label)
            }
            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
            .lineLimit(1)
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
                appVM.presentCloseSheet(for: issue.id)
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

        Menu("Change Assignee") {
            Button("Claude") {
                Task {
                    await store.update(id: issue.id, UpdateIssueInput(assignee: "claude"))
                }
            }
            Button("Codex") {
                Task {
                    await store.update(id: issue.id, UpdateIssueInput(assignee: "codex"))
                }
            }
            Button("Other") {
                Task {
                    await store.update(id: issue.id, UpdateIssueInput(assignee: "other"))
                }
            }
            Button("Me") {
                Task {
                    await store.update(id: issue.id, UpdateIssueInput(assignee: "me"))
                }
            }
        }
    }
}
