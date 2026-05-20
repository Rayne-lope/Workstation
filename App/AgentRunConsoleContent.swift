import SwiftUI

struct AgentRunConsoleContent: View {
    @Bindable var appVM: AppViewModel
    let record: AgentRunRecord
    let compact: Bool

    @State private var notesDraft: String = ""
    @State private var copyConfirmation: String?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: compact ? 18 : 22) {
                runMetaSection
                AgentRunPromptPreviewView(
                    record: record,
                    compact: compact,
                    onCopyPrompt: { copy(record.prompt, label: "Prompt copied") },
                    onCopyCommand: { copy(record.command, label: "Command copied") },
                    onOpenTerminal: { appVM.openTerminalForAgentRun(record) }
                )

                AgentRunActionsView(
                    record: record,
                    onUpdateStatus: { status in
                        appVM.updateAgentRunStatus(id: record.id, status: status)
                    }
                )

                AgentRunNotesView(
                    notes: $notesDraft,
                    isDirty: notesDraft != (record.notes ?? ""),
                    onSave: { saveNotes() },
                    onRevert: { notesDraft = record.notes ?? "" }
                )

                AgentRunTranscriptView(
                    runID: record.id,
                    messages: appVM.transcriptMessages(for: record.id),
                    onAppend: { role, content in
                        appVM.appendTranscriptMessage(runID: record.id, role: role, content: content)
                    },
                    onUpdateContent: { id, content in
                        appVM.updateTranscriptMessageContent(id: id, content: content)
                    },
                    onUpdateRole: { id, role in
                        appVM.updateTranscriptMessageRole(id: id, role: role)
                    },
                    onDelete: { id in
                        appVM.deleteTranscriptMessage(id: id)
                    }
                )

                if let copyConfirmation {
                    Label(copyConfirmation, systemImage: "checkmark.circle.fill")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.green)
                        .transition(.opacity)
                }
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

    private var runMetaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(record.issueID)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textSelection(.enabled)
                Text(record.issueTitle)
                    .font(WorkstationTheme.Fonts.display(15, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                metaItem("Agent", record.agentName)
                metaItem("Launch", record.hasWorktreeMetadata ? "Worktree" : "Main tree")
                metaItem("Started", record.startedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let completed = record.completedAt {
                metaItem("Completed", completed.formatted(date: .abbreviated, time: .shortened))
            }

            if let worktree = record.worktree {
                HStack(spacing: 12) {
                    metaItem("Worktree", worktree.path)
                    metaItem("Branch", worktree.branchName)
                }

                if let sourceRunID = worktree.sourceRunID {
                    metaItem("Source Run", shortUUID(sourceRunID))
                }
            } else if !record.projectPath.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textMuted)
                    Text(record.projectPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func shortUUID(_ uuid: UUID) -> String {
        String(uuid.uuidString.prefix(8))
    }

    private func metaItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
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
