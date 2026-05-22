import SwiftUI

struct ReviewFollowupSheet: View {
    let issueID: String
    let appVM: AppViewModel
    let store: IssueStore
    let onDismiss: () -> Void

    @State private var notes: String = ""
    @State private var resetToInProgress: Bool = false
    @State private var copiedFlash: Bool = false
    @FocusState private var notesFocused: Bool

    private var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    Image(systemName: "arrow.uturn.backward.circle")
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
                        Text("Send this issue back to the agent.")
                            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                        Text("Tulis bug / hardening yang perlu diperbaiki. Catatanmu akan ikut ke prompt.")
                            .font(WorkstationTheme.Fonts.body(12))
                            .foregroundStyle(WorkstationTheme.textMuted)
                            .lineSpacing(2)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("REVIEWER NOTES")
                            .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(WorkstationTheme.textSubtle)
                        Circle()
                            .fill(WorkstationTheme.accent)
                            .frame(width: 4, height: 4)
                    }
                    StyledTextEditor(
                        placeholder: "e.g. dark mode toggle nggak persist setelah restart — pakai @AppStorage. Juga edge case kalau system theme berubah.",
                        text: $notes,
                        minHeight: 140,
                        isFocused: notesFocused
                    )
                    .focused($notesFocused)
                }

                Toggle(isOn: $resetToInProgress) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset to In Progress")
                            .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                        Text("Hapus label `human` supaya issue balik ke kolom In Progress.")
                            .font(WorkstationTheme.Fonts.body(11))
                            .foregroundStyle(WorkstationTheme.textMuted)
                    }
                }
                .toggleStyle(.switch)
                .tint(WorkstationTheme.accent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(WorkstationTheme.background)

            Divider().overlay(WorkstationTheme.borderSoft)

            HStack(spacing: 10) {
                if copiedFlash {
                    Label("Copied to clipboard", systemImage: "checkmark.circle.fill")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.green)
                        .transition(.opacity)
                }
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(WorkstationGhostButtonStyle())
                    .keyboardShortcut(.cancelAction)

                Button {
                    appVM.copyReviewFollowupPrompt(for: issueID, notes: notes)
                    if resetToInProgress {
                        Task { await store.clearHumanReview(id: issueID) }
                    }
                    withAnimation(.easeOut(duration: 0.15)) { copiedFlash = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        onDismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .bold))
                        Text("Copy Prompt")
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedNotes.isEmpty)
                .opacity(trimmedNotes.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 520)
        .background(WorkstationTheme.surface)
        .onAppear { notesFocused = true }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("CRAFTBOARD /")
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Text(issueID)
                        .foregroundStyle(WorkstationTheme.accent)
                }
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .tracking(0.9)

                Text("Send Back to Agent")
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
}
