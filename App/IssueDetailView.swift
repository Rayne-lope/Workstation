import AppKit
import SwiftUI

struct IssueDetailView: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore
    let issue: BeadIssue

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    propertiesSection
                    dependenciesSection
                    textSections
                    actionsSection
                    agentSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .background(WorkstationTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(WorkstationTheme.border)
                .frame(width: 1)
        }
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }

    private var panelHeader: some View {
        let hasRunRecord = appVM.agentRunHistoryStore.latestRecord(forIssueID: issue.id) != nil
        return HStack(spacing: 6) {
            Text("Issue / ")
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSubtle)
            + Text(issue.status ?? "open")
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(statusColor)

            Spacer()

            Button {
                appVM.showConsolePane(forIssueID: issue.id)
            } label: {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(IconButtonStyle())
            .disabled(!hasRunRecord)
            .opacity(hasRunRecord ? 1 : 0.35)
            .help(hasRunRecord ? "Open Run Console" : "No agent run recorded yet")

            Button {
                appVM.copyPrompt(for: issue)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(IconButtonStyle())
            .help("Copy Agent Prompt")

            Button {
                store.clearSelection()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(IconButtonStyle())
            .keyboardShortcut(.cancelAction)
            .help("Close Detail")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(issue.id)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textMuted)
                .textSelection(.enabled)

            Text(issue.title)
                .font(WorkstationTheme.Fonts.display(22, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .lineLimit(4)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Issue \(issue.id), \(issue.title)")
    }

    private var propertiesSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
            GridRow {
                propertyLabel("Status")
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(issue.status ?? "open")
                        .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                        .foregroundStyle(statusColor)
                }
            }

            GridRow {
                propertyLabel("Difficulty")
                Text(PriorityDifficulty.from(priority: issue.priority)?.displayName ?? "-")
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            GridRow {
                propertyLabel("Type")
                Text(issue.issueType ?? "-")
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            GridRow {
                propertyLabel("Assignee")
                if let assignee = issue.assignee, !assignee.isEmpty {
                    AssigneeBadgeView(assignee: assignee, profiles: appVM.agentProfileStore.profiles, compact: true)
                } else {
                    Text("Unassigned")
                        .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
            }

            if let updated = issue.updatedAt, !updated.isEmpty {
                GridRow {
                    propertyLabel("Updated")
                    Text(updated)
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private var dependenciesSection: some View {
        if let detail = store.selectedIssueDetail {
            let blockers = detail.dependencies ?? []
            let dependents = detail.dependents ?? []
            VStack(alignment: .leading, spacing: 14) {
                dependencyGroup(
                    title: "Blocked by",
                    items: blockers,
                    tone: WorkstationTheme.red,
                    onAddTapped: {
                        appVM.presentBlockerPicker(
                            for: issue.id,
                            existingBlockerIDs: Set(blockers.map(\.id))
                        )
                    },
                    onRemove: { blockerID in
                        Task { await store.removeDependency(blockerID: blockerID, from: issue.id) }
                    }
                )
                if !dependents.isEmpty {
                    dependencyGroup(
                        title: "Blocks",
                        items: dependents,
                        tone: WorkstationTheme.accent
                    )
                }
            }
        }
    }

    private func dependencyGroup(
        title: String,
        items: [BeadIssue],
        tone: Color,
        onAddTapped: (() -> Void)? = nil,
        onRemove: ((String) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                uppercaseLabel(title)
                Spacer()
                if let onAddTapped {
                    Button { onAddTapped() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Add")
                                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                        }
                        .foregroundStyle(WorkstationTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Add a blocker")
                }
            }
            if items.isEmpty {
                Text("None")
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textMuted)
            } else {
                VStack(spacing: 6) {
                    ForEach(items) { item in
                        dependencyChip(item, tone: tone, onRemove: onRemove)
                    }
                }
            }
        }
    }

    private func dependencyChip(
        _ item: BeadIssue,
        tone: Color,
        onRemove: ((String) -> Void)? = nil
    ) -> some View {
        HStack(spacing: 6) {
            Button {
                store.selectIssue(id: item.id)
            } label: {
                HStack(spacing: 6) {
                    Text(item.id)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .layoutPriority(1)
                    Text(item.title)
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let status = item.status, status == "closed" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(WorkstationTheme.green)
                    }
                }
                .foregroundStyle(tone)
            }
            .buttonStyle(.plain)
            .help("\(item.id) — \(item.title)")

            if let onRemove {
                Button {
                    onRemove(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tone.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Remove blocker \(item.id)")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(tone.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    @ViewBuilder
    private var textSections: some View {
        if let description = issue.description, !description.isEmpty {
            section(title: "Description", body: description)
        }
        if let acceptance = issue.acceptanceCriteria, !acceptance.isEmpty {
            section(title: "Acceptance Criteria", body: acceptance)
        }
        if let detail = store.selectedIssueDetail ?? store.selectedIssue,
           let notes = detail.notes, !notes.isEmpty {
            section(title: "Notes", body: notes)
        }
    }

    private var actionsSection: some View {
        let alreadyInReview = issue.labels?.contains(KanbanStateMapper.humanReviewLabel) == true
        return VStack(alignment: .leading, spacing: 12) {
            uppercaseLabel("Actions")

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    claimButton
                    reviewButton
                }
                HStack(spacing: 8) {
                    closeButton
                    reopenButton
                }
                if alreadyInReview {
                    sendBackButton
                }
            }
        }
    }

    private var sendBackButton: some View {
        Button {
            appVM.presentReviewFollowup(for: issue.id)
        } label: {
            Label("Send Back to Agent", systemImage: "arrow.uturn.backward.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(WorkstationGhostButtonStyle())
        .disabled(issue.status == "closed" || store.isLoading)
        .help("Copy a follow-up prompt with your notes so the agent can fix bugs / harden the implementation")
    }

    private var claimButton: some View {
        let profile = appVM.selectedAgentProfile()
        return Button {
            Task { await store.claim(id: issue.id) }
        } label: {
            Label("Claim", systemImage: "hand.raised")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(WorkstationGhostButtonStyle())
        .disabled(issue.status == "closed" || store.isLoading || !profile.shouldClaimIssue)
        .help(profile.shouldClaimIssue ? "" : "Selected agent doesn't claim issues")
    }

    @ViewBuilder
    private var reviewButton: some View {
        let profile = appVM.selectedAgentProfile()
        let alreadyInReview = issue.labels?.contains(KanbanStateMapper.humanReviewLabel) == true
        if profile.shouldRequestHumanReview {
            Button {
                Task { await store.requestHumanReview(id: issue.id) }
            } label: {
                Label(alreadyInReview ? "In Review" : "Request Review", systemImage: "person.fill.questionmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationGhostButtonStyle())
            .disabled(issue.status == "closed" || store.isLoading || alreadyInReview)
            .help(alreadyInReview ? "Already awaiting human review" : "Tag this issue with the human label so it lands in Review")
        }
    }

    private var closeButton: some View {
        let alreadyInReview = issue.labels?.contains(KanbanStateMapper.humanReviewLabel) == true
        return Button {
            appVM.presentCloseSheet(for: issue.id)
        } label: {
            Label(alreadyInReview ? "Approve & Close" : "Close", systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(WorkstationPrimaryButtonStyle())
        .disabled(issue.status == "closed" || store.isLoading)
        .help(alreadyInReview ? "Approve the review and close this issue" : "Close this issue")
    }

    private var reopenButton: some View {
        Button {
            Task { await store.reopen(id: issue.id) }
        } label: {
            Label("Reopen", systemImage: "arrow.uturn.backward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(WorkstationGhostButtonStyle())
        .disabled(issue.status != "closed" || store.isLoading)
    }

    private var agentSection: some View {
        let profile = appVM.selectedAgentProfile()
        let runnableProfiles = appVM.agentProfileStore.profiles.filter(\.canExecuteCode)
        let canExecute = profile.canExecuteCode
        let workspaceMissing = appVM.activeWorkspace == nil

        return VStack(alignment: .leading, spacing: 12) {
            uppercaseLabel("Agent")

            Picker("Agent Profile", selection: $appVM.selectedAgentProfileID) {
                ForEach(appVM.agentProfileStore.profiles) { profile in
                    Text("\(profile.name) — \(profile.role.displayName)").tag(profile.id)
                }
            }
            .labelsHidden()

            if !runnableProfiles.isEmpty {
                Menu {
                    ForEach(runnableProfiles) { runnableProfile in
                        Button {
                            appVM.launchAgent(for: issue, profile: runnableProfile)
                        } label: {
                            Text(runnableProfile.name)
                        }
                    }
                } label: {
                    Label("Run Agent", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(workspaceMissing)
                .help(workspaceMissing ? "Open a workspace first" : "Launch agent in terminal")
            }

            FlowHStack(spacing: 8, runSpacing: 8) {
                Button {
                    appVM.copyPrompt(for: issue)
                } label: {
                    Label("Copy Prompt", systemImage: "doc.on.doc")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))

                if canExecute {
                    Button {
                        appVM.copyAgentCommand(for: issue)
                    } label: {
                        Label("Copy Command", systemImage: "terminal.fill")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))

                    Button {
                        appVM.launchSelectedAgentInWorktree(for: issue)
                    } label: {
                        Label("Run in Worktree", systemImage: "folder.badge.gearshape")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .disabled(workspaceMissing)
                }
            }
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            uppercaseLabel(title)
            markdownBody(body, mode: .detail)
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    @ViewBuilder
    private func markdownBody(_ body: String, mode: MarkdownTextRenderer.Mode) -> some View {
        if let rendered = MarkdownTextRenderer.attributedString(from: body, mode: mode) {
            Text(rendered)
        } else {
            Text(body)
        }
    }

    private func propertyLabel(_ label: String) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(WorkstationTheme.textSubtle)
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(width: 90, alignment: .leading)
    }

    private func uppercaseLabel(_ label: String) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.label)
            .foregroundStyle(WorkstationTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.7)
    }

    private var statusColor: Color {
        switch issue.status {
        case "closed":
            return WorkstationTheme.green
        case "blocked":
            return WorkstationTheme.red
        case "in_progress":
            return WorkstationTheme.accent
        default:
            return WorkstationTheme.textSecondary
        }
    }
}

struct IssueDetailPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.and.text.magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textDisabled)
            Text("Select an issue")
                .font(WorkstationTheme.Fonts.display(16, weight: .bold))
                .foregroundStyle(WorkstationTheme.textSecondary)
            Text("Issue details and agent actions will appear here.")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(WorkstationTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(WorkstationTheme.border)
                .frame(width: 1)
        }
    }
}

private struct FlowHStack: Layout {
    var spacing: CGFloat = 6
    var runSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + runSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        return CGSize(width: totalWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                y += rowHeight + runSpacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
            .background(configuration.isPressed ? WorkstationTheme.borderSoft : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
