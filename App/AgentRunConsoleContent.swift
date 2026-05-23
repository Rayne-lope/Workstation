import SwiftUI

struct AgentRunConsoleContent: View {
    @Bindable var appVM: AppViewModel
    let record: AgentRunRecord
    let compact: Bool

    @State private var notesDraft: String = ""
    @State private var copyConfirmation: String?
    @State private var selectedTab: AgentRunConsoleTab = .terminal

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: compact ? 16 : 20) {
                runTitleSection
                runMetadataCard
                consoleTabBar
                selectedTabContent
                copyConfirmationBanner
            }
            .padding(.horizontal, compact ? 18 : 24)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .onAppear { notesDraft = record.notes ?? "" }
        .onChange(of: record.id) { _, _ in
            notesDraft = record.notes ?? ""
        }
    }

    private var runTitleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.issueID)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textSelection(.enabled)

                Text(record.issueTitle)
                    .font(WorkstationTheme.Fonts.display(compact ? 17 : 19, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FlowLayout(spacing: 8) {
                runChip(record.status.displayName, systemImage: "circle.fill", tint: statusColor(record.status))
                runChip(record.hasWorktreeMetadata ? "Worktree" : "Main tree", systemImage: record.hasWorktreeMetadata ? "folder.badge.gearshape" : "macwindow", tint: WorkstationTheme.accent)
                runChip(record.agentName, systemImage: "terminal", tint: WorkstationTheme.textSecondary)
            }
        }
    }

    private var runMetadataCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            metadataRow(
                label: "Agent",
                value: record.agentName,
                systemImage: "person.crop.circle.badge.checkmark"
            )
            metadataDivider

            metadataRow(
                label: "Started",
                value: record.startedAt.formatted(date: .abbreviated, time: .shortened),
                systemImage: "clock"
            )

            if let completed = record.completedAt {
                metadataDivider
                metadataRow(
                    label: "Completed",
                    value: completed.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "checkmark.circle"
                )
            }

            metadataDivider

            if let worktree = record.worktree {
                metadataRow(label: "Worktree", value: worktree.path, systemImage: "folder.badge.gearshape", monospaced: true)
                metadataDivider
                metadataRow(label: "Branch", value: worktree.branchName, systemImage: "point.topleft.down.curvedto.point.bottomright.up")

                if let sourceRunID = worktree.sourceRunID {
                    metadataDivider
                    metadataRow(label: "Source Run", value: shortUUID(sourceRunID), systemImage: "arrow.triangle.branch")
                }
            } else {
                metadataRow(label: "Project", value: record.projectPath, systemImage: "folder", monospaced: true)
            }
        }
        .padding(14)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private var consoleTabBar: some View {
        HStack(spacing: 6) {
            ForEach(AgentRunConsoleTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        selectedTab = tab
                    }
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(selectedTab == tab ? WorkstationTheme.card : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            }
        }
        .padding(4)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .prompt:
            promptCard
        case .command:
            commandCard
        case .terminal:
            terminalDrawerSection
        case .activity:
            activityContent
        }
    }

    private var promptCard: some View {
        sectionCard {
            HStack(spacing: 10) {
                sectionTitle("Prompt", systemImage: "doc.text")
                Spacer()
                Button {
                    copy(record.prompt, label: "Prompt copied")
                } label: {
                    Label("Copy Prompt", systemImage: "doc.on.doc")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
            }

            ScrollView(.vertical) {
                Text(record.prompt)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: compact ? 360 : 460)
            .background(WorkstationTheme.inputBg)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    private var commandCard: some View {
        sectionCard {
            HStack(spacing: 10) {
                sectionTitle("Terminal Command", systemImage: "terminal")
                Spacer()
                Button {
                    copy(record.command, label: "Command copied")
                } label: {
                    Label("Copy Command", systemImage: "doc.on.doc")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))

                Button {
                    appVM.openTerminalForAgentRun(record)
                } label: {
                    Label("Open Terminal", systemImage: "macwindow")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
            }

            Text(record.command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(WorkstationTheme.inputBg)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    private var terminalDrawerSection: some View {
        LiveTerminalDrawer(
            runID: record.id,
            messages: appVM.transcriptMessages(for: record.id),
            isActive: record.status == .terminalOpened,
            onKillAgent: { appVM.killActiveAgent(runID: record.id) },
            onClearLogs: { appVM.clearLiveLogs(runID: record.id) }
        )
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 16) {
            sectionCard {
                AgentRunActionsView(
                    record: record,
                    onUpdateStatus: { status in
                        appVM.updateAgentRunStatus(id: record.id, status: status)
                    }
                )
            }

            sectionCard {
                AgentRunNotesView(
                    notes: $notesDraft,
                    isDirty: notesDraft != (record.notes ?? ""),
                    onSave: { saveNotes() },
                    onRevert: { notesDraft = record.notes ?? "" }
                )
            }

            sectionCard {
                AgentRunTimelineFullView(
                    appVM: appVM,
                    runID: record.id,
                    issueID: record.issueID
                )
            }
        }
    }

    @ViewBuilder
    private var copyConfirmationBanner: some View {
        if let copyConfirmation {
            Label(copyConfirmation, systemImage: "checkmark.circle.fill")
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(WorkstationTheme.greenBg)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.greenBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                .transition(.opacity)
        }
    }

    private var metadataDivider: some View {
        Rectangle()
            .fill(WorkstationTheme.borderSoft)
            .frame(height: 1)
            .padding(.leading, 30)
            .padding(.vertical, 9)
    }

    private func metadataRow(label: String, value: String, systemImage: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textMuted)
                .frame(width: 20)

            Text(label)
                .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.55)
                .frame(width: 78, alignment: .leading)

            Text(value.isEmpty ? "None" : value)
                .font(monospaced ? .system(size: 11.5, weight: .medium, design: .monospaced) : WorkstationTheme.Fonts.body(11.5, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(WorkstationTheme.Fonts.label)
            .foregroundStyle(WorkstationTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.7)
    }

    private func runChip(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private func statusColor(_ status: AgentRunStatus) -> Color {
        switch status {
        case .prepared:
            return WorkstationTheme.textMuted
        case .terminalOpened:
            return WorkstationTheme.accent
        case .needsReview:
            return WorkstationTheme.orange
        case .accepted:
            return WorkstationTheme.green
        case .failed:
            return WorkstationTheme.red
        case .abandoned:
            return WorkstationTheme.textSubtle
        }
    }

    private func shortUUID(_ uuid: UUID) -> String {
        String(uuid.uuidString.prefix(8))
    }

    private func copy(_ value: String, label: String) {
        Clipboard.copy(value)
        withAnimation(.easeOut(duration: 0.15)) { copyConfirmation = label }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.15)) { copyConfirmation = nil }
        }
    }

    private func saveNotes() {
        appVM.updateAgentRunNotes(id: record.id, notes: notesDraft)
        withAnimation(.easeOut(duration: 0.15)) { copyConfirmation = "Notes saved" }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.15)) { copyConfirmation = nil }
        }
    }
}

private enum AgentRunConsoleTab: String, CaseIterable, Identifiable {
    case prompt
    case command
    case terminal
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prompt: return "Prompt"
        case .command: return "Command"
        case .terminal: return "Terminal"
        case .activity: return "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .prompt: return "doc.text"
        case .command: return "terminal"
        case .terminal: return "chevron.left.forwardslash.chevron.right"
        case .activity: return "waveform.path.ecg"
        }
    }
}
