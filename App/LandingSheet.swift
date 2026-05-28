import SwiftUI
#if canImport(BeadsWorkspace)
import BeadsWorkspace
import BeadsContract
#endif

/// The Automated Landing Sheet — presented when an agent run finalises.
/// Shows test results, changed files, suggested action (close vs review),
/// and pre-fills notes for human to approve with one click.
struct LandingSheet: View {
    let landing: PendingLanding
    @Bindable var appVM: AppViewModel
    var store: IssueStore

    @State private var notes: String = ""
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss

    private var testResult: TestRunResult? { appVM.landingTestResults[landing.id] }
    private var diffResult: DiffAnalysis? { appVM.landingDiffResults[landing.id] }
    private var isAnalysing: Bool { testResult == nil || diffResult == nil }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().background(WorkstationTheme.border)
            analysisSection
            Divider().background(WorkstationTheme.border)
            notesSection
            Divider().background(WorkstationTheme.border)
            actionBar
        }
        .frame(width: 560)
        .background(WorkstationTheme.card)
        .cornerRadius(WorkstationTheme.Radius.large)
        .onAppear { generateNotes() }
        .onChange(of: testResult?.summary) { _, _ in generateNotes() }
        .onChange(of: diffResult?.suggestion) { _, _ in generateNotes() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "airplane.arrival")
                .foregroundStyle(WorkstationTheme.accent)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Automated Landing")
                    .font(WorkstationTheme.Fonts.display(15, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("\(landing.issueID) · \(landing.issueTitle)")
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if isAnalysing {
                AgentRunSpinnerView(size: 16)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var analysisSection: some View {
        VStack(spacing: 0) {
            testResultRow
            Divider().background(WorkstationTheme.border).padding(.horizontal, 20)
            diffResultRow
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var testResultRow: some View {
        HStack(spacing: 12) {
            Label("Tests", systemImage: "testtube.2")
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .frame(width: 90, alignment: .leading)
            if let result = testResult {
                Text(result.summary)
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                    .foregroundStyle(result.state == .passed ? WorkstationTheme.green : WorkstationTheme.orange)
                Spacer()
                Image(systemName: result.state == .passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.state == .passed ? WorkstationTheme.green : WorkstationTheme.orange)
            } else {
                Text("Running…")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textDisabled)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var diffResultRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Label("Changed files", systemImage: "doc.text.magnifyingglass")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .frame(width: 120, alignment: .leading)
                if let diff = diffResult {
                    Text("\(diff.changedFiles.count) file\(diff.changedFiles.count == 1 ? "" : "s")")
                        .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                    Spacer()
                    suggestionBadge(diff.suggestion)
                } else {
                    Text("Analysing…")
                        .font(WorkstationTheme.Fonts.body(13))
                        .foregroundStyle(WorkstationTheme.textDisabled)
                    Spacer()
                }
            }
            if let diff = diffResult, !diff.changedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(diff.changedFiles.prefix(6), id: \.self) { file in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(DiffAnalysis.isUIFile(file) ? WorkstationTheme.orange : WorkstationTheme.textDisabled)
                                .frame(width: 4, height: 4)
                            Text(file)
                                .font(WorkstationTheme.Fonts.body(11))
                                .foregroundStyle(WorkstationTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    if diff.changedFiles.count > 6 {
                        Text("+ \(diff.changedFiles.count - 6) more")
                            .font(WorkstationTheme.Fonts.body(11))
                            .foregroundStyle(WorkstationTheme.textDisabled)
                    }
                }
                .padding(.leading, 132)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func suggestionBadge(_ suggestion: DiffAnalysis.Suggestion) -> some View {
        let (label, color): (String, Color) = switch suggestion {
        case .review: ("🔶 UI changes — review", WorkstationTheme.orange)
        case .close:  ("✅ Logic only — self-close", WorkstationTheme.green)
        }
        return Text(label)
            .font(WorkstationTheme.Fonts.body(11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes / Reason")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
            TextEditor(text: $notes)
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(WorkstationTheme.background.opacity(0.5))
                .cornerRadius(WorkstationTheme.Radius.small)
                .frame(minHeight: 72, maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            // Flag for review
            Button {
                Task { await flagReview() }
            } label: {
                Label("Flag for Review", systemImage: "flag.fill")
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .foregroundStyle(WorkstationTheme.orange)
            .disabled(isSubmitting || isAnalysing)

            // Close issue
            Button {
                Task { await closeIssue() }
            } label: {
                Label("Close Issue", systemImage: "checkmark.circle.fill")
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(WorkstationTheme.green)
            .disabled(isSubmitting || isAnalysing)

            Spacer()

            // Skip
            Button("Skip") {
                appVM.dismissLanding(landing)
                dismiss()
            }
            .font(WorkstationTheme.Fonts.body(13))
            .foregroundStyle(WorkstationTheme.textSecondary)
            .buttonStyle(.plain)
            .disabled(isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Actions

    private func flagReview() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        await store.flagForReview(id: landing.issueID, notes: notes)
        appVM.dismissLanding(landing)
        dismiss()
    }

    private func closeIssue() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        await store.close(id: landing.issueID, reason: notes)
        appVM.dismissLanding(landing)
        dismiss()
    }

    // MARK: - Pre-fill notes

    private func generateNotes() {
        guard !notes.isEmpty && notes == generatedNotes(using: nil) else {
            // Only auto-update if notes haven't been manually edited
            let generated = generatedNotes(using: diffResult)
            if notes.isEmpty || notes.hasPrefix("Implementasi") || notes.hasPrefix("Landing") {
                notes = generated
            }
            return
        }
        notes = generatedNotes(using: diffResult)
    }

    private func generatedNotes(using diff: DiffAnalysis?) -> String {
        var parts: [String] = []
        parts.append("Landing Sequence: \(landing.issueTitle).")

        if let test = testResult {
            parts.append("Tests: \(test.summary).")
        }

        if let diff {
            if !diff.uiFiles.isEmpty {
                let names = diff.uiFiles.prefix(3).map { ($0 as NSString).lastPathComponent }
                parts.append("UI files: \(names.joined(separator: ", ")).")
            } else if !diff.changedFiles.isEmpty {
                parts.append("Pure logic, no UI files changed.")
            }
        }

        return parts.joined(separator: " ")
    }
}
