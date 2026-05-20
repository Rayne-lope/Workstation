import SwiftUI

struct LocalAISuggestionPreviewSheet: View {
    @Bindable var preview: LocalAISuggestionPreviewState
    let onDismiss: () -> Void

    @State private var copiedFlash = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)

            Divider().overlay(WorkstationTheme.borderSoft)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
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
                        Text(preview.subtitle)
                            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                            .lineLimit(2)
                        Text("Edit the suggestion before applying it anywhere else.")
                            .font(WorkstationTheme.Fonts.body(12))
                            .foregroundStyle(WorkstationTheme.textMuted)
                            .lineSpacing(2)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(preview.sourceLabel.uppercased())
                            .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(WorkstationTheme.textSubtle)
                        if preview.isRegenerating {
                            ProgressView()
                                .controlSize(.small)
                                .tint(WorkstationTheme.accent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("OUTPUT")
                            .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(WorkstationTheme.textSubtle)
                        Circle()
                            .fill(WorkstationTheme.accent)
                            .frame(width: 4, height: 4)
                    }

                    TextEditor(text: $preview.draftText)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 280)
                        .background(WorkstationTheme.cardAlt)
                        .overlay(
                            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                        .textSelection(.enabled)
                }

                if let errorMessage = preview.errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.orange)
                            .padding(.top, 2)
                        Text(errorMessage)
                            .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                            .foregroundStyle(WorkstationTheme.orange)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
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
                    Clipboard.copy(preview.draftText)
                    flashCopyConfirmation()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(WorkstationGhostButtonStyle())

                Button {
                    Task { await preview.regenerate() }
                } label: {
                    HStack(spacing: 6) {
                        if preview.isRegenerating {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(preview.isRegenerating ? "Regenerating" : "Regenerate")
                    }
                }
                .buttonStyle(WorkstationGhostButtonStyle())
                .disabled(preview.isRegenerating)

                Button {
                    preview.apply()
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text(preview.primaryActionTitle)
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(preview.trimmedDraftText.isEmpty || preview.isRegenerating)
                .opacity(preview.trimmedDraftText.isEmpty || preview.isRegenerating ? 0.45 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 760, height: 640)
        .background(WorkstationTheme.surface)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("LOCAL AI /")
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Text(preview.sourceLabel)
                        .foregroundStyle(WorkstationTheme.accent)
                }
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .tracking(0.9)

                Text(preview.title)
                    .font(WorkstationTheme.Fonts.display(22, weight: .heavy))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(2)
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

    private func flashCopyConfirmation() {
        withAnimation(.easeOut(duration: 0.15)) {
            copiedFlash = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeOut(duration: 0.15)) {
                copiedFlash = false
            }
        }
    }
}
