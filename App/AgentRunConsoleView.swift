import SwiftUI

struct AgentRunConsolePane: View {
    @Bindable var appVM: AppViewModel
    let issue: BeadIssue

    var body: some View {
        VStack(spacing: 0) {
            AgentRunPaneHeader(
                issue: issue,
                record: appVM.activeConsoleRecord(),
                onBack: { appVM.showIssuePane() }
            )

            if let record = appVM.activeConsoleRecord() {
                AgentRunConsoleContent(appVM: appVM, record: record, compact: true)
            } else {
                EmptyConsolePlaceholder(onBack: { appVM.showIssuePane() })
            }
        }
        .background(WorkstationTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(WorkstationTheme.border)
                .frame(width: 1)
        }
    }
}

private struct AgentRunPaneHeader: View {
    let issue: BeadIssue
    let record: AgentRunRecord?
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Issue")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
            }
            .buttonStyle(InlinePaneButtonStyle())
            .keyboardShortcut(.cancelAction)
            .help("Back to issue detail")

            Text("Run Console")
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.leading, 4)

            Spacer()

            if let record {
                statusBadge(for: record.status)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    private func statusBadge(for status: AgentRunStatus) -> some View {
        let color: Color
        switch status {
        case .prepared, .terminalOpened: color = WorkstationTheme.accent
        case .needsReview: color = WorkstationTheme.blue
        case .accepted: color = WorkstationTheme.green
        case .failed: color = WorkstationTheme.red
        case .abandoned: color = WorkstationTheme.textMuted
        }
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(status.displayName)
                .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct InlinePaneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
            .background(configuration.isPressed ? WorkstationTheme.borderSoft : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct EmptyConsolePlaceholder: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.slash")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textDisabled)
            Text("No agent run recorded yet")
                .font(WorkstationTheme.Fonts.display(14, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSecondary)
            Text("Run an agent for this issue to populate the console.")
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Back to Issue") { onBack() }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct AgentRunConsoleContent: View {
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
                metaItem("Started", record.startedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let completed = record.completedAt {
                metaItem("Completed", completed.formatted(date: .abbreviated, time: .shortened))
            }

            if !record.projectPath.isEmpty {
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

struct AgentRunPromptPreviewView: View {
    let record: AgentRunRecord
    var compact: Bool = false
    let onCopyPrompt: () -> Void
    let onCopyCommand: () -> Void
    let onOpenTerminal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Prompt") {
                Button {
                    onCopyPrompt()
                } label: {
                    Label("Copy Prompt", systemImage: "doc.on.doc")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
            }

            ScrollView(.vertical) {
                Text(record.prompt)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: compact ? 160 : 220)
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

            sectionHeader("Terminal Command") {
                HStack(spacing: 6) {
                    Button {
                        onCopyCommand()
                    } label: {
                        Label("Copy Command", systemImage: "terminal")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .disabled(record.command.isEmpty)

                    Button {
                        onOpenTerminal()
                    } label: {
                        Label("Open Terminal", systemImage: "macwindow")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .disabled(record.projectPath.isEmpty)
                }
            }

            Text(record.command.isEmpty ? "No command recorded for this run." : record.command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(record.command.isEmpty ? WorkstationTheme.textMuted : WorkstationTheme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    @ViewBuilder
    private func sectionHeader<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textMuted)
                .textCase(.uppercase)
                .tracking(0.7)
            Spacer()
            trailing()
        }
    }
}

struct AgentRunActionsView: View {
    let record: AgentRunRecord
    let onUpdateStatus: (AgentRunStatus) -> Void

    private let statuses: [AgentRunStatus] = [.needsReview, .accepted, .failed, .abandoned]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mark Run As")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                Text("Current: \(record.status.displayName)")
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
            }

            FlowLayout(spacing: 8) {
                ForEach(statuses, id: \.self) { status in
                    Button {
                        onUpdateStatus(status)
                    } label: {
                        Text(status.displayName)
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .disabled(record.status == status)
                    .help("Update local run status to \(status.displayName). Does not modify the Beads issue.")
                }
            }

            Text("These statuses only affect this app's local run record. Beads issue status is not changed automatically.")
                .font(WorkstationTheme.Fonts.body(11, weight: .regular))
                .foregroundStyle(WorkstationTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AgentRunNotesView: View {
    @Binding var notes: String
    let isDirty: Bool
    let onSave: () -> Void
    let onRevert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Notes")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                if isDirty {
                    Text("Unsaved")
                        .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.orange)
                }
            }

            TextEditor(text: $notes)
                .font(.system(size: 12))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 110)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

            HStack(spacing: 8) {
                Spacer()
                Button {
                    onRevert()
                } label: {
                    Text("Revert")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                .disabled(!isDirty)

                Button {
                    onSave()
                } label: {
                    Label("Save Notes", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(!isDirty)
            }
        }
    }
}

struct AgentRunTranscriptView: View {
    let runID: UUID
    let messages: [AgentRunMessage]
    let onAppend: (AgentRunMessageRole, String) -> AgentRunMessage?
    let onUpdateContent: (UUID, String) -> Void
    let onUpdateRole: (UUID, AgentRunMessageRole) -> Void
    let onDelete: (UUID) -> Void

    @State private var draftContent: String = ""
    @State private var draftRole: AgentRunMessageRole = .agent
    @State private var pendingDeleteID: UUID?
    @State private var editingMessageID: UUID?
    @State private var editingDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                Text("\(messages.count) entr\(messages.count == 1 ? "y" : "ies")")
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textSubtle)
            }

            Text("Manually paste agent output, user instructions, or follow-up notes to build a lightweight transcript for this run. Nothing is streamed automatically.")
                .font(WorkstationTheme.Fonts.body(11, weight: .regular))
                .foregroundStyle(WorkstationTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if messages.isEmpty {
                Text("No transcript entries yet.")
                    .font(WorkstationTheme.Fonts.body(11.5, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(WorkstationTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(messages) { message in
                        AgentRunTranscriptEntryView(
                            message: message,
                            isEditing: editingMessageID == message.id,
                            editingDraft: $editingDraft,
                            pendingDelete: pendingDeleteID == message.id,
                            onStartEdit: {
                                editingMessageID = message.id
                                editingDraft = message.content
                            },
                            onCancelEdit: {
                                editingMessageID = nil
                                editingDraft = ""
                            },
                            onSaveEdit: {
                                onUpdateContent(message.id, editingDraft)
                                editingMessageID = nil
                                editingDraft = ""
                            },
                            onChangeRole: { role in
                                onUpdateRole(message.id, role)
                            },
                            onRequestDelete: {
                                pendingDeleteID = message.id
                            },
                            onConfirmDelete: {
                                onDelete(message.id)
                                pendingDeleteID = nil
                                if editingMessageID == message.id {
                                    editingMessageID = nil
                                    editingDraft = ""
                                }
                            },
                            onCancelDelete: {
                                pendingDeleteID = nil
                            }
                        )
                    }
                }
            }

            AgentRunTranscriptComposer(
                draftRole: $draftRole,
                draftContent: $draftContent,
                onAppend: {
                    if let _ = onAppend(draftRole, draftContent) {
                        draftContent = ""
                    }
                }
            )
        }
        .onChange(of: runID) { _, _ in
            draftContent = ""
            draftRole = .agent
            pendingDeleteID = nil
            editingMessageID = nil
            editingDraft = ""
        }
    }
}

private struct AgentRunTranscriptEntryView: View {
    let message: AgentRunMessage
    let isEditing: Bool
    @Binding var editingDraft: String
    let pendingDelete: Bool
    let onStartEdit: () -> Void
    let onCancelEdit: () -> Void
    let onSaveEdit: () -> Void
    let onChangeRole: (AgentRunMessageRole) -> Void
    let onRequestDelete: () -> Void
    let onConfirmDelete: () -> Void
    let onCancelDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                roleBadge

                Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSubtle)

                Spacer()

                Menu {
                    ForEach(AgentRunMessageRole.allCases) { role in
                        Button {
                            onChangeRole(role)
                        } label: {
                            Label(role.displayName, systemImage: role == message.role ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label("Role", systemImage: "tag")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .help("Change role")
                .fixedSize()

                if isEditing {
                    Button {
                        onCancelEdit()
                    } label: {
                        Text("Cancel")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))

                    Button {
                        onSaveEdit()
                    } label: {
                        Label("Save", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(WorkstationPrimaryButtonStyle())
                    .disabled(editingDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else if pendingDelete {
                    Button {
                        onCancelDelete()
                    } label: {
                        Text("Cancel")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))

                    Button {
                        onConfirmDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .help("Confirm delete")
                } else {
                    Button {
                        Clipboard.copy(message.content)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .help("Copy message")

                    Button {
                        onStartEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .help("Edit message")

                    Button {
                        onRequestDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .help("Delete message")
                }
            }

            if isEditing {
                TextEditor(text: $editingDraft)
                    .font(.system(size: 12))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 90)
                    .background(WorkstationTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            } else {
                Text(message.content)
                    .font(.system(size: 12, design: message.role == .agent ? .monospaced : .default))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(roleColor(for: message.role).opacity(pendingDelete ? 0.8 : 0.3), lineWidth: pendingDelete ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private var roleBadge: some View {
        let color = roleColor(for: message.role)
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(message.role.displayName)
                .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                .foregroundStyle(color)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }

    private func roleColor(for role: AgentRunMessageRole) -> Color {
        switch role {
        case .user: return WorkstationTheme.accent
        case .agent: return WorkstationTheme.blue
        case .note: return WorkstationTheme.textMuted
        }
    }
}

private struct AgentRunTranscriptComposer: View {
    @Binding var draftRole: AgentRunMessageRole
    @Binding var draftContent: String
    let onAppend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Add Entry")
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Picker("Role", selection: $draftRole) {
                    ForEach(AgentRunMessageRole.allCases) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 260)

                Spacer()
            }

            TextEditor(text: $draftContent)
                .font(.system(size: 12))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 90)
                .background(WorkstationTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

            HStack {
                Text("Paste agent output, user instructions, or a note.")
                    .font(WorkstationTheme.Fonts.body(10.5))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                Spacer()
                Button {
                    onAppend()
                } label: {
                    Label("Append", systemImage: "plus")
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(WorkstationTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
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
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
