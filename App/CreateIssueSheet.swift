import Foundation
import SwiftUI

struct CreateIssueSheet: View {
    enum Mode: String, CaseIterable, Identifiable, Hashable {
        case manual
        case aiDetail

        var id: String { rawValue }

        var label: String {
            switch self {
            case .manual: return "Manual"
            case .aiDetail: return "AI Detail"
            }
        }
    }

    enum ManualField {
        case title
        case description
    }

    let appVM: AppViewModel
    let store: IssueStore
    let onDismiss: () -> Void

    @State private var mode: Mode = .manual
    @State private var title: String
    @State private var description: String
    @State private var issueType: String
    @State private var priority: Int
    @State private var roughIdea: String = ""
    @State private var aiDraft: IssueDraft = .empty
    @State private var hasGeneratedAIDraft = false
    @State private var isGeneratingAIDraft = false
    @State private var aiErrorMessage: String?
    @FocusState private var focusedField: ManualField?
    @FocusState private var roughIdeaFocused: Bool

    private let issueTypes = ["task", "bug", "feature", "epic", "chore"]
    private let defaultIssueType: String
    private let defaultPriority: Int

    init(
        appVM: AppViewModel,
        store: IssueStore,
        defaultIssueType: String = "task",
        defaultPriority: Int = 2,
        onDismiss: @escaping () -> Void
    ) {
        self.appVM = appVM
        self.store = store
        self.onDismiss = onDismiss
        self.defaultIssueType = defaultIssueType
        self.defaultPriority = defaultPriority
        _title = State(initialValue: "")
        _description = State(initialValue: "")
        _issueType = State(initialValue: defaultIssueType)
        _priority = State(initialValue: defaultPriority)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)

            Divider().overlay(WorkstationTheme.borderSoft)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    modeSwitcher

