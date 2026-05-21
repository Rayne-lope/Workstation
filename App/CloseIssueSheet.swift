import SwiftUI

struct CloseIssueSheet: View {
    let issue: BeadIssue
    let store: IssueStore
    let appVM: AppViewModel
    let onDismiss: () -> Void

    @State private var reason: String
    @State private var isGeneratingAISuggestion = false
    @State private var localAIErrorMessage: String?
    @FocusState private var reasonFocused: Bool

    init(
        issue: BeadIssue,
        store: IssueStore,
        defaultReason: String = "",
        appVM: AppViewModel,
        onDismiss: @escaping () -> Void
    ) {
        self.issue = issue
        self.store = store
        self.appVM = appVM
        self.onDismiss = onDismiss
        _reason = State(initialValue: defaultReason)
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var aiSummarySeed: String {
        let trimmed = trimmedReason
        if !trimmed.isEmpty {
            return trimmed
        }
        if let description = issue.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return description
        }
        return issue.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)

            Divider().overlay(WorkstationTheme.borderSoft)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.accent)
                        .frame(width: 28, height: 28)
                        .background(WorkstationTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Closing logs to history.")
                            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                        Text("A short reason helps future-you and the team understand the outcome.")
                            .font(WorkstationTheme.Fonts.body(12))
                            .foregroundStyle(WorkstationTheme.textMuted)
                            .lineSpacing(2)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("REASON")
                            .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(WorkstationTheme.textSubtle)
                        Circle()
                            .fill(WorkstationTheme.accent)
                            .frame(width: 4, height: 4)
                    }
                    StyledTextEditor(
                        placeholder: "e.g. Shipped to main. Verified via swift test (170/170).",
                        text: $reason,
                        minHeight: 120,
                        isFocused: reasonFocused
                    )
                    .focused($reasonFocused)
                }

                if let localAIErrorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.orange)
                            .padding(.top, 2)
                        Text(localAIErrorMessage)
                            .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                            .foregroundStyle(WorkstationTheme.orange)
                            .lineSpacing(2)
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
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(WorkstationTheme.background)

            Divider().overlay(WorkstationTheme.borderSoft)

            HStack(spacing: 10) {
                if isGeneratingAISuggestion {
                    ProgressView()
                        .controlSize(.small)
                        .tint(WorkstationTheme.accent)
                }

                Button {
                    requestAISuggestion()
                } label: {
                    Label(isGeneratingAISuggestion ? "Generating..." : "Draft with Local AI", systemImage: "cpu")
                }
                .buttonStyle(WorkstationGhostButtonStyle())
                .disabled(isGeneratingAISuggestion)
                .help("Draft alasan close dengan AI · Tersedia juga di Copilot ⌘K")

                Spacer()

                Button("Cancel") { onDismiss() }
                    .buttonStyle(WorkstationGhostButtonStyle())
                    .keyboardShortcut(.cancelAction)

                Button {
                    Task { await store.close(id: issue.id, reason: reason) }
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Close Issue")
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedReason.isEmpty)
                .opacity(trimmedReason.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 560)
        .background(WorkstationTheme.surface)
        .preferredColorScheme(.dark)
        .onAppear { reasonFocused = true }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("CRAFTBOARD /")
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Text(issue.id)
                        .foregroundStyle(WorkstationTheme.accent)
                }
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .tracking(0.9)

                Text("Close Issue")
                    .font(WorkstationTheme.Fonts.display(22, weight: .heavy))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }
            Spacer()
            Button(action: onDismiss) {
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
        }
    }

    private func requestAISuggestion() {
        guard !isGeneratingAISuggestion else { return }
        isGeneratingAISuggestion = true
        localAIErrorMessage = nil

        let action = LocalAIAction.closeReason(issue: issue, summary: aiSummarySeed)
        let currentAppVM = appVM
        Task {
            do {
                let suggestion = try await currentAppVM.requestLocalAIResponse(for: action)
                await MainActor.run {
                    let reasonBinding = $reason
                    currentAppVM.presentLocalAISuggestionPreview(
                        title: "Review AI Close Reason",
                        subtitle: "\(issue.id) · \(issue.title)",
                        sourceLabel: "Close Reason",
                        generatedText: suggestion,
                        regenerate: {
                            try await currentAppVM.requestLocalAIResponse(for: action)
                        },
                        onApply: { text in
                            reasonBinding.wrappedValue = text
                            currentAppVM.dismissLocalAISuggestionPreview()
                        }
                    )
                    self.isGeneratingAISuggestion = false
                }
            } catch {
                await MainActor.run {
                    self.localAIErrorMessage = error.localizedDescription
                    self.isGeneratingAISuggestion = false
                }
            }
        }
    }
}
