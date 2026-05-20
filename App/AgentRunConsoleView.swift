import SwiftUI

struct AgentRunConsoleView: View {
    @Bindable var appVM: AppViewModel
    let record: AgentRunRecord
    let onDismiss: () -> Void

    @State private var notesDraft: String = ""
    @State private var copyConfirmation: String?

    var body: some View {
        VStack(spacing: 0) {
            AgentRunHeaderView(record: record, onDismiss: onDismiss)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 22) {
                    AgentRunPromptPreviewView(
                        record: record,
                        onCopyPrompt: { copy(record.prompt, label: "Prompt copied") },
                        onCopyCommand: { copy(record.command, label: "Command copied") },
                        onOpenTerminal: { openTerminal() }
                    )

                    AgentRunActionsView(
                        record: record,
                        onUpdateStatus: { status in
                            appVM.updateAgentRunStatus(id: record.id, status: status)
                        }
                    )

                    AgentRunNotesView(
                        notes: $notesDraft,
                        isDirty: notesDraftIsDirty,
                        onSave: { saveNotes() },
                        onRevert: { notesDraft = record.notes ?? "" }
                    )

                    if let copyConfirmation {
                        Text(copyConfirmation)
                            .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                            .foregroundStyle(WorkstationTheme.green)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .frame(minWidth: 560, minHeight: 540)
        .background(WorkstationTheme.surface)
        .onAppear {
            notesDraft = record.notes ?? ""
        }
        .onChange(of: record.id) { _, _ in
            notesDraft = record.notes ?? ""
        }
    }

    private var notesDraftIsDirty: Bool {
        notesDraft != (record.notes ?? "")
    }

    private func copy(_ value: String, label: String) {
        Clipboard.copy(value)
        copyConfirmation = label
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copyConfirmation = nil
        }
    }

    private func openTerminal() {
        appVM.openTerminalForAgentRun(record)
    }

    private func saveNotes() {
        appVM.updateAgentRunNotes(id: record.id, notes: notesDraft)
        copyConfirmation = "Notes saved"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copyConfirmation = nil
        }
    }
}

struct AgentRunHeaderView: View {
    let record: AgentRunRecord
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Agent Run Console")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                statusBadge

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(WorkstationTheme.textMuted)
                .keyboardShortcut(.cancelAction)
                .help("Close console")
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(record.issueID)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textSelection(.enabled)
                Text(record.issueTitle)
                    .font(WorkstationTheme.Fonts.display(18, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
            }

            HStack(spacing: 14) {
                metaItem(label: "Agent", value: record.agentName)
                metaItem(label: "Started", value: record.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let completed = record.completedAt {
                    metaItem(label: "Completed", value: completed.formatted(date: .abbreviated, time: .shortened))
                }
            }

            pathRow
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(WorkstationTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    private var pathRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textMuted)
            Text(record.projectPath.isEmpty ? "No project path recorded" : record.projectPath)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private func metaItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(1)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(record.status.displayName)
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(statusColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch record.status {
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
}

struct AgentRunPromptPreviewView: View {
    let record: AgentRunRecord
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
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 220)
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
