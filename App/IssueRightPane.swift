import SwiftUI
import AppKit
import Foundation
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

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

private final class CopilotTextView: NSTextView {
    var onPlainReturn: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.isEmpty {
                let text = self.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    onPlainReturn?()
                }
                return
            }
        }
        super.keyDown(with: event)
    }
}

@MainActor
private struct EnterToSendTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 13
    var onSend: () -> Void
    /// Callback with content height for auto-resize
    var onHeightChange: ((CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSend: onSend, onHeightChange: onHeightChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = CopilotTextView()
        textView.onPlainReturn = { context.coordinator.handleReturn() }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont(name: "DM Sans-Medium", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .medium)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = NSColor(WorkstationTheme.textPrimary)
        textView.insertionPointColor = NSColor(WorkstationTheme.accent)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Disable autoresizing mask translation so we can control frame
        textView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSTextView.scrollableTextView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Disable scroll view autoresizing to allow SwiftUI to control height
        scrollView.autoresizingMask = []
        scrollView.verticalScrollElasticity = .none

        // Set initial frame
        let initialHeight: CGFloat = 38
        textView.frame = NSRect(x: 0, y: 0, width: 400, height: initialHeight)
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: initialHeight)

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CopilotTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.onPlainReturn = { context.coordinator.handleReturn() }

        // Update height constraint based on content
        context.coordinator.updateHeight()
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onSend: () -> Void
        var onHeightChange: ((CGFloat) -> Void)?
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?

        // Height constraints
        private var heightConstraint: NSLayoutConstraint?

        // Line height approximation
        private let lineHeight: CGFloat = 20
        private let minHeight: CGFloat = 38
        private let maxHeight: CGFloat = 180 // ~6-8 lines

        init(text: Binding<String>, onSend: @escaping () -> Void, onHeightChange: ((CGFloat) -> Void)?) {
            self.text = text
            self.onSend = onSend
            self.onHeightChange = onHeightChange
        }

        func handleReturn() {
            onSend()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            updateHeight()
        }

        func updateHeight() {
            guard let textView = textView, let scrollView = scrollView else { return }

            // Calculate needed height based on content
            let layoutManager = textView.layoutManager!
            let textContainer = textView.textContainer!
            let textStorage = textView.textStorage!

            // Force layout if needed
            layoutManager.ensureLayout(for: textContainer)

            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
            let boundingRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: textContainer
            )

            // Add padding for text container insets
            let neededHeight = boundingRect.height + 16 // 8 top + 8 bottom padding

            // Clamp between min and max
            let clampedHeight = min(max(neededHeight, minHeight), maxHeight)

            // Update scroll view frame
            var frame = scrollView.frame
            frame.size.height = clampedHeight
            scrollView.frame = frame

            // Also update text view frame to match
            textView.frame = NSRect(x: 0, y: 0, width: frame.size.width, height: clampedHeight)

            // Notify parent of height change
            onHeightChange?(clampedHeight)
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
    @State private var streamingStartTime: Date?
    @State private var excludedContextIDs: Set<String> = []
    @State private var hoveredMessageID: UUID?
    @State private var showingCopilotMenu = false

    private var selected: [BeadIssue] {
        store.selectedIssues()
    }

    private var visibleContextIssues: [BeadIssue] {
        let issues = selected.isEmpty ? Array(store.issues.prefix(50)) : selected
        return issues.filter { !excludedContextIDs.contains($0.id) }
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

    private var modelName: String {
        let settings = appVM.localAISettings
        let name = settings.strongModel
        if let slash = name.lastIndex(of: "/") {
            return String(name[name.index(after: slash)])
        }
        return name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider().overlay(WorkstationTheme.borderSoft)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty && !isSending {
                            emptyStateView
                        }
                        conversationSection
                        if !prdDrafts.isEmpty {
                            prdDraftReviewSection
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(CopilotScrollTarget.bottom)
                    }
                    .padding(16)
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

            inputBar
        }
        .frame(maxHeight: .infinity)
        .background(WorkstationTheme.surface)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WorkstationTheme.accent)
            Text("Copilot")
                .font(WorkstationTheme.Fonts.display(18, weight: .heavy))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Spacer()
            if isSending || isGeneratingPRDDrafts || isCreatingPRDDrafts {
                ProgressView()
                    .controlSize(.small)
                    .tint(WorkstationTheme.accent)
            }
            Button {
                appVM.resetDetailPaneToIssue()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .frame(width: 26, height: 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Close Copilot")
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(WorkstationTheme.textDisabled)
            Text("Ask about your board or selected issues")
                .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
            Text("Shift + Enter for a new line")
                .font(WorkstationTheme.Fonts.body(11))
                .foregroundStyle(WorkstationTheme.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(messages) { message in
                chatBubble(message)
            }
            if isSending, messages.last?.role != .assistant {
                thinkingIndicator
            }
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WorkstationTheme.accent)
                .frame(width: 6, height: 6)
                .modifier(PulsingDotModifier())
            Text("Thinking...")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
        .padding(.vertical, 8)
    }

    private func chatBubble(_ message: CopilotConversationMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            if message.role == .assistant, let duration = message.thinkingDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text("Thought for \(Int(duration))s")
                        .font(WorkstationTheme.Fonts.body(10))
                }
                .foregroundStyle(WorkstationTheme.textSubtle)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(message.roleLabel)
                        .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                        .foregroundStyle(message.roleLabelColor)
                    Spacer(minLength: 0)
                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(WorkstationTheme.Fonts.body(9))
                        .foregroundStyle(WorkstationTheme.textDisabled)
                }

                if message.isStreaming && message.text.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(WorkstationTheme.accent)
                            .frame(width: 6, height: 6)
                            .modifier(PulsingDotModifier())
                        Text("Thinking...")
                            .font(WorkstationTheme.Fonts.body(12))
                            .foregroundStyle(WorkstationTheme.textMuted)
                    }
                } else if message.role == .assistant {
                    MarkdownTextRenderer.copilotText(for: message.text)
                        .font(WorkstationTheme.Fonts.body(13))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                } else {
                    Text(message.text)
                        .font(WorkstationTheme.Fonts.body(13))
                        .foregroundStyle(message.foregroundColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: message.role == .user ? 320 : .infinity, alignment: .leading)
            .background(message.bubbleBackground)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(message.bubbleBorderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))

            if message.role == .assistant && !message.isStreaming && !message.text.isEmpty {
                responseActions(for: message)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private func responseActions(for message: CopilotConversationMessage) -> some View {
        HStack(spacing: 2) {
            Button {
                copyMessageText(message.text)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(WorkstationTheme.textMuted)
            .help("Copy response")

            if messages.last?.id == message.id, lastCopilotRequest != nil {
                Button {
                    regenerateLastResponse()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(WorkstationTheme.textMuted)
                .disabled(isSending || isGeneratingPRDDrafts || isCreatingPRDDrafts)
                .help("Regenerate response")
            }
        }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !visibleContextIssues.isEmpty {
                contextChips
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }

            EnterToSendTextEditor(text: $prompt, onSend: sendPrompt)
                .frame(minHeight: 38, maxHeight: 120)
                .padding(.horizontal, 4)
                .padding(.vertical, visibleContextIssues.isEmpty ? 10 : 4)

            HStack(spacing: 8) {
                // "+" menu button
                Button {
                    showingCopilotMenu.toggle()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(WorkstationTheme.card)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(WorkstationTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingCopilotMenu, arrowEdge: .top) {
                    CopilotMenuPopover(
                        hasPRDText: !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        hasLastRequest: lastCopilotRequest?.prompt.isEmpty == false,
                        onDraftPRD: {
                            showingCopilotMenu = false
                            generatePRDDrafts()
                        },
                        onRegenerate: {
                            showingCopilotMenu = false
                            regenerateLastResponse()
                        }
                    )
                    .frame(width: 200)
                }

                Text(modelName)
                    .font(WorkstationTheme.Fonts.body(10))
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .lineLimit(1)

                Spacer()

                Button {
                    sendPrompt()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canSend ? WorkstationTheme.background : WorkstationTheme.textDisabled)
                        .frame(width: 30, height: 30)
                        .background(canSend ? WorkstationTheme.accent : WorkstationTheme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("Send to Copilot (Enter)")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var contextChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(visibleContextIssues.prefix(10)) { issue in
                    HStack(spacing: 4) {
                        Text(issue.id)
                            .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                            .foregroundStyle(WorkstationTheme.accent)
                        Text(issue.title)
                            .font(WorkstationTheme.Fonts.body(10))
                            .foregroundStyle(WorkstationTheme.textSecondary)
                            .lineLimit(1)
                        Button {
                            excludedContextIDs.insert(issue.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(WorkstationTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WorkstationTheme.hover)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 0.5)
                    )
                }
            }
        }
    }

    private func copyMessageText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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

    private func sendPrompt() {
        let request = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, !isSending else { return }

        prompt = ""
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
        streamingStartTime = Date()
        Task {
            do {
                let stream = try appVM.requestLocalAIResponseStream(
                    for: .copilot(prompt: request, contextIssues: contextIssues)
                )
                let streamingIdx = await MainActor.run { () -> Int in
                    messages.append(.init(role: .assistant, text: "", isStreaming: true))
                    return messages.count - 1
                }
                for try await chunk in stream {
                    await MainActor.run {
                        messages[streamingIdx].text += chunk
                        scrollPulse += 1
                    }
                }
                await MainActor.run {
                    let duration = Date().timeIntervalSince(streamingStartTime ?? Date())
                    messages[streamingIdx].isStreaming = false
                    messages[streamingIdx].thinkingDuration = duration
                    isSending = false
                    streamingStartTime = nil
                }
            } catch {
                await MainActor.run {
                    messages.append(.init(role: .error, text: error.localizedDescription))
                    isSending = false
                    streamingStartTime = nil
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
                }
            } catch {
                await MainActor.run {
                    messages.append(.init(role: .error, text: "Could not draft PRD issues: \(error.localizedDescription)"))
                    isGeneratingPRDDrafts = false
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
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.16)) {
            proxy.scrollTo(CopilotScrollTarget.bottom, anchor: .bottom)
        }
    }
}

private struct PulsingDotModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
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
    var isStreaming: Bool = false
    var thinkingDuration: TimeInterval?

    var roleLabel: String {
        switch role {
        case .user:
            return "You"
        case .assistant:
            return "Copilot"
        case .error:
            return "Error"
        }
    }

    var roleLabelColor: Color {
        switch role {
        case .user:
            return WorkstationTheme.accent
        case .assistant:
            return WorkstationTheme.textSecondary
        case .error:
            return WorkstationTheme.red
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

    var bubbleBackground: Color {
        switch role {
        case .user:
            return WorkstationTheme.accentBg
        case .assistant:
            return WorkstationTheme.card
        case .error:
            return WorkstationTheme.redBg
        }
    }

    var bubbleBorderColor: Color {
        switch role {
        case .user:
            return WorkstationTheme.accentBorder
        case .assistant:
            return WorkstationTheme.border
        case .error:
            return WorkstationTheme.redBorder
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

private struct CopilotMenuPopover: View {
    let hasPRDText: Bool
    let hasLastRequest: Bool
    let onDraftPRD: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("COPILOT")
                .font(WorkstationTheme.Fonts.body(9.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(WorkstationTheme.textSubtle)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            Divider().overlay(WorkstationTheme.borderSoft)

            Button {
                onDraftPRD()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 12))
                    Text("Draft Issue(s) from PRD")
                        .font(WorkstationTheme.Fonts.body(12.5))
                    Spacer()
                    Text("PRD text in input")
                        .font(WorkstationTheme.Fonts.body(10))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
                .foregroundStyle(hasPRDText ? WorkstationTheme.textPrimary : WorkstationTheme.textDisabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(!hasPRDText)
            .help(hasPRDText ? "Generate issue drafts from the PRD text in your input" : "Enter PRD text in the input field first")

            Button {
                onRegenerate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("Regenerate Last Response")
                        .font(WorkstationTheme.Fonts.body(12.5))
                    Spacer()
                }
                .foregroundStyle(hasLastRequest ? WorkstationTheme.textPrimary : WorkstationTheme.textDisabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(!hasLastRequest)
            .help(hasLastRequest ? "Regenerate the last copilot response" : "No previous response to regenerate")
        }
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }
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