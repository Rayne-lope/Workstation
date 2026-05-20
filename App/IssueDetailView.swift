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
                    recurringSection
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

    @State private var recurringNotesDraft: String = ""
    @State private var recurringActionFlash: String?

    @ViewBuilder
    private var recurringSection: some View {
        let metadata = appVM.recurringMetadata(for: issue.id)
        let isRecurring = metadata?.isRecurring == true
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                uppercaseLabel("Recurring")
                Spacer()
                if isRecurring {
                    recurringCounterPill(metadata!)
                }
            }

            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { isRecurring },
                    set: { _ in appVM.toggleRecurring(for: issue.id) }
                )) {
                    Label(isRecurring ? "Recurring enabled" : "Mark as recurring", systemImage: "arrow.triangle.2.circlepath")
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(isRecurring ? WorkstationTheme.textPrimary : WorkstationTheme.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(WorkstationTheme.accent)
                .help("When on, completing a run resets the issue to Ready instead of closing it")
                Spacer()
            }

            if isRecurring, let metadata {
                cadencePickerView(currentDays: metadata.cadenceDays)
                runCompletionInput()
                if !metadata.history.isEmpty {
                    runHistoryView(metadata: metadata)
                }
            }

            if let flash = recurringActionFlash {
                Label(flash, systemImage: "checkmark.circle.fill")
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.green)
                    .transition(.opacity)
            }
        }
    }

    private func recurringCounterPill(_ metadata: RecurringMetadata) -> some View {
        let overdue = metadata.overdueDays(now: Date())
        let label: String
        if overdue > 0 {
            label = "Overdue \(overdue)d"
        } else if metadata.completionCount > 0 {
            label = "Run #\(metadata.completionCount)"
        } else {
            label = "No runs yet"
        }
        let color = overdue > 0 ? WorkstationTheme.orange : WorkstationTheme.purple
        return Text(label)
            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    @ViewBuilder
    private func cadencePickerView(currentDays: Int?) -> some View {
        let current = CadenceTarget.from(days: currentDays)
        HStack(spacing: 6) {
            Text("Cadence")
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.6)
            ForEach(CadenceTarget.allCases, id: \.self) { option in
                cadenceChip(option: option, isSelected: option == current)
            }
            Spacer()
        }
    }

    private func cadenceChip(option: CadenceTarget, isSelected: Bool) -> some View {
        Button {
            appVM.setCadence(for: issue.id, days: option.days)
        } label: {
            Text(cadenceShortLabel(option))
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(isSelected ? WorkstationTheme.background : WorkstationTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? WorkstationTheme.accent : WorkstationTheme.cardAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(isSelected ? WorkstationTheme.accent : WorkstationTheme.borderStrong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func cadenceShortLabel(_ option: CadenceTarget) -> String {
        switch option {
        case .none: return "None"
        case .weekly: return "7d"
        case .monthly: return "30d"
        case .quarterly: return "90d"
        }
    }

    private func runCompletionInput() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Optional notes for this run (what was done, what to remember next time)", text: $recurringNotesDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .lineLimit(2...4)
                .padding(10)
                .background(WorkstationTheme.cardAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

            Button {
                let notes = recurringNotesDraft
                Task { @MainActor in
                    let ok = await appVM.completeRecurringRun(for: issue.id, notes: notes)
                    if ok {
                        recurringNotesDraft = ""
                        flashRecurringAction("Run logged — issue reset to Ready")
                    }
                }
            } label: {
                Label("Mark Run Complete", systemImage: "checkmark.arrow.trianglehead.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationPrimaryButtonStyle())
            .disabled(issue.status == "closed" || store.isLoading)
            .help("Append a history entry and reset this issue back to Ready (does not close)")
        }
    }

    private func flashRecurringAction(_ message: String) {
        withAnimation(.easeOut(duration: 0.15)) { recurringActionFlash = message }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeOut(duration: 0.15)) { recurringActionFlash = nil }
        }
    }

    @ViewBuilder
    private func runHistoryView(metadata: RecurringMetadata) -> some View {
        let entries = metadata.history.sorted(by: { $0.completedAt > $1.completedAt })
        VStack(alignment: .leading, spacing: 8) {
            Text("Run history")
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.6)
            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    runHistoryRow(entry: entry, isFirst: index == 0)
                }
                if entries.count > 5 {
                    Text("+ \(entries.count - 5) older runs")
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    private func runHistoryRow(entry: RecurringHistoryEntry, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.green)
                Text(entry.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                if let by = entry.completedBy, !by.isEmpty {
                    Text("· \(by)")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
                Spacer()
            }
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 19)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle()
                    .fill(WorkstationTheme.borderSoft)
                    .frame(height: 1)
            }
        }
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
