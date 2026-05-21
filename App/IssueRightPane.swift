import SwiftUI

struct IssueRightPane: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore
    let issue: BeadIssue?

    var body: some View {
        ZStack {
            switch appVM.detailPaneMode {
            case .issue:
                if let issue {
                    IssueDetailView(appVM: appVM, store: store, issue: issue)
                        .transition(.opacity)
                }
            case .console:
                if let issue {
                    AgentRunConsolePane(appVM: appVM, issue: issue)
                        .transition(.opacity)
                }
            case .bulkAction:
                BulkActionPanel(appVM: appVM, store: store)
                    .transition(.opacity)
            case .copilot:
                WorkflowCopilotPane(appVM: appVM, store: store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: appVM.detailPaneMode)
        .onChange(of: issue?.id) { _, _ in
            guard appVM.detailPaneMode != .bulkAction else { return }
            guard appVM.detailPaneMode != .copilot else { return }
            if !store.hasMultiSelection {
                appVM.resetDetailPaneToIssue()
            }
        }
    }
}

struct WorkflowCopilotPane: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore
    @State private var prompt = ""
    @State private var messages: [CopilotConversationMessage] = []
    @State private var isSending = false
    @FocusState private var promptFocused: Bool

    private var selected: [BeadIssue] {
        store.selectedIssues()
    }

    private var canSend: Bool {
        !isSending && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider().overlay(WorkstationTheme.borderSoft)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    contextSection
                    conversationSection
                }
                .padding(20)
            }

            Divider().overlay(WorkstationTheme.borderSoft)

            inputSection
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(maxHeight: .infinity)
        .background(WorkstationTheme.surface)
        .onAppear { promptFocused = true }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WORKFLOW")
                    .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(WorkstationTheme.textSubtle)
                Text("Copilot")
                    .font(WorkstationTheme.Fonts.display(22, weight: .heavy))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Ask about the current board or selected issues.")
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
            Spacer()
            Button {
                appVM.resetDetailPaneToIssue()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Close Copilot")
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONTEXT")
                .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(WorkstationTheme.textSubtle)

            if selected.isEmpty {
                Text("No issues selected. Copilot will use board-level context.")
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(WorkstationTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            } else {
                ForEach(selected) { issue in
                    HStack(spacing: 8) {
                        Text(issue.id)
                            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                            .foregroundStyle(WorkstationTheme.accent)
                        Text(issue.title)
                            .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WorkstationTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                }
            }
        }
    }

    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(messages.isEmpty ? "READY" : "CONVERSATION")
                .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(WorkstationTheme.textSubtle)

            if messages.isEmpty {
                Text("Type a request below. Existing Local AI entry points remain available while Copilot wiring is expanded.")
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(messages) { message in
                    conversationBubble(message)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.background)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ASK COPILOT")
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(WorkstationTheme.textSubtle)
                Spacer()
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            TextEditor(text: $prompt)
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 82)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(promptFocused ? WorkstationTheme.accent : WorkstationTheme.borderStrong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                .focused($promptFocused)

            HStack(spacing: 10) {
                Text("Uses selected issues as context.")
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .lineLimit(1)
                Spacer()
                Button {
                    sendPrompt()
                } label: {
                    Label(isSending ? "Sending" : "Send", systemImage: "paperplane.fill")
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!canSend)
                .help("Send to Workflow Copilot")
            }
        }
    }

    private func conversationBubble(_ message: CopilotConversationMessage) -> some View {
        Text(message.text)
            .font(WorkstationTheme.Fonts.body(12))
            .foregroundStyle(message.foregroundColor)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .background(message.backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(message.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func sendPrompt() {
        let request = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, !isSending else { return }

        prompt = ""
        isSending = true
        promptFocused = true
        messages.append(.init(role: .user, text: request))

        let contextIssues = selected.isEmpty ? Array(store.issues.prefix(50)) : selected
        Task {
            do {
                let stream = try appVM.requestLocalAIResponseStream(
                    for: .copilot(prompt: request, contextIssues: contextIssues)
                )
                let streamingIdx = await MainActor.run { () -> Int in
                    messages.append(.init(role: .assistant, text: ""))
                    return messages.count - 1
                }
                for try await chunk in stream {
                    await MainActor.run {
                        messages[streamingIdx].text += chunk
                    }
                }
                await MainActor.run {
                    isSending = false
                    promptFocused = true
                }
            } catch {
                await MainActor.run {
                    messages.append(.init(role: .error, text: error.localizedDescription))
                    isSending = false
                    promptFocused = true
                }
            }
        }
    }
}

private struct CopilotConversationMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
        case error
    }

    let id = UUID()
    let role: Role
    var text: String

    var foregroundColor: Color {
        switch role {
        case .user, .assistant:
            return WorkstationTheme.textPrimary
        case .error:
            return WorkstationTheme.red
        }
    }

    var backgroundColor: Color {
        switch role {
        case .user:
            return WorkstationTheme.card
        case .assistant:
            return WorkstationTheme.background
        case .error:
            return WorkstationTheme.red.opacity(0.08)
        }
    }

    var borderColor: Color {
        switch role {
        case .user:
            return WorkstationTheme.accent.opacity(0.45)
        case .assistant:
            return WorkstationTheme.border
        case .error:
            return WorkstationTheme.red.opacity(0.45)
        }
    }
}
