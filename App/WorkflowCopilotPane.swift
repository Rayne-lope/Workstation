import SwiftUI
import AppKit
import Foundation
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

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
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  let textStorage = textView.textStorage else {
                return
            }

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
    @State private var inputHeight: CGFloat = 38
    @State private var isPlusHovered = false
    @State private var isSendHovered = false

    private var currentIssueID: String {
        store.selectedIssue?.id ?? "global"
    }

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
        .onAppear {
            loadHistory()
        }
        .onChange(of: currentIssueID) { _, _ in
            loadHistory()
        }
        .onChange(of: messages) { _, newMessages in
            if !newMessages.contains(where: { $0.isStreaming }) {
                appVM.copilotTranscriptStore.save(messages: newMessages, forIssueID: currentIssueID)
            }
        }
    }

    private func loadHistory() {
        self.messages = appVM.copilotTranscriptStore.messages(forIssueID: currentIssueID)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WorkstationTheme.accent)
            Text("Copilot")
                .font(WorkstationTheme.Fonts.display(18, weight: .heavy))
                .foregroundStyle(WorkstationTheme.textPrimary)
            
            if appVM.sessionPromptTokens > 0 || appVM.sessionCompletionTokens > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "gauge")
                        .font(.system(size: 9))
                    Text("Session: \(appVM.sessionPromptTokens + appVM.sessionCompletionTokens) tkn")
                }
                .font(WorkstationTheme.Fonts.body(9, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(WorkstationTheme.cardAlt)
                .cornerRadius(WorkstationTheme.Radius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                )
            }
            
            Spacer()
            if isSending || isGeneratingPRDDrafts || isCreatingPRDDrafts {
                ProgressView()
                    .controlSize(.small)
                    .tint(WorkstationTheme.accent)
            }
            if !messages.isEmpty {
                Button {
                    appVM.copilotTranscriptStore.clear(forIssueID: currentIssueID)
                    self.messages = []
                    appVM.sessionPromptTokens = 0
                    appVM.sessionCompletionTokens = 0
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Clear Chat")
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
            ForEach($messages) { $message in
                chatBubble(message: $message)
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

    private func chatBubble(message: Binding<CopilotConversationMessage>) -> some View {
        let msg = message.wrappedValue
        return VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
            if msg.role == .assistant, let duration = msg.thinkingDuration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text("Thought for \(Int(duration))s")
                        .font(WorkstationTheme.Fonts.body(10))
                }
                .foregroundStyle(WorkstationTheme.textSubtle)
            }

            if msg.role == .error && msg.isNetworkOffline {
                OfflineErrorCard(message: msg) {
                    retryResponse(for: msg)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(msg.roleLabel)
                            .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                            .foregroundStyle(msg.roleLabelColor)
                        Spacer(minLength: 0)
                        Text(msg.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(WorkstationTheme.Fonts.body(9))
                            .foregroundStyle(WorkstationTheme.textDisabled)
                    }

                    if msg.isStreaming && msg.text.isEmpty {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(WorkstationTheme.accent)
                                .frame(width: 6, height: 6)
                                .modifier(PulsingDotModifier())
                            Text("Thinking...")
                                .font(WorkstationTheme.Fonts.body(12))
                                .foregroundStyle(WorkstationTheme.textMuted)
                        }
                    } else if msg.role == .assistant {
                        if msg.isPlan {
                            planCardView(message: message)
                        } else if msg.isAgentLaunch {
                            agentLaunchCardView(message: message)
                        } else if let planError = msg.planError {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(WorkstationTheme.red)
                                    Text("Could not parse plan: \(planError). Falling back to response text:")
                                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                                        .foregroundStyle(WorkstationTheme.red)
                                }
                                
                                formattedMessageText(for: msg.text)
                            }
                        } else {
                            formattedMessageText(for: msg.text)
                        }
                    } else {
                        Text(msg.text)
                            .font(WorkstationTheme.Fonts.body(13))
                            .foregroundStyle(msg.foregroundColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: msg.role == .user ? 320 : .infinity, alignment: .leading)
                .background(msg.bubbleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                        .stroke(msg.bubbleBorderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))

                if msg.role == .assistant && !msg.isStreaming && !msg.text.isEmpty && !msg.isPlan {
                    responseActions(for: msg)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
    }

    private func retryResponse(for message: CopilotConversationMessage) {
        messages.removeAll { $0.id == message.id }
        regenerateLastResponse()
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

            EnterToSendTextEditor(text: $prompt, onSend: sendPrompt, onHeightChange: { height in
                self.inputHeight = height
            })
            .frame(height: inputHeight)
            .padding(.horizontal, 4)
                .padding(.vertical, visibleContextIssues.isEmpty ? 10 : 4)

            HStack(spacing: 8) {
                // "+" menu button
                Button {
                    showingCopilotMenu.toggle()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isPlusHovered || showingCopilotMenu ? WorkstationTheme.accent : WorkstationTheme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(isPlusHovered || showingCopilotMenu ? WorkstationTheme.active : WorkstationTheme.inputBg)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isPlusHovered || showingCopilotMenu ? WorkstationTheme.accent.opacity(0.5) : WorkstationTheme.border, lineWidth: 1)
                        )
                        .scaleEffect(isPlusHovered ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: isPlusHovered)
                        .animation(.easeOut(duration: 0.15), value: showingCopilotMenu)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isPlusHovered = hovering
                }
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(canSend ? WorkstationTheme.background : WorkstationTheme.textDisabled)
                        .frame(width: 30, height: 30)
                        .background(canSend ? (isSendHovered ? WorkstationTheme.accentHover : WorkstationTheme.accent) : WorkstationTheme.inputBg)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(canSend ? Color.clear : WorkstationTheme.border, lineWidth: 1)
                        )
                        .scaleEffect(isSendHovered && canSend ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: isSendHovered)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .onHover { hovering in
                    isSendHovered = hovering
                }
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
                    .help(issue.title)
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
        VStack(alignment: .leading, spacing: 0) {
            // Header Row (Always Visible)
            HStack(alignment: .center, spacing: 8) {
                // Left Vertical Priority Accent Stripe
                RoundedRectangle(cornerRadius: 2)
                    .fill(priorityColor(for: draft.wrappedValue.priority))
                    .frame(width: 4, height: 18)

                Toggle("", isOn: draft.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                // Mini Pill Priority Badge
                Text("P\(draft.wrappedValue.priority)")
                    .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                    .foregroundStyle(priorityColor(for: draft.wrappedValue.priority))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(priorityColor(for: draft.wrappedValue.priority).opacity(0.12))
                    .clipShape(Capsule())

                TextField("Issue title", text: draft.title)
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .textFieldStyle(.plain)

                Spacer()

                Text("Why?")
                    .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                    .foregroundStyle(WorkstationTheme.accent)
                    .help(draft.wrappedValue.reasonText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(WorkstationTheme.accentBg)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(WorkstationTheme.accentBorder, lineWidth: 0.5)
                    )

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        draft.wrappedValue.isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: draft.wrappedValue.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(WorkstationTheme.hover)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            // Collapsible Content Body
            if draft.wrappedValue.isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().overlay(WorkstationTheme.borderSoft)
                        .padding(.vertical, 4)

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DESCRIPTION")
                            .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(WorkstationTheme.textSubtle)
                        
                        TextEditor(text: draft.description)
                            .font(WorkstationTheme.Fonts.body(12))
                            .foregroundStyle(WorkstationTheme.textSecondary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 54, maxHeight: 100)
                            .padding(8)
                            .background(WorkstationTheme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                                    .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                            )
                    }

                    // Acceptance Criteria
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ACCEPTANCE CRITERIA")
                            .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(WorkstationTheme.textSubtle)
                        
                        TextEditor(text: draft.acceptanceCriteria)
                            .font(WorkstationTheme.Fonts.body(12))
                            .foregroundStyle(WorkstationTheme.textSecondary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 54, maxHeight: 100)
                            .padding(8)
                            .background(WorkstationTheme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                                    .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                            )
                    }

                    // Multi-field metadata rows
                    HStack(alignment: .center, spacing: 12) {
                        // Issue Type
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TYPE")
                                .font(WorkstationTheme.Fonts.body(9, weight: .semibold))
                                .foregroundStyle(WorkstationTheme.textSubtle)
                            
                            TextField("type", text: draft.issueType)
                                .font(WorkstationTheme.Fonts.body(11))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(WorkstationTheme.inputBg)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                                )
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Custom Capsule Stepper
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PRIORITY")
                                .font(WorkstationTheme.Fonts.body(9, weight: .semibold))
                                .foregroundStyle(WorkstationTheme.textSubtle)
                            
                            CapsuleStepper(value: draft.priority, range: 0...4)
                        }

                        // Labels
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LABELS")
                                .font(WorkstationTheme.Fonts.body(9, weight: .semibold))
                                .foregroundStyle(WorkstationTheme.textSubtle)
                            
                            TextField("labels", text: draft.labelsText)
                                .font(WorkstationTheme.Fonts.body(11))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(WorkstationTheme.inputBg)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if !draft.wrappedValue.dependencySuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(WorkstationTheme.blue)
                                Text("DEPENDENCY SUGGESTIONS")
                                    .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                                    .tracking(0.7)
                                    .foregroundStyle(WorkstationTheme.blue)
                            }
                            Text(draft.wrappedValue.dependencySuggestions.joined(separator: "\n"))
                                .font(WorkstationTheme.Fonts.body(11))
                                .foregroundStyle(WorkstationTheme.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WorkstationTheme.blueBg)
                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                                .stroke(WorkstationTheme.blueBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(WorkstationTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous)
                .stroke(draft.wrappedValue.isSelected ? WorkstationTheme.accent.opacity(0.5) : WorkstationTheme.borderSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(draft.wrappedValue.isSelected ? 0.03 : 0.01), radius: 4, x: 0, y: 2)
    }

    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 0, 1:
            return WorkstationTheme.accent
        case 2:
            return WorkstationTheme.blue
        default:
            return WorkstationTheme.textMuted
        }
    }

    private struct CapsuleStepper: View {
        @Binding var value: Int
        let range: ClosedRange<Int>

        var body: some View {
            HStack(spacing: 0) {
                Button {
                    if value > range.lowerBound {
                        value -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(value > range.lowerBound ? WorkstationTheme.textPrimary : WorkstationTheme.textDisabled)
                        .frame(width: 24, height: 26)
                        .background(WorkstationTheme.hover)
                }
                .buttonStyle(.plain)
                .disabled(value <= range.lowerBound)

                Text("P\(value)")
                    .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .frame(width: 32)
                    .multilineTextAlignment(.center)

                Button {
                    if value < range.upperBound {
                        value += 1
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(value < range.upperBound ? WorkstationTheme.textPrimary : WorkstationTheme.textDisabled)
                        .frame(width: 24, height: 26)
                        .background(WorkstationTheme.hover)
                }
                .buttonStyle(.plain)
                .disabled(value >= range.upperBound)
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
            )
        }
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

    private func looksLikeMutationRequest(_ text: String) -> Bool {
        let lower = text.lowercased()
        
        // Specific mutation phrases / commands
        let actionPhrases = [
            // Close / Tutup
            "close issue", "tutup issue", "selesaikan issue", "close ini", "tutup ini", "selesaikan ini",
            "tutup bead", "close bead",
            
            // Priority
            "ubah priority", "ganti priority", "set priority", "priority jd", "priority jadi",
            "ubah prio", "ganti prio", "set prio", "prio jd", "prio jadi",
            "set p0", "set p1", "set p2", "set p3", "set p4",
            "jadikan p0", "jadikan p1", "jadikan p2", "jadikan p3", "jadikan p4",
            
            // Status / Progress
            "ubah status", "ganti status", "set status", "status jadi", "status jd",
            "ubah progress", "ganti progress", "set progress", "progress jadi", "progress jd",
            "pindahkan ke", "pindah ke", "geser ke", "pindah kolom", "geser kolom",
            
            // Assign / Tugaskan
            "assign ke", "tugaskan ke", "tunjuk ke", "assign me", "assign saya", "tugaskan saya",
            
            // Create / Buat Issue
            "buat issue", "tambah issue", "create issue", "bikin issue", "buat task", "tambah task",
            "create task", "bikin task", "buat bead", "tambah bead", "create bead", "bikin bead"
        ]
        
        if actionPhrases.contains(where: { lower.contains($0) }) {
            return true
        }
        
        // Single strong action words, but only when accompanied by "issue", "bead", or "task", OR if they are exact command words.
        let strongVerbs = ["close", "tutup", "selesaikan", "assign", "tugaskan", "create", "pindahkan"]
        let contextWords = ["issue", "bead", "task", "tiket", "ini", "itu"]
        
        for verb in strongVerbs {
            if lower.contains(verb) {
                // If it's used with issue/task/bead context
                if contextWords.contains(where: { lower.contains($0) }) {
                    return true
                }
            }
        }
        
        // Direct issue ID + state changes or close
        // E.g., "close workstation-123" or "workstation-123 to in progress"
        if let regex = try? NSRegularExpression(pattern: "workstation-\\w+"),
           regex.firstMatch(in: lower, options: [], range: NSRange(location: 0, length: lower.utf16.count)) != nil {
            let actionWords = ["close", "tutup", "selesai", "pindah", "geser", "status", "priority", "prio", "assign", "tugaskan"]
            if actionWords.contains(where: { lower.contains($0) }) {
                return true
            }
        }
        
        return false
    }

    private func cleanJSONString(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func streamCopilotResponse(prompt request: String, contextIssues: [BeadIssue]) {
        if looksLikeAgentLaunchRequest(request) {
            let targetIssue = contextIssues.first ?? store.issues.first
            let matchedProfile = detectProfile(matching: request)
            let defaultProfile = appVM.agentProfileStore.profiles.first ?? AgentProfile.builtInProfiles[0]
            let chosenProfile = matchedProfile ?? defaultProfile

            let preflight = AgentLaunchPreflight(
                issueId: targetIssue?.id ?? "",
                selectedProfileId: chosenProfile.id,
                useFastModel: false,
                extraPrompt: "",
                autoClaim: chosenProfile.shouldClaimIssue,
                autoMerge: chosenProfile.shouldCloseIssue,
                requestReview: chosenProfile.shouldRequestHumanReview
            )
            let msg = CopilotConversationMessage(
                role: .assistant,
                text: "I've prepared the pre-flight configuration for running the agent:",
                isAgentLaunch: true,
                agentLaunch: preflight
            )
            messages.append(msg)
            isSending = false
            return
        }

        isSending = true
        streamingStartTime = Date()
        Task {
            do {
                let isMutation = looksLikeMutationRequest(request)
                let actionToRequest: LocalAIAction = isMutation ?
                    .copilotPlan(prompt: request, contextIssues: contextIssues) :
                    .copilot(prompt: request, contextIssues: contextIssues)
                
                let stream = try appVM.requestLocalAIResponseStream(for: actionToRequest)
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
                    
                    if isMutation {
                        let rawText = messages[streamingIdx].text
                        let cleaned = cleanJSONString(rawText)
                        if let data = cleaned.data(using: .utf8) {
                            do {
                                let plan = try JSONDecoder().decode(WorkflowPlan.self, from: data)
                                let activeActions = plan.actions.filter { $0.kind != "skip" }
                                if activeActions.isEmpty {
                                    messages[streamingIdx].isPlan = false
                                    messages[streamingIdx].text = plan.summary
                                } else {
                                    messages[streamingIdx].plan = plan
                                    messages[streamingIdx].isPlan = true
                                }
                            } catch {
                                messages[streamingIdx].planError = error.localizedDescription
                            }
                        }
                    }
                    
                    isSending = false
                    streamingStartTime = nil
                }
            } catch {
                await MainActor.run {
                    var isOffline = false
                    let errStr = error.localizedDescription
                    
                    if let serviceErr = error as? OpenCodeServiceError {
                        switch serviceErr {
                        case .unreachable:
                            isOffline = true
                        default:
                            break
                        }
                    } else if let connErr = error as? LocalAIConnectionError {
                        switch connErr {
                        case .unreachable:
                            isOffline = true
                        default:
                            break
                        }
                    } else if error is URLError {
                        isOffline = true
                    } else {
                        let lower = errStr.lowercased()
                        if lower.contains("offline") || lower.contains("unreachable") || lower.contains("connection") || lower.contains("timed out") || lower.contains("network") {
                            isOffline = true
                        }
                    }
                    
                    messages.append(.init(role: .error, text: errStr, isNetworkOffline: isOffline))
                    isSending = false
                    streamingStartTime = nil
                }
            }
        }
    }

    @ViewBuilder
    private func planCardView(message: Binding<CopilotConversationMessage>) -> some View {
        let msg = message.wrappedValue
        if let plan = msg.plan {
            VStack(alignment: .leading, spacing: 12) {
                Text(plan.summary)
                    .font(WorkstationTheme.Fonts.body(13, weight: .bold))
                    .foregroundStyle(WorkstationTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(WorkstationTheme.borderSoft)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.actions.indices, id: \.self) { idx in
                        WorkflowActionRow(
                            action: plan.actions[idx],
                            isExecuted: msg.isExecuted,
                            isSelected: Binding(
                                get: { message.plan.wrappedValue?.actions[idx].isSelected ?? true },
                                set: { message.plan.wrappedValue?.actions[idx].isSelected = $0 }
                            )
                        )
                    }
                }

                if let warnings = plan.warnings, !warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(WorkstationTheme.orange)
                            Text("Risks & Warnings")
                                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                                .foregroundStyle(WorkstationTheme.orange)
                        }
                        .padding(.bottom, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(warnings, id: \.self) { warning in
                                HStack(alignment: .top, spacing: 4) {
                                    Text("•")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(WorkstationTheme.orange)
                                    Text(warning)
                                        .font(WorkstationTheme.Fonts.body(10.5))
                                        .foregroundStyle(WorkstationTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WorkstationTheme.orangeBg)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.orangeBorder, lineWidth: 1)
                    )
                }

                Divider().overlay(WorkstationTheme.borderSoft)

                if msg.isExecuted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(WorkstationTheme.green)
                        Text("Applied Successfully")
                            .font(WorkstationTheme.Fonts.body(12.5, weight: .bold))
                            .foregroundStyle(WorkstationTheme.green)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(WorkstationTheme.greenBg)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.greenBorder, lineWidth: 1)
                    )
                    .padding(.top, 4)
                } else {
                    HStack {
                        Button {
                            message.wrappedValue.plan = nil
                            message.wrappedValue.isPlan = false
                        } label: {
                            Text("Cancel")
                        }
                        .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                        .disabled(msg.isExecuting)

                        Spacer()

                        Button {
                            executePlan(message: message)
                        } label: {
                            if msg.isExecuting {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                    Text("Executing...")
                                }
                            } else {
                                Text("Proceed")
                            }
                        }
                        .buttonStyle(WorkstationPrimaryButtonStyle())
                        .disabled(msg.isExecuting || !(plan.actions.contains { $0.isSelected ?? true }))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(WorkstationTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous)
                    .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
    }

    private struct WorkflowActionRow: View {
        let action: WorkflowAction
        let isExecuted: Bool
        @Binding var isSelected: Bool
        @State private var isHovered = false

        var body: some View {
            let theme = actionTheme(for: action.kind, isSelected: isSelected)
            HStack(alignment: .top, spacing: 8) {
                if !isExecuted {
                    Toggle("", isOn: $isSelected)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .padding(.top, 2)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(WorkstationTheme.green)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        actionIcon(for: action.kind)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.iconColor)

                        if let issueId = action.issueId {
                            Text(issueId)
                                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                                .foregroundStyle(isSelected ? WorkstationTheme.accent : WorkstationTheme.textMuted)
                        }
                        
                        Text(actionDescription(for: action))
                            .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                            .foregroundStyle(isSelected ? WorkstationTheme.textPrimary : WorkstationTheme.textDisabled)
                    }

                    if let reason = action.reason {
                        Text(reason)
                            .font(WorkstationTheme.Fonts.body(10))
                            .foregroundStyle(isSelected ? WorkstationTheme.textSecondary : WorkstationTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
            .padding(8)
            .background(theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
            .scaleEffect(isHovered && !isExecuted ? 1.015 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }

        private func actionIcon(for kind: String) -> Image {
            switch kind {
            case "close_with_reason":
                return Image(systemName: "checkmark.circle")
            case "update_field":
                return Image(systemName: "pencil.circle")
            case "create_issue":
                return Image(systemName: "plus.circle")
            case "skip":
                return Image(systemName: "slash.circle")
            default:
                return Image(systemName: "gearshape")
            }
        }

        private func actionDescription(for action: WorkflowAction) -> String {
            switch action.kind {
            case "close_with_reason":
                return "Close issue"
            case "update_field":
                if let field = action.field, let value = action.value {
                    return "Set \(field) to '\(value)'"
                }
                return "Update field"
            case "create_issue":
                if let title = action.title {
                    return "Create issue: \(title)"
                }
                return "Create issue"
            case "skip":
                return "Skip action"
            default:
                return "Modify issue"
            }
        }

        private struct ActionTheme {
            let bg: Color
            let border: Color
            let iconColor: Color
        }

        private func actionTheme(for kind: String, isSelected: Bool) -> ActionTheme {
            guard isSelected else {
                return ActionTheme(
                    bg: WorkstationTheme.cardAlt,
                    border: WorkstationTheme.borderSoft,
                    iconColor: WorkstationTheme.textDisabled
                )
            }
            switch kind {
            case "close_with_reason":
                return ActionTheme(bg: WorkstationTheme.greenBg, border: WorkstationTheme.greenBorder, iconColor: WorkstationTheme.green)
            case "update_field":
                return ActionTheme(bg: WorkstationTheme.blueBg, border: WorkstationTheme.blueBorder, iconColor: WorkstationTheme.blue)
            case "create_issue":
                return ActionTheme(bg: WorkstationTheme.purpleBg, border: WorkstationTheme.purpleBorder, iconColor: WorkstationTheme.purple)
            default:
                return ActionTheme(bg: WorkstationTheme.accentBg, border: WorkstationTheme.accentBorder, iconColor: WorkstationTheme.accent)
            }
        }
    }

    private func executePlan(message: Binding<CopilotConversationMessage>) {
        guard let plan = message.wrappedValue.plan, !message.wrappedValue.isExecuting else { return }

        message.wrappedValue.isExecuting = true
        Task {
            let approvedActions = plan.actions.filter { $0.isSelected ?? true }
            for action in approvedActions {
                guard let issueId = action.issueId else { continue }
                
                switch action.kind {
                case "close_with_reason":
                    await store.close(id: issueId, reason: action.reason ?? action.draftReason ?? "Closed via Copilot")
                    
                case "update_field":
                    guard let field = action.field, let value = action.value else { continue }
                    if field == "priority" {
                        if let priorityVal = Int(value) {
                            await store.update(id: issueId, UpdateIssueInput(priority: priorityVal))
                        }
                    } else if field == "status" {
                        await store.update(id: issueId, UpdateIssueInput(status: value))
                    } else if field == "assignee" {
                        await store.update(id: issueId, UpdateIssueInput(assignee: value))
                    } else if field == "title" {
                        await store.update(id: issueId, UpdateIssueInput(title: value))
                    } else if field == "description" {
                        await store.update(id: issueId, UpdateIssueInput(description: value))
                    }
                    
                case "create_issue":
                    if let title = action.title {
                        let input = CreateIssueInput(
                            title: title,
                            description: action.description ?? "",
                            issueType: action.issueType ?? "feature",
                            priority: action.priority ?? 2,
                            labels: []
                        )
                        await store.createIssue(input)
                    }
                    
                default:
                    break
                }
            }
            
            await store.reload()
            
            await MainActor.run {
                message.wrappedValue.isExecuting = false
                message.wrappedValue.isExecuted = true
                
                messages.append(.init(role: .assistant, text: "Executed \(approvedActions.count) plan action(s) successfully! The Kanban board has been updated."))
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

    private func looksLikeAgentLaunchRequest(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = [
            "launch", "jalankan", "jalanin", "kerjakan", "run agent", 
            "executor", "spec writer", "reviewer", "tester", "pre-flight"
        ]
        return keywords.contains { lower.contains($0) }
    }

    private func detectProfile(matching request: String) -> AgentProfile? {
        let lower = request.lowercased()
        let profiles = appVM.agentProfileStore.profiles
        
        if lower.contains("spec writer") || lower.contains("spec") {
            if let p = profiles.first(where: { $0.role == .specWriter }) {
                return p
            }
        }
        if lower.contains("reviewer") || lower.contains("review") {
            if let p = profiles.first(where: { $0.role == .reviewer }) {
                return p
            }
        }
        if lower.contains("tester") || lower.contains("test") {
            if let p = profiles.first(where: { $0.role == .tester }) {
                return p
            }
        }
        
        if lower.contains("claude") {
            if let p = profiles.first(where: { $0.name.lowercased().contains("claude") }) {
                return p
            }
        }
        if lower.contains("codex") {
            if let p = profiles.first(where: { $0.name.lowercased().contains("codex") }) {
                return p
            }
        }
        if lower.contains("kimi") {
            if let p = profiles.first(where: { $0.name.lowercased().contains("kimi") }) {
                return p
            }
        }
        if lower.contains("zhipu") {
            if let p = profiles.first(where: { $0.name.lowercased().contains("zhipu") }) {
                return p
            }
        }
        if lower.contains("deepseek") {
            if let p = profiles.first(where: { $0.name.lowercased().contains("deepseek") }) {
                return p
            }
        }
        if lower.contains("gemini") {
            if let p = profiles.first(where: { $0.name.lowercased().contains("gemini") }) {
                return p
            }
        }
        if lower.contains("minimax") {
            if let p = profiles.first(where: { $0.name.lowercased().contains("minimax") }) {
                return p
            }
        }

        if let p = profiles.first(where: { $0.role == .codingExecutor }) {
            return p
        }
        return profiles.first
    }

    @ViewBuilder
    private func agentLaunchCardView(message: Binding<CopilotConversationMessage>) -> some View {
        let msg = message.wrappedValue
        if let preflight = msg.agentLaunch {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WorkstationTheme.accent)
                    Text("🚀 Agent Pre-flight Launch Setup")
                        .font(WorkstationTheme.Fonts.body(13, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                }
                .padding(.bottom, 2)

                Divider().overlay(WorkstationTheme.borderSoft)

                HStack(spacing: 8) {
                    Text("Target Issue:")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(WorkstationTheme.accent)
                        Text(preflight.issueId.isEmpty ? "No issue selected" : preflight.issueId)
                            .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                            .foregroundStyle(WorkstationTheme.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WorkstationTheme.accentBg)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(WorkstationTheme.accentBorder, lineWidth: 1)
                    )
                    
                    if let issueObj = store.issues.first(where: { $0.id == preflight.issueId }) {
                        Text(issueObj.title)
                            .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                            .foregroundStyle(WorkstationTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("AGENT PROFILE")
                        .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    
                    HStack {
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(WorkstationTheme.accent)
                        
                        Picker("", selection: Binding(
                            get: { preflight.selectedProfileId },
                            set: { newId in
                                message.wrappedValue.agentLaunch?.selectedProfileId = newId
                                if let profile = appVM.agentProfileStore.profiles.first(where: { $0.id == newId }) {
                                    message.wrappedValue.agentLaunch?.autoClaim = profile.shouldClaimIssue
                                    message.wrappedValue.agentLaunch?.autoMerge = profile.shouldCloseIssue
                                    message.wrappedValue.agentLaunch?.requestReview = profile.shouldRequestHumanReview
                                }
                            }
                        )) {
                            ForEach(appVM.agentProfileStore.profiles) { profile in
                                Text("\(profile.name) (\(profile.role.rawValue))")
                                    .tag(profile.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(WorkstationTheme.cardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("MODEL SELECTION")
                        .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    
                    Picker("", selection: Binding(
                        get: { preflight.useFastModel ? 1 : 0 },
                        set: { message.wrappedValue.agentLaunch?.useFastModel = ($0 == 1) }
                    )) {
                        Text("Strong Model").tag(0)
                        Text("Fast Model").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(4)
                    .background(WorkstationTheme.cardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("SETTINGS")
                        .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(WorkstationTheme.textSubtle)

                    VStack(spacing: 8) {
                        AgentSettingCard(
                            systemImage: "person.badge.key.fill",
                            title: "Auto-Claim Issue",
                            description: "Assign issue to agent automatically on launch",
                            isOn: Binding(
                                get: { preflight.autoClaim },
                                set: { message.wrappedValue.agentLaunch?.autoClaim = $0 }
                            )
                        )
                        
                        AgentSettingCard(
                            systemImage: "arrow.triangle.merge",
                            title: "Auto-Merge & Close",
                            description: "Automatically merge worktree changes and close on success",
                            isOn: Binding(
                                get: { preflight.autoMerge },
                                set: { message.wrappedValue.agentLaunch?.autoMerge = $0 }
                            )
                        )
                        
                        AgentSettingCard(
                            systemImage: "checkmark.shield.fill",
                            title: "Human Review Required",
                            description: "Ask for authorization before merging or staging code changes",
                            isOn: Binding(
                                get: { preflight.requestReview },
                                set: { message.wrappedValue.agentLaunch?.requestReview = $0 }
                            )
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("ADDITIONAL INSTRUCTIONS")
                        .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(WorkstationTheme.textSubtle)

                    TextEditor(text: Binding(
                        get: { preflight.extraPrompt },
                        set: { message.wrappedValue.agentLaunch?.extraPrompt = $0 }
                    ))
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 48, maxHeight: 80)
                    .padding(8)
                    .background(WorkstationTheme.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                    )
                }

                Divider().overlay(WorkstationTheme.borderSoft)

                HStack {
                    Button {
                        if let index = messages.firstIndex(where: { $0.id == msg.id }) {
                            messages.remove(at: index)
                        }
                    } label: {
                        Text("Cancel")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))

                    Spacer()

                    AgentLaunchButton(
                        action: {
                            executeAgentLaunch(preflight: preflight, messageId: msg.id)
                        },
                        disabled: preflight.issueId.isEmpty
                    )
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(WorkstationTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
    }

    private struct AgentSettingCard: View {
        let systemImage: String
        let title: String
        let description: String
        @Binding var isOn: Bool
        @State private var isHovered = false

        var body: some View {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isOn.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isOn ? WorkstationTheme.accent : WorkstationTheme.textMuted)
                        
                        Text(title)
                            .font(WorkstationTheme.Fonts.body(11.5, weight: .bold))
                            .foregroundStyle(isOn ? WorkstationTheme.textPrimary : WorkstationTheme.textSecondary)
                        
                        Spacer()
                        
                        Circle()
                            .fill(isOn ? WorkstationTheme.accent : Color.clear)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(isOn ? WorkstationTheme.accent : WorkstationTheme.borderStrong, lineWidth: 1)
                            )
                    }

                    Text(description)
                        .font(WorkstationTheme.Fonts.body(9.5))
                        .foregroundStyle(isOn ? WorkstationTheme.textSecondary : WorkstationTheme.textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isOn ? WorkstationTheme.hover : WorkstationTheme.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(isOn ? WorkstationTheme.accent.opacity(0.3) : WorkstationTheme.borderSoft, lineWidth: 1)
                )
                .scaleEffect(isHovered ? 1.015 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    private struct AgentLaunchButton: View {
        let action: () -> Void
        let disabled: Bool
        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Luncurkan Agen di Git Worktree")
                        .font(WorkstationTheme.Fonts.body(12.5, weight: .bold))
                }
                .foregroundStyle(disabled ? WorkstationTheme.textDisabled : Color.black)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(disabled ? WorkstationTheme.hover : (isHovered ? WorkstationTheme.accentHover : WorkstationTheme.accent))
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(disabled ? WorkstationTheme.borderSoft : WorkstationTheme.accentBorder, lineWidth: 1)
                )
                .shadow(color: disabled ? Color.clear : WorkstationTheme.accent.opacity(isHovered ? 0.35 : 0.2), radius: isHovered ? 8 : 4, x: 0, y: 2)
                .scaleEffect(isHovered && !disabled ? 1.025 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    private func executeAgentLaunch(preflight: AgentLaunchPreflight, messageId: UUID) {
        guard let targetIssue = store.issues.first(where: { $0.id == preflight.issueId }) else { return }
        guard let originalProfile = appVM.agentProfileStore.profiles.first(where: { $0.id == preflight.selectedProfileId }) else { return }
        
        var configuredProfile = originalProfile
        configuredProfile.shouldClaimIssue = preflight.autoClaim
        configuredProfile.shouldCloseIssue = preflight.autoMerge
        configuredProfile.shouldRequestHumanReview = preflight.requestReview
        
        if preflight.useFastModel {
            configuredProfile.defaultPromptTemplate += "\n[Preference: Use Fast Model]"
        }
        
        if !preflight.extraPrompt.isEmpty {
            configuredProfile.defaultPromptTemplate += "\n\nAdditional Instructions:\n\(preflight.extraPrompt)"
        }
        
        appVM.launchAgentInWorktree(for: targetIssue, profile: configuredProfile)
        
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].text = "Agent launch initiated in Git Worktree for \(targetIssue.id) using \(configuredProfile.name)."
            messages[index].isAgentLaunch = false
            messages[index].agentLaunch = nil
        }
        
        messages.append(.init(role: .assistant, text: "🚀 Launched agent successfully! You can monitor progress in the Agent Console panel."))
    }

    @ViewBuilder
    private func formattedMessageText(for text: String) -> some View {
        let blocks = MarkdownTextRenderer.parseContentBlocks(from: text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<blocks.count, id: \.self) { idx in
                switch blocks[idx] {
                case .text(let plain):
                    MarkdownTextRenderer.copilotText(for: plain)
                        .font(WorkstationTheme.Fonts.body(13))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                case .heading(let level, let title):
                    let fontSize: CGFloat = {
                        switch level {
                        case 1: return 17
                        case 2: return 15
                        case 3: return 13.5
                        default: return 12.5
                        }
                    }()
                    Text(title)
                        .font(WorkstationTheme.Fonts.body(fontSize, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .padding(.top, level == 1 ? 16 : (level == 2 ? 12 : 8))
                        .padding(.bottom, 4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                case .table(let headers, let alignments, let rows):
                    MarkdownTableView(headers: headers, alignments: alignments, rows: rows)
                }
            }
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

extension CopilotConversationMessage {
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

struct OfflineErrorCard: View {
    let message: CopilotConversationMessage
    let onRetry: () -> Void
    
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(WorkstationTheme.red)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Connection Offline")
                        .font(WorkstationTheme.Fonts.body(13, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                    
                    Text("Unable to connect to the local AI service. Please verify that your local model server is running and accessible.")
                        .font(WorkstationTheme.Fonts.body(12))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            if !message.text.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showDetails.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showDetails ? "chevron.down" : "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                            Text("Show Technical Details")
                                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        }
                        .foregroundStyle(WorkstationTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    
                    if showDetails {
                        Text(message.text)
                            .font(WorkstationTheme.Fonts.body(11))
                            .foregroundStyle(WorkstationTheme.textMuted)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(WorkstationTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                                    .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                            )
                            .textSelection(.enabled)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            
            HStack {
                Spacer()
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Retry Connection")
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(WorkstationTheme.redBg.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.redBorder.opacity(0.3), lineWidth: 1)
        )
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
    var isExpanded = false
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

struct MarkdownTableView: View {
    let headers: [String]
    let alignments: [MarkdownTextRenderer.TableAlignment]
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                    // Header Row
                    GridRow {
                        ForEach(0..<headers.count, id: \.self) { colIdx in
                            let text = headers[colIdx]
                            let align = colIdx < alignments.count ? alignments[colIdx] : .left
                            
                            Text(text)
                                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                                .foregroundStyle(WorkstationTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(minWidth: 100, maxWidth: .infinity, alignment: textAlignment(for: align))
                                .background(WorkstationTheme.accentBg.opacity(0.8))
                        }
                    }
                    
                    // Data Rows
                    ForEach(0..<rows.count, id: \.self) { rowIdx in
                        let row = rows[rowIdx]
                        GridRow {
                            ForEach(0..<row.count, id: \.self) { colIdx in
                                let cell = row[colIdx]
                                let align = colIdx < alignments.count ? alignments[colIdx] : .left
                                
                                Text(cell)
                                    .font(WorkstationTheme.Fonts.body(11, weight: .regular))
                                    .foregroundStyle(WorkstationTheme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 100, maxWidth: .infinity, alignment: textAlignment(for: align))
                                    .background(
                                        rowIdx % 2 == 0
                                        ? WorkstationTheme.card.opacity(0.2)
                                        : WorkstationTheme.cardAlt.opacity(0.3)
                                    )
                            }
                        }
                    }
                }
                .background(WorkstationTheme.borderSoft)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium)
                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func textAlignment(for align: MarkdownTextRenderer.TableAlignment) -> Alignment {
        switch align {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
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