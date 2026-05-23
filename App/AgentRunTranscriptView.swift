import SwiftUI

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
            } else if message.role == .agent {
                let lines = message.content.components(separatedBy: .newlines)
                let displayLines = lines.suffix(300)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(message.content)
                    .font(.system(size: 12, design: .default))
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

struct FlowLayout: Layout {
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
