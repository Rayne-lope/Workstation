import AppKit
import SwiftUI

struct IssueDetailView: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore
    let issue: BeadIssue

    @State private var isGeneratingIndonesianSummary = false
    @State private var indonesianSummaryError: String?
    @State private var selectedDetailTab: IssueDetailTab = .details

    @State private var changedFiles: [GitChangedFile] = []
    @State private var isLoadingFiles = false
    @State private var filesError: String? = nil
    @State private var timer: Timer? = nil
    @State private var hoveredFileID: String? = nil

    @State private var aiCommitState: AICommitState = .idle
    @State private var commitMessageText: String = ""
    @State private var hoveredCommitRow: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    titleSection
                    metadataCard
                    timelineSection
                    detailTabBar
                    selectedTabContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .background(WorkstationTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(WorkstationTheme.border)
                .frame(width: 1)
        }
        .onAppear {
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
        .onChange(of: issue.id) { _, _ in
            refreshModifiedFiles()
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
            + Text(displayStatus)
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

            FlowHStack(spacing: 6, runSpacing: 6) {
                if let type = issue.issueType, !type.isEmpty {
                    detailChip(label: type, systemImage: "tag", style: .info)
                }
                if let priority = issue.priority,
                   let difficulty = PriorityDifficulty.from(priority: priority) {
                    detailChip(label: difficulty.displayName, systemImage: "speedometer", style: .priority(priority))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Issue \(issue.id), \(issue.title)")
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            metadataRow(label: "Status") {
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(displayStatus)
                        .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }

            metadataDivider

            metadataRow(label: "Assignee") {
                assigneeMenuLabel
            }

            if let updated = issue.updatedAt, !updated.isEmpty {
                metadataDivider
                metadataRow(label: "Updated") {
                    Text(updated)
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                }
            }

            if let latestRun = appVM.agentRunHistoryStore.latestRecord(forIssueID: issue.id),
               let worktree = latestRun.worktree {
                metadataDivider
                metadataRow(label: "Worktree") {
                    worktreeMetadataBadge(branch: worktree.branchName, path: worktree.path)
                }
            }

            if let metadata = appVM.recurringMetadata(for: issue.id), metadata.isRecurring {
                metadataDivider
                metadataRow(label: "Recurring") {
                    recurringSummaryBadge(metadata)
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

    // MARK: - Timeline Section

    @ViewBuilder
    private var timelineSection: some View {
        if let latestRun = appVM.agentRunHistoryStore.latestRecord(forIssueID: issue.id) {
            AgentRunTimelineCompactView(appVM: appVM, runID: latestRun.id, issueID: issue.id)
                .padding(.bottom, 6)
        }
    }

    private var metadataDivider: some View {
        Rectangle()
            .fill(WorkstationTheme.borderSoft)
            .frame(height: 1)
            .padding(.leading, 104)
    }

    private func metadataRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(width: 92, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var assigneeMenuLabel: some View {
        Menu {
            ForEach(appVM.agentProfileStore.profiles.filter { $0.role == .codingExecutor && $0.canExecuteCode }, id: \.id) { profile in
                Button("\(profile.name) (assign + launch)") {
                    appVM.assignAndLaunchIfExecutor(for: issue, assignee: profile.claimAssigneeToken)
                }
            }
            Divider()
            Button("Me") {
                Task { await store.update(id: issue.id, UpdateIssueInput(assignee: "me")) }
            }
            Button("Clear") {
                Task { await store.update(id: issue.id, UpdateIssueInput(assignee: "")) }
            }
        } label: {
            if let assignee = issue.assignee, !assignee.isEmpty {
                AssigneeBadgeView(assignee: assignee, profiles: appVM.agentProfileStore.profiles, compact: true)
            } else {
                Text("Unassigned")
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func detailChip(label: String, systemImage: String, style: BadgeStyle) -> some View {
        BadgeView(style: style, verticalPadding: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .bold))
            }
            .lineLimit(1)
        }
    }

    private func worktreeMetadataBadge(branch: String, path: String) -> some View {
        Label {
            Text(branch)
                .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(WorkstationTheme.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(WorkstationTheme.blueBg)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(WorkstationTheme.blueBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
        .help(path)
    }

    private func recurringSummaryBadge(_ metadata: RecurringMetadata) -> some View {
        let overdue = metadata.overdueDays(now: Date())
        let text: String
        if overdue > 0 {
            text = "Overdue \(overdue)d"
        } else if let cadence = metadata.cadenceDays {
            text = "\(cadence)d cadence"
        } else {
            text = "Recurring"
        }

        return BadgeView(style: .recurring(isOverdue: overdue > 0), verticalPadding: 4) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9, weight: .bold))
                Text(text)
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .bold))
            }
            .lineLimit(1)
        }
    }

    private var detailTabBar: some View {
        HStack(spacing: 0) {
            ForEach(IssueDetailTab.allCases) { tab in
                detailTabButton(tab)
            }
        }
        .padding(3)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func detailTabButton(_ tab: IssueDetailTab) -> some View {
        let isSelected = selectedDetailTab == tab
        return Button {
            selectedDetailTab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(tab.title)
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? WorkstationTheme.card : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedDetailTab {
        case .details:
            detailsTabContent
        case .activity:
            activityTabContent
        case .actions:
            actionsTabContent
        }
    }

    private var detailsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            textSections
            modifiedFilesSection
            aiCommitSection
            dependenciesSection
        }
    }

    private var activityTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let latestRun = appVM.agentRunHistoryStore.latestRecord(forIssueID: issue.id) {
                latestRunSummary(for: latestRun)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WorkstationTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                            .stroke(WorkstationTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
            } else {
                emptyPanelMessage("No agent runs yet", systemImage: "rectangle.on.rectangle.slash")
            }

            IssueDetailRecurringSection(
                appVM: appVM,
                issue: issue,
                isLoading: store.isLoading,
                displayMode: .history
            )

            focusTimeSection
        }
    }

    private var actionsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            actionsSection
            IssueDetailRecurringSection(
                appVM: appVM,
                issue: issue,
                isLoading: store.isLoading,
                displayMode: .controls
            )
            focusTimeSection
        }
    }

    private func emptyPanelMessage(_ message: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(message)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
        }
        .foregroundStyle(WorkstationTheme.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
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
                copyPromptButton
                HStack(spacing: 8) {
                    claimButton
                    reviewButton
                }
                HStack(spacing: 8) {
                    closeButton
                    reopenButton
                }
                HStack(spacing: 8) {
                    focusButton
                    if alreadyInReview {
                        sendBackButton
                    }
                }

                if appVM.localAISettings.isEnabled {
                    simplifyIndonesianButton
                    if let indonesianSummaryError {
                        localAIErrorBanner(message: indonesianSummaryError)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private var simplifyIndonesianButton: some View {
        Button {
            requestIndonesianSummary()
        } label: {
            HStack(spacing: 6) {
                if isGeneratingIndonesianSummary {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(isGeneratingIndonesianSummary ? "Menyederhanakan..." : "Sederhanakan (Bahasa Indonesia)")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(WorkstationGhostButtonStyle())
        .disabled(isGeneratingIndonesianSummary)
        .help("Buat penjelasan sederhana dalam Bahasa Indonesia (pratinjau read-only) · Tersedia juga di Copilot ⌘K")
    }

    private func localAIErrorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.orange)
                .padding(.top, 2)
            Text(message)
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.orange)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(WorkstationTheme.borderSoft)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func requestIndonesianSummary() {
        guard !isGeneratingIndonesianSummary else { return }
        isGeneratingIndonesianSummary = true
        indonesianSummaryError = nil

        let action = LocalAIAction.simplifyIssueIndonesian(issue: issue)
        let currentAppVM = appVM
        let issueID = issue.id
        let issueTitle = issue.title

        Task {
            do {
                let suggestion = try await currentAppVM.requestLocalAIResponse(for: action)
                await MainActor.run {
                    currentAppVM.presentLocalAISuggestionPreview(
                        title: "Ringkasan Bahasa Indonesia",
                        subtitle: "\(issueID) · \(issueTitle)",
                        sourceLabel: "Simplify",
                        generatedText: suggestion,
                        regenerate: {
                            try await currentAppVM.requestLocalAIResponse(for: action)
                        },
                        onApply: { _ in
                            currentAppVM.dismissLocalAISuggestionPreview()
                        }
                    )
                    self.isGeneratingIndonesianSummary = false
                }
            } catch {
                await MainActor.run {
                    self.indonesianSummaryError = error.localizedDescription
                    self.isGeneratingIndonesianSummary = false
                }
            }
        }
    }

    private func latestRunSummary(for record: AgentRunRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            uppercaseLabel("Latest Run")

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(for: record.status))
                        .frame(width: 7, height: 7)
                    Text(record.status.displayName)
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(statusColor(for: record.status))
                }
            }

            if let worktree = record.worktree {
                VStack(alignment: .leading, spacing: 6) {
                    labelValueRow(label: "Path", value: worktree.path)
                    labelValueRow(label: "Branch", value: worktree.branchName)
                    if let sourceRunID = worktree.sourceRunID {
                        labelValueRow(label: "Source", value: String(sourceRunID.uuidString.prefix(8)))
                    }
                }
            } else if !record.projectPath.isEmpty {
                labelValueRow(label: "Path", value: record.projectPath)
            }
        }
    }

    private func labelValueRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private func statusColor(for status: AgentRunStatus) -> Color {
        switch status {
        case .prepared, .terminalOpened:
            return WorkstationTheme.accent
        case .needsReview:
            return WorkstationTheme.blue
        case .accepted:
            return WorkstationTheme.green
        case .failed:
            return WorkstationTheme.red
        case .abandoned:
            return WorkstationTheme.textMuted
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

    private var copyPromptButton: some View {
        Button {
            appVM.copyPrompt(for: issue)
        } label: {
            Label("Copy Prompt", systemImage: "doc.on.doc")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(WorkstationGhostButtonStyle())
        .help("Copy Agent Prompt")
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
            appVM.presentCloseSheet(for: issue)
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

    private func uppercaseLabel(_ label: String) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.label)
            .foregroundStyle(WorkstationTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.7)
    }

    // MARK: - Focus Mode

    private var focusButton: some View {
        let isFocused = appVM.activeFocusIssueID == issue.id
        return Button {
            appVM.focusToggle(for: issue.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isFocused ? "stop.circle.fill" : "eye.circle")
                    .font(.system(size: 11, weight: .bold))
                Text(isFocused ? "End Focus" : "Focus")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(WorkstationPrimaryButtonStyle())
        .opacity(isFocused ? 1 : 0)
        .disabled(!isFocused)
        .overlay {
            Button {
                appVM.focusToggle(for: issue.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye.circle")
                        .font(.system(size: 11, weight: .bold))
                    Text("Focus")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationGhostButtonStyleCompat())
            .opacity(isFocused ? 0 : 1)
            .disabled(isFocused)
        }
        .help(isFocused ? "End focus session" : "Start a focus session for this issue")
    }

    private struct WorkstationGhostButtonStyleCompat: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                .foregroundStyle(configuration.isPressed ? WorkstationTheme.textPrimary : WorkstationTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(configuration.isPressed ? WorkstationTheme.hover : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    private var focusTimeSection: some View {
        let totalMs = appVM.focusSessionStore?.totalMs(for: issue.id) ?? 0
        let session = appVM.focusSessionStore?.session(for: issue.id)
        let intervals = session?.completedIntervals ?? []
        let isActive = session?.isActive == true

        return VStack(alignment: .leading, spacing: 10) {
            uppercaseLabel("Time Spent")

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.accent)

                    if totalMs == 0 && !isActive {
                        Text("No focus sessions yet")
                            .font(WorkstationTheme.Fonts.body(12))
                            .foregroundStyle(WorkstationTheme.textMuted)
                    } else {
                        Text(formatDuration(totalMs))
                            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.textPrimary)

                        if isActive {
                            Text("· Active now")
                                .font(WorkstationTheme.Fonts.body(11))
                                .foregroundStyle(WorkstationTheme.accent)
                        }

                        Spacer()

                        Text("\(intervals.count) session\(intervals.count == 1 ? "" : "s")")
                            .font(WorkstationTheme.Fonts.body(10))
                            .foregroundStyle(WorkstationTheme.textSubtle)
                    }
                }

                if !intervals.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(intervals.suffix(5).reversed()) { interval in
                            HStack(spacing: 6) {
                                Text(formatDate(interval.startedAt))
                                    .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                                    .foregroundStyle(WorkstationTheme.textSubtle)
                                    .layoutPriority(1)
                                Spacer()
                                Text(formatDuration(interval.durationMs))
                                    .font(WorkstationTheme.Fonts.body(10, weight: .medium).monospacedDigit())
                                    .foregroundStyle(WorkstationTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    private func formatDuration(_ ms: Int64) -> String {
        let totalSeconds = max(0, ms / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var displayStatus: String {
        if issue.labels?.contains("human") == true {
            return "review"
        }
        return issue.status ?? "open"
    }

    private var statusColor: Color {
        if issue.labels?.contains("human") == true {
            return WorkstationTheme.blue
        }
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

    // MARK: - AI Commit Section (Workstation-uhwd)

    private enum AICommitState: Equatable {
        case idle
        case drafting
        case drafted
        case committing
        case success
        case error(String)
    }

    @ViewBuilder
    private var aiCommitSection: some View {
        if hasActiveWorktree && !changedFiles.isEmpty && filesError == nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.accent)
                    uppercaseLabel("AI Commit")
                    Spacer()
                }

                switch aiCommitState {
                case .idle:
                    aiCommitIdleContent
                case .drafting:
                    aiCommitDraftingContent
                case .drafted:
                    aiCommitDraftedContent
                case .committing:
                    aiCommitCommittingContent
                case .success:
                    aiCommitSuccessContent
                case .error(let message):
                    aiCommitErrorContent(message)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(WorkstationTheme.accentBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        }
    }

    private var aiCommitIdleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(changedFiles.count) file\(changedFiles.count == 1 ? "" : "s") changed")
                    .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                Spacer()
            }

            Button {
                draftCommitMessage()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("Draft Commit Message with AI")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationGhostButtonStyle())
        }
    }

    private var aiCommitDraftingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(WorkstationTheme.accent)
                Text("Drafting commit message...")
                    .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        }
    }

    private var aiCommitDraftedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                TextEditor(text: $commitMessageText)
                    .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60, maxHeight: 160)
                    .padding(10)
                    .background(WorkstationTheme.inputBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            }

            HStack(spacing: 8) {
                Button {
                    aiCommitState = .idle
                    commitMessageText = ""
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkstationGhostButtonStyle())
                .help("Discard the drafted message")

                Button {
                    commitAndPush()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Commit & Push")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(commitMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Commit all changes and push to remote")
            }
        }
    }

    private var aiCommitCommittingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(WorkstationTheme.accent)
                Text("Committing and pushing...")
                    .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        }
    }

    private var aiCommitSuccessContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WorkstationTheme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Changes committed & pushed")
                    .font(WorkstationTheme.Fonts.body(13, weight: .bold))
                    .foregroundStyle(WorkstationTheme.green)
                Text("Worktree cleaned up successfully.")
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.textSecondary)
            }
            Spacer()
            Button {
                aiCommitState = .idle
                commitMessageText = ""
                refreshModifiedFiles()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .frame(width: 20, height: 20)
                    .background(WorkstationTheme.hover)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.vertical, 4)
    }

    private func aiCommitErrorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.red)
                Text(message)
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.red)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    aiCommitState = .idle
                    commitMessageText = ""
                } label: {
                    Text("Dismiss")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkstationGhostButtonStyle())

                Button {
                    draftCommitMessage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                        Text("Retry")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkstationGhostButtonStyle())
            }
        }
    }

    private func draftCommitMessage() {
        aiCommitState = .drafting
        commitMessageText = ""
        let currentAppVM = appVM
        let currentIssue = issue
        Task {
            do {
                let message = try await currentAppVM.draftCommitMessage(for: currentIssue)
                await MainActor.run {
                    self.commitMessageText = message
                    self.aiCommitState = .drafted
                }
            } catch {
                await MainActor.run {
                    self.aiCommitState = .error(error.localizedDescription)
                }
            }
        }
    }

    private func commitAndPush() {
        let message = commitMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        aiCommitState = .committing
        let currentAppVM = appVM
        let currentIssue = issue
        Task {
            do {
                try await currentAppVM.commitAndPushWorktree(for: currentIssue, message: message)
                await MainActor.run {
                    self.commitMessageText = ""
                    self.aiCommitState = .success
                }
            } catch {
                await MainActor.run {
                    self.aiCommitState = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Modified Files Section (Workstation-8rmu)

    private var hasActiveWorktree: Bool {
        guard let workspace = appVM.activeWorkspace else { return false }
        let location = appVM.gitWorktreeService.worktreeLocation(for: workspace, issueID: issue.id)
        return FileManager.default.fileExists(atPath: location.worktreeURL.path)
    }

    private func startMonitoring() {
        refreshModifiedFiles()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            refreshModifiedFiles()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshModifiedFiles() {
        guard let workspace = appVM.activeWorkspace else { return }
        let location = appVM.gitWorktreeService.worktreeLocation(for: workspace, issueID: issue.id)
        guard FileManager.default.fileExists(atPath: location.worktreeURL.path) else {
            self.changedFiles = []
            self.filesError = nil
            return
        }

        isLoadingFiles = true
        filesError = nil
        Task {
            do {
                let summary = try await GitStatusService(commandRunner: appVM.shellRunner).statusSummary(in: location.worktreeURL)
                await MainActor.run {
                    self.changedFiles = summary.changedFiles
                    self.isLoadingFiles = false
                }
            } catch {
                await MainActor.run {
                    self.filesError = error.localizedDescription
                    self.isLoadingFiles = false
                }
            }
        }
    }

    @ViewBuilder
    private var modifiedFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                uppercaseLabel("Modified Files")
                
                if hasActiveWorktree && !changedFiles.isEmpty {
                    Text("\(changedFiles.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WorkstationTheme.borderSoft)
                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                }
                
                Spacer()
                
                if hasActiveWorktree {
                    if isLoadingFiles {
                        ProgressView()
                            .controlSize(.small)
                            .tint(WorkstationTheme.accent)
                    } else {
                        Button {
                            refreshModifiedFiles()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(WorkstationTheme.accent)
                                .frame(width: 24, height: 24)
                                .background(WorkstationTheme.hover)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Refresh file status")
                    }
                }
            }
            .padding(.bottom, 2)

            if !hasActiveWorktree {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                            .fill(WorkstationTheme.borderSoft)
                            .frame(width: 32, height: 32)
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.textMuted)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No active worktree found")
                            .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                            .foregroundStyle(WorkstationTheme.textSecondary)
                        Text("Launch an agent to start tracking changes.")
                            .font(WorkstationTheme.Fonts.body(10))
                            .foregroundStyle(WorkstationTheme.textDisabled)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
            } else if let filesError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkstationTheme.red)
                    Text(filesError)
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WorkstationTheme.redBg)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            } else if changedFiles.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(WorkstationTheme.green)
                    Text("Working tree is clean. No modified files.")
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(changedFiles) { file in
                                modifiedFileRow(file)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            }
        }
    }

    private func modifiedFileRow(_ file: GitChangedFile) -> some View {
        let isHovered = hoveredFileID == file.id
        let url = URL(fileURLWithPath: file.path)
        let fileName = url.lastPathComponent
        let folderPath = url.deletingLastPathComponent().path
        
        return Button {
            openModifiedFile(file)
        } label: {
            HStack(spacing: 12) {
                // Change status badge
                statusBadge(for: file.status)
                
                // File type icon
                Image(systemName: fileIconName(for: file.path))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(fileIconColor(for: file.path))
                    .frame(width: 20, height: 20)
                
                // File path details
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                    
                    if !folderPath.isEmpty && folderPath != "." {
                        Text(folderPath)
                            .font(WorkstationTheme.Fonts.body(10))
                            .foregroundStyle(WorkstationTheme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                
                Spacer()
                
                // Action indicator on hover
                if isHovered {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.accent)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? WorkstationTheme.hover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredFileID = hovering ? file.id : nil
        }
    }

    private func openModifiedFile(_ file: GitChangedFile) {
        guard let workspace = appVM.activeWorkspace else { return }
        let location = appVM.gitWorktreeService.worktreeLocation(for: workspace, issueID: issue.id)
        let fileURL = location.worktreeURL.appendingPathComponent(file.path)
        NSWorkspace.shared.open(fileURL)
    }

    private func fileIconName(for path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return "curlybraces"
        case "md", "markdown": return "doc.text"
        case "json", "yaml", "yml", "plist", "xml": return "slider.horizontal.3"
        case "sh", "bash", "zsh": return "terminal"
        case "png", "jpg", "jpeg", "gif", "svg", "assets": return "photo"
        default: return "doc"
        }
    }

    private func fileIconColor(for path: String) -> Color {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return WorkstationTheme.orange
        case "md", "markdown": return WorkstationTheme.blue
        case "json", "yaml", "yml", "plist", "xml": return WorkstationTheme.purple
        case "sh", "bash", "zsh": return WorkstationTheme.accent
        case "png", "jpg", "jpeg", "gif", "svg", "assets": return WorkstationTheme.green
        default: return WorkstationTheme.textSecondary
        }
    }

    private func statusBadge(for status: String) -> some View {
        let label: String
        let fg: Color
        let bg: Color
        let border: Color

        let trimmed = status.trimmingCharacters(in: .whitespaces)
        if trimmed == "A" || trimmed == "??" || trimmed == "?" {
            label = "+"
            fg = WorkstationTheme.green
            bg = WorkstationTheme.greenBg
            border = WorkstationTheme.greenBorder
        } else if trimmed == "D" {
            label = "-"
            fg = WorkstationTheme.red
            bg = WorkstationTheme.redBg
            border = WorkstationTheme.redBorder
        } else if trimmed == "R" || trimmed == "C" {
            label = "→"
            fg = WorkstationTheme.blue
            bg = WorkstationTheme.blueBg
            border = WorkstationTheme.blueBorder
        } else {
            label = "M"
            fg = WorkstationTheme.orange
            bg = WorkstationTheme.orangeBg
            border = WorkstationTheme.orangeBorder
        }

        return Text(label)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(fg)
            .frame(width: 16, height: 16)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
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

private enum IssueDetailTab: String, CaseIterable, Identifiable {
    case details
    case activity
    case actions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .details:
            return "Details"
        case .activity:
            return "Activity"
        case .actions:
            return "Actions"
        }
    }

    var systemImage: String {
        switch self {
        case .details:
            return "text.alignleft"
        case .activity:
            return "waveform.path.ecg"
        case .actions:
            return "bolt"
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
