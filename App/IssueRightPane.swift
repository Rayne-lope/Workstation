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
    @State private var prdDrafts: [CopilotIssueDraft] = []
    @State private var isSending = false
    @State private var isGeneratingPRDDrafts = false
    @State private var isCreatingPRDDrafts = false
    @State private var lastCopilotRequest: CopilotRequest?
    @State private var lastPRDText: String?
    @State private var scrollPulse = 0
    @FocusState private var promptFocused: Bool

    private var selected: [BeadIssue] {
        store.selectedIssues()
    }

    private var canSend: Bool {
        !isSending && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canGeneratePRDDrafts: Bool {
        !isSending && !isGeneratingPRDDrafts && !isCreatingPRDDrafts && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedDraftCount: Int {
        prdDrafts.filter(\.isSelected).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider().overlay(WorkstationTheme.borderSoft)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        contextSection
                        conversationSection
                        if !prdDrafts.isEmpty {
                            prdDraftReviewSection
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(CopilotScrollTarget.bottom)
                    }
                    .padding(20)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: prdDrafts.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: scrollPulse) { _, _ in
                    scrollToBottom(proxy)
                }
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
                if isSending || isGeneratingPRDDrafts || isCreatingPRDDrafts {
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
                if let lastCopilotRequest, !lastCopilotRequest.prompt.isEmpty {
                    Button {
                        regenerateLastResponse()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .disabled(isSending || isGeneratingPRDDrafts || isCreatingPRDDrafts)
                    .help("Regenerate the latest Copilot answer using the same prompt and context")
                }
                Button {
                    generatePRDDrafts()
                } label: {
                    Label(isGeneratingPRDDrafts ? "Drafting" : "Draft Issues", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                .disabled(!canGeneratePRDDrafts)
                .help("Use Copilot to draft reviewable Beads issues from the text above")
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

    private var prdDraftReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PRD ISSUE DRAFTS")
                        .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Text("\(selectedDraftCount) of \(prdDrafts.count) selected. Dependency suggestions are preview-only.")
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
                Spacer()
                Button {
                    regeneratePRDDrafts()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                .disabled(isGeneratingPRDDrafts || isCreatingPRDDrafts || lastPRDText == nil)
                .help("Regenerate the PRD issue draft plan from the same PRD text")

                Button {
                    createSelectedDrafts()
                } label: {
                    Label(isCreatingPRDDrafts ? "Creating" : "Create Selected", systemImage: "plus.circle")
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(selectedDraftCount == 0 || isGeneratingPRDDrafts || isCreatingPRDDrafts)
                .help("Create only the selected drafts. Suggested dependencies are not applied.")
            }

            ForEach($prdDrafts) { $draft in
                prdDraftCard($draft)
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

    private func prdDraftCard(_ draft: Binding<CopilotIssueDraft>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Toggle("", isOn: draft.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                TextField("Issue title", text: draft.title)
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .textFieldStyle(.plain)
                Text("Why?")
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.accent)
                    .help(draft.wrappedValue.reasonText)
            }

            TextEditor(text: draft.description)
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 54)
                .padding(8)
                .background(WorkstationTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))

            TextEditor(text: draft.acceptanceCriteria)
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 54)
                .padding(8)
                .background(WorkstationTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                .help("Acceptance criteria")

            HStack(spacing: 10) {
                TextField("type", text: draft.issueType)
                    .font(WorkstationTheme.Fonts.body(11))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(WorkstationTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                Stepper("P\(draft.priority.wrappedValue)", value: draft.priority, in: 0...4)
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .frame(width: 92)
                TextField("labels", text: draft.labelsText)
                    .font(WorkstationTheme.Fonts.body(11))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(WorkstationTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            }

            if !draft.wrappedValue.dependencySuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEPENDENCY SUGGESTIONS")
                        .font(WorkstationTheme.Fonts.body(9.5, weight: .semibold))
                        .tracking(0.7)
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Text(draft.wrappedValue.dependencySuggestions.joined(separator: "\n"))
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(draft.wrappedValue.isSelected ? WorkstationTheme.accent.opacity(0.45) : WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func conversationBubble(_ message: CopilotConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(message.roleLabel)
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                    .foregroundStyle(message.foregroundColor)
                Spacer()
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(WorkstationTheme.Fonts.body(10))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
            Text(message.text.isEmpty ? "Thinking..." : message.text)
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(message.foregroundColor)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        promptFocused = true
        messages.append(.init(role: .user, text: request))

        let contextIssues = selected.isEmpty ? Array(store.issues.prefix(50)) : selected
        lastCopilotRequest = CopilotRequest(prompt: request, contextIssues: contextIssues)
        streamCopilotResponse(prompt: request, contextIssues: contextIssues)
    }

    private func regenerateLastResponse() {
        guard let lastCopilotRequest, !isSending, !isGeneratingPRDDrafts, !isCreatingPRDDrafts else { return }
        streamCopilotResponse(prompt: lastCopilotRequest.prompt, contextIssues: lastCopilotRequest.contextIssues)
    }

    private func streamCopilotResponse(prompt request: String, contextIssues: [BeadIssue]) {
        isSending = true
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
                        scrollPulse += 1
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

    private func generatePRDDrafts() {
        let prd = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prd.isEmpty, !isGeneratingPRDDrafts, !isCreatingPRDDrafts else { return }

        prompt = ""
        lastPRDText = prd
        messages.append(.init(role: .user, text: "Draft Beads issues from this PRD:\n\n\(prd)"))
        runPRDDraftGeneration(prd: prd)
    }

    private func regeneratePRDDrafts() {
        guard let lastPRDText, !isGeneratingPRDDrafts, !isCreatingPRDDrafts else { return }
        runPRDDraftGeneration(prd: lastPRDText)
    }

    private func runPRDDraftGeneration(prd: String) {
        isGeneratingPRDDrafts = true
        Task {
            do {
                let response = try await appVM.requestLocalAIResponse(for: .draftIssuesFromPRD(prd: prd))
                let drafts = try CopilotIssueDraft.parseDrafts(from: response)
                await MainActor.run {
                    prdDrafts = drafts
                    messages.append(.init(role: .assistant, text: "Drafted \(drafts.count) issue\(drafts.count == 1 ? "" : "s"). Review and edit them below, then create only the selected drafts."))
                    isGeneratingPRDDrafts = false
                    promptFocused = true
                }
            } catch {
                await MainActor.run {
                    messages.append(.init(role: .error, text: "Could not draft PRD issues: \(error.localizedDescription)"))
                    isGeneratingPRDDrafts = false
                    promptFocused = true
                }
            }
        }
    }

    private func createSelectedDrafts() {
        let selectedDrafts = prdDrafts.filter(\.isSelected)
        guard !selectedDrafts.isEmpty, !isCreatingPRDDrafts else { return }

        isCreatingPRDDrafts = true
        Task {
            for draft in selectedDrafts {
                await store.createIssue(draft.createInput())
            }
            await MainActor.run {
                prdDrafts.removeAll { draft in
                    selectedDrafts.contains { $0.id == draft.id }
                }
                messages.append(.init(role: .assistant, text: "Created \(selectedDrafts.count) selected issue\(selectedDrafts.count == 1 ? "" : "s"). Dependency suggestions were left as preview-only."))
                isCreatingPRDDrafts = false
                promptFocused = true
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.16)) {
            proxy.scrollTo(CopilotScrollTarget.bottom, anchor: .bottom)
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
    let createdAt = Date()
    let role: Role
    var text: String

    var roleLabel: String {
        switch role {
        case .user:
            return "YOU"
        case .assistant:
            return "COPILOT"
        case .error:
            return "ERROR"
        }
    }

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

private struct CopilotRequest {
    let prompt: String
    let contextIssues: [BeadIssue]
}

private enum CopilotScrollTarget {
    static let bottom = "copilot-bottom"
}

private struct CopilotIssueDraft: Identifiable, Equatable {
    let id = UUID()
    var isSelected = true
    var title: String
    var description: String
    var implementationNotes: String
    var acceptanceCriteria: String
    var issueType: String
    var priority: Int
    var labels: [String]
    var dependencySuggestions: [String]
    var reason: String

    var labelsText: String {
        get { labels.joined(separator: ", ") }
        set {
            labels = newValue
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    var reasonText: String {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedReason.isEmpty {
            return trimmedReason
        }
        let trimmedNotes = implementationNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            return trimmedNotes
        }
        return "Copilot included this draft because it maps to a distinct PRD deliverable."
    }

    func createInput() -> CreateIssueInput {
        CreateIssueInput(
            title: title,
            description: optional(description),
            designNotes: optional(implementationNotes),
            issueType: optional(issueType),
            priority: priority,
            acceptanceCriteria: optional(acceptanceCriteria),
            labels: labels.isEmpty ? nil : labels
        )
    }

    static func parseDrafts(from raw: String) throws -> [CopilotIssueDraft] {
        let json = stripMarkdownFence(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = json.data(using: .utf8) else {
            throw CopilotIssueDraftParseError.unreadableResponse
        }
        let object = try JSONSerialization.jsonObject(with: data)
        let dictionaries: [[String: Any]]
        if let array = object as? [[String: Any]] {
            dictionaries = array
        } else if let dictionary = object as? [String: Any],
                  let nested = (dictionary["issues"] ?? dictionary["drafts"]) as? [[String: Any]] {
            dictionaries = nested
        } else if let dictionary = object as? [String: Any] {
            dictionaries = [dictionary]
        } else {
            throw CopilotIssueDraftParseError.unsupportedShape
        }

        let drafts = dictionaries.compactMap(parseDraft)
        guard !drafts.isEmpty else {
            throw CopilotIssueDraftParseError.noDrafts
        }
        return drafts
    }

    private static func parseDraft(_ dictionary: [String: Any]) -> CopilotIssueDraft? {
        guard let title = stringValue(dictionary, keys: ["title", "name"]),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        return CopilotIssueDraft(
            title: title,
            description: stringValue(dictionary, keys: ["description", "summary"]) ?? "",
            implementationNotes: stringValue(dictionary, keys: ["implementation_notes", "implementationNotes", "design_notes", "designNotes"]) ?? "",
            acceptanceCriteria: stringArrayValue(dictionary, keys: ["acceptance_criteria", "acceptanceCriteria", "ac"]).joined(separator: "\n"),
            issueType: stringValue(dictionary, keys: ["issue_type", "issueType", "type"]) ?? "feature",
            priority: intValue(dictionary, keys: ["priority"]) ?? 2,
            labels: stringArrayValue(dictionary, keys: ["labels", "tags"]),
            dependencySuggestions: stringArrayValue(dictionary, keys: ["dependency_suggestions", "dependencySuggestions", "dependencies"]),
            reason: stringValue(dictionary, keys: ["reason", "why", "rationale"]) ?? ""
        )
    }

    private static func stringValue(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if let value = dictionary[key] {
                let rendered = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
                if !rendered.isEmpty, rendered != "[]" { return rendered }
            }
        }
        return nil
    }

    private static func stringArrayValue(_ dictionary: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let values = dictionary[key] as? [String] {
                return values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
            if let value = dictionary[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return [] }
                return trimmed
                    .split(whereSeparator: \.isNewline)
                    .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "-* ").union(.whitespacesAndNewlines)) }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }

    private static func intValue(_ dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dictionary[key] as? Int {
                return min(max(value, 0), 4)
            }
            if let value = dictionary[key] as? Double {
                return min(max(Int(value), 0), 4)
            }
            if let value = dictionary[key] as? String,
               let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return min(max(parsed, 0), 4)
            }
        }
        return nil
    }

    private static func stripMarkdownFence(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        var lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if !lines.isEmpty {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private func optional(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum CopilotIssueDraftParseError: LocalizedError {
    case unreadableResponse
    case unsupportedShape
    case noDrafts

    var errorDescription: String? {
        switch self {
        case .unreadableResponse:
            return "The AI response could not be read."
        case .unsupportedShape:
            return "The AI response was not a JSON array or issue draft object."
        case .noDrafts:
            return "The AI response did not include any usable issue drafts."
        }
    }
}
