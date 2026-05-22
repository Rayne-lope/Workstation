import SwiftUI

struct CreateIssueSheet: View {
    let store: IssueStore
    let onDismiss: () -> Void

    @State private var title: String
    @State private var description: String
    @State private var issueType: String
    @State private var priority: Int
    @FocusState private var focusedField: Field?

    private enum Field { case title, description }

    private let issueTypes = ["task", "bug", "feature", "epic", "chore"]

    init(
        store: IssueStore,
        defaultIssueType: String = "task",
        defaultPriority: Int = 2,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.onDismiss = onDismiss
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
                            label: { PriorityDifficulty.from(priority: $0)?.displayName ?? "P\($0)" },
                            tint: { WorkstationTheme.difficultyColor($0) }
                        ) { priority = $0 }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
            .background(WorkstationTheme.background)

            Divider().overlay(WorkstationTheme.borderSoft)

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(WorkstationGhostButtonStyle())
                    .keyboardShortcut(.cancelAction)

                Button {
                    submit()
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
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 520)
        .background(WorkstationTheme.surface)
        .onAppear { focusedField = .title }
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
        default: return WorkstationTheme.blue
        }
    }

    private func submit() {
        let input = CreateIssueInput(
            title: title,
            description: description.isEmpty ? nil : description,
            issueType: issueType,
            priority: priority
        )
        Task { await store.createIssue(input) }
        onDismiss()
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