                    switch mode {
                    case .manual:
                        manualForm
                    case .aiDetail:
                        aiDetailForm
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
            .background(WorkstationTheme.background)

            Divider().overlay(WorkstationTheme.borderSoft)

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
        }
        .frame(width: 760)
        .background(WorkstationTheme.surface)
        .onAppear {
            focusedField = .title
        }
        .onChange(of: mode) { _, newValue in
            guard newValue == .aiDetail else { return }
            seedRoughIdeaIfNeeded()
            roughIdeaFocused = true
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CRAFTBOARD / NEW")
                    .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(WorkstationTheme.textSubtle)
                Text("Create Issue")
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

    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases) { option in
                let isSelected = option == mode
                Button {
                    mode = option
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option == .manual ? "square.and.pencil" : "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text(option.label)
                            .font(WorkstationTheme.Fonts.body(11.5, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(isSelected ? WorkstationTheme.card : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                            .stroke(isSelected ? WorkstationTheme.accent.opacity(0.55) : WorkstationTheme.borderStrong, lineWidth: isSelected ? 1.2 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var manualForm: some View {
        VStack(alignment: .leading, spacing: 22) {
            field(label: "Title", required: true) {
                StyledTextField(
                    placeholder: "Short, specific summary",
                    text: $title,
                    isFocused: focusedField == .title
                )
                .focused($focusedField, equals: .title)
            }

            field(label: "Description", required: false) {
                StyledTextEditor(
                    placeholder: "Why this issue exists and what needs to be done.",
                    text: $description,
                    minHeight: 110,
                    isFocused: focusedField == .description
                )
                .focused($focusedField, equals: .description)
            }

            field(label: "Type", required: false) {
                ChipRow(
                    options: issueTypes,
                    selected: issueType,
                    label: { $0.capitalized },
                    tint: { tint(forType: $0) }
                ) { issueType = $0 }
            }

            field(label: "Priority", required: false) {
                ChipRow(
                    options: Array(0..<5),
                    selected: priority,
                    label: { PriorityDifficulty.from(priority: $0)?.displayName ?? "P\(String($0))" },
                    tint: { WorkstationTheme.difficultyColor($0) }
                ) { priority = $0 }
            }
        }
    }

    private var aiDetailForm: some View {
        VStack(alignment: .leading, spacing: 22) {
            field(label: "Rough Idea", required: true) {
                StyledTextEditor(
                    placeholder: "Describe the rough idea, user need, or problem to solve.",
                    text: $roughIdea,
                    minHeight: 120,
                    isFocused: roughIdeaFocused
                )
                .focused($roughIdeaFocused)
            }

            HStack(spacing: 10) {
                if isGeneratingAIDraft {
                    ProgressView()
                        .controlSize(.small)
                        .tint(WorkstationTheme.accent)
                }

                Button {
                    generateAIDraft()
                } label: {
                    Label(
                        hasGeneratedAIDraft ? "Regenerate Draft" : "Generate Draft",
                        systemImage: "sparkles"
                    )
                }
                .buttonStyle(WorkstationGhostButtonStyle())
                .disabled(isGeneratingAIDraft || roughIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Text("Draft is editable before any `bd create` call.")
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }

            if let aiErrorMessage {
                errorBanner(aiErrorMessage)
            }

            if hasGeneratedAIDraft {
                VStack(alignment: .leading, spacing: 22) {
                    field(label: "Title", required: true) {
                        StyledTextField(
                            placeholder: "Short, specific summary",
                            text: $aiDraft.title,
                            isFocused: false
                        )
                    }

                    field(label: "Description", required: false) {
                        StyledTextEditor(
                            placeholder: "Why this issue exists and what needs to be done.",
                            text: $aiDraft.description,
                            minHeight: 110,
                            isFocused: false
                        )
                    }

                    field(label: "Implementation Notes", required: false) {
                        StyledTextEditor(
                            placeholder: "Implementation notes, design cues, or guardrails.",
                            text: $aiDraft.implementationNotes,
                            minHeight: 110,
                            isFocused: false
                        )
                    }

                    field(label: "Acceptance Criteria", required: false) {
                        StyledTextEditor(
                            placeholder: "One criterion per line.",
                            text: $aiDraft.acceptanceCriteria,
                            minHeight: 110,
                            isFocused: false
                        )
                    }

                    field(label: "Type", required: false) {
                        ChipRow(
                            options: issueTypes,
                            selected: aiDraft.issueType ?? defaultIssueType,
                            label: { $0.capitalized },
                            tint: { tint(forType: $0) }
                        ) { aiDraft.issueType = $0 }
                    }

                    field(label: "Priority", required: false) {
                        ChipRow(
                            options: Array(0..<5),
                            selected: aiDraft.priority ?? defaultPriority,
                            label: { PriorityDifficulty.from(priority: $0)?.displayName ?? "P\(String($0))" },
                            tint: { WorkstationTheme.difficultyColor($0) }
                        ) { aiDraft.priority = $0 }
                    }

                    field(label: "Labels", required: false) {
                        StyledTextField(
                            placeholder: "frontend, ux, api",
                            text: $aiDraft.labels,
                            isFocused: false
                        )
                    }

                    advisorySection(
                        title: "Split suggestions",
                        body: aiDraft.splitSuggestionsText
                    )

                    advisorySection(
                        title: "Dependency suggestions",
                        body: aiDraft.dependencySuggestionsText
                    )
                }
                .padding(.top, 4)
            } else {
                EmptyStateCard(
                    title: "Generate a draft to unlock the editor",
                    message: "The AI will turn the rough idea into a structured draft you can edit before creating the issue."
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()

            Button("Cancel") { onDismiss() }
                .buttonStyle(WorkstationGhostButtonStyle())
                .keyboardShortcut(.cancelAction)

            if mode == .aiDetail {
                Button {
                    generateAIDraft()
                } label: {
                    HStack(spacing: 6) {
                        if isGeneratingAIDraft {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: hasGeneratedAIDraft ? "arrow.clockwise" : "sparkles")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(hasGeneratedAIDraft ? "Regenerate" : "Generate Draft")
                    }
                }
                .buttonStyle(WorkstationGhostButtonStyle())
                .disabled(isGeneratingAIDraft || roughIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    submitAI()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Create Issue")
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreateAI)
                .opacity(canCreateAI ? 1 : 0.45)
            } else {
                Button {
                    submitManual()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Create Issue")
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
        }
    }

    @ViewBuilder
    private func advisorySection(title: String, body: String) -> some View {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(title.uppercased())
                        .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Circle()
                        .fill(WorkstationTheme.blue)
                        .frame(width: 4, height: 4)
                }
                Text(trimmed)
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WorkstationTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.orange)
                .padding(.top, 2)
            Text(message)
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

    @ViewBuilder
    private func field<Content: View>(
        label: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(WorkstationTheme.textSubtle)
                if required {
                    Circle()
                        .fill(WorkstationTheme.accent)
                        .frame(width: 4, height: 4)
                }
            }
            content()
        }
    }

    private func tint(forType type: String) -> Color {
        switch type {
        case "bug": return WorkstationTheme.red
        case "feature": return WorkstationTheme.accent
        case "epic": return WorkstationTheme.purple
        case "chore": return WorkstationTheme.textMuted
        case "decision": return WorkstationTheme.blue
        default: return WorkstationTheme.blue
        }
    }

    private func seedRoughIdeaIfNeeded() {
        guard roughIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let seedParts = [title, description]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        roughIdea = seedParts.joined(separator: "\n\n")
    }

    private var canCreateAI: Bool {
        hasGeneratedAIDraft && !aiDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGeneratingAIDraft
    }

    private func submitManual() {
        let input = CreateIssueInput(
            title: title,
            description: description.isEmpty ? nil : description,
            issueType: issueType,
            priority: priority
        )
        Task { await store.createIssue(input) }
        onDismiss()
    }

    private func submitAI() {
        guard canCreateAI else { return }
        let input = aiDraft.createInput()
        Task { await store.createIssue(input) }
        onDismiss()
    }

    private func generateAIDraft() {
        guard !isGeneratingAIDraft else { return }
        let seed = roughIdea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !seed.isEmpty else {
            aiErrorMessage = "Enter a rough idea first."
            hasGeneratedAIDraft = false
            return
        }

        isGeneratingAIDraft = true
        aiErrorMessage = nil
        let action = LocalAIAction.detailIssueFromRoughIdea(roughIdea: seed)

        Task {
            do {
                let suggestion = try await appVM.requestLocalAIResponse(for: action)
                let parsed = try IssueDraft.parse(from: suggestion)
                await MainActor.run {
                    self.applyParsedDraft(parsed)
                    self.isGeneratingAIDraft = false
                }
            } catch {
                await MainActor.run {
                    self.aiErrorMessage = error.localizedDescription
                    self.isGeneratingAIDraft = false
                }
            }
        }
    }

    private func applyParsedDraft(_ parsed: IssueDraft) {
        aiDraft = parsed
        if aiDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            aiDraft.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if aiDraft.issueType == nil {
            aiDraft.issueType = defaultIssueType
        }
        if aiDraft.priority == nil {
            aiDraft.priority = defaultPriority
        }
        hasGeneratedAIDraft = true
    }

}

// MARK: - Styled inputs

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .padding(.horizontal, 12)
            }
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(isFocused ? WorkstationTheme.accent : WorkstationTheme.borderStrong,
                        lineWidth: isFocused ? 1.2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct StyledTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 96
    var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(minHeight: minHeight)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(isFocused ? WorkstationTheme.accent : WorkstationTheme.borderStrong,
                        lineWidth: isFocused ? 1.2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Text(message)
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textMuted)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }
}

// MARK: - Chip row selector

struct ChipRow<Option: Hashable>: View {
    let options: [Option]
    let selected: Option
    let label: (Option) -> String
    let tint: (Option) -> Color
    let onSelect: (Option) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isActive = option == selected
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(tint(option))
                            .frame(width: 5, height: 5)
                        Text(label(option))
                            .font(WorkstationTheme.Fonts.body(11.5, weight: .semibold))
                    }
                    .foregroundStyle(isActive ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isActive ? WorkstationTheme.card : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                            .stroke(isActive ? tint(option).opacity(0.55) : WorkstationTheme.borderStrong,
                                    lineWidth: isActive ? 1.2 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.15), value: isActive)
            }
            Spacer(minLength: 0)
        }
    }
}
