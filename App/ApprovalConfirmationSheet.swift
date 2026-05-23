import SwiftUI

/// Confirmation sheet for critical risk approvals.
/// Requires user to type "APPROVE" to confirm the action.
struct ApprovalConfirmationSheet: View {
    let approval: AgentApprovalRequest
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var confirmText: String = ""
    @FocusState private var isInputFocused: Bool

    private var isConfirmEnabled: Bool {
        confirmText.uppercased() == "APPROVE"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Critical Approval Required")
                        .font(WorkstationTheme.Fonts.display(16, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)

                    Text("This action requires explicit confirmation")
                        .font(WorkstationTheme.Fonts.body(12))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 18)

            Divider().overlay(WorkstationTheme.borderSoft)

            // Warning banner
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.red)

                Text("This operation may have significant consequences. Type APPROVE to confirm.")
                    .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                    .foregroundStyle(WorkstationTheme.red)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkstationTheme.redBg)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.redBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Approval prompt details
            VStack(alignment: .leading, spacing: 8) {
                Text("APPROVAL PROMPT")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(approval.prompt)
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WorkstationTheme.cardAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            }
            .padding(.horizontal, 24)

            // Confirmation input
            VStack(alignment: .leading, spacing: 8) {
                Text("TYPE 'APPROVE' TO CONFIRM")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)

                TextField("APPROVE", text: $confirmText)
                    .font(WorkstationTheme.Fonts.body(14, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(WorkstationTheme.inputBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(
                                confirmText.uppercased() == "APPROVE" ? WorkstationTheme.red : WorkstationTheme.borderStrong,
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                    .focused($isInputFocused)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer(minLength: 20)

            Divider().overlay(WorkstationTheme.borderSoft)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Cancel")
                            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkstationGhostButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button {
                    onConfirm()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Confirm Approval")
                            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CriticalApprovalButtonStyle(isEnabled: isConfirmEnabled))
                .disabled(!isConfirmEnabled)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 420)
        .background(WorkstationTheme.surface)
        .onAppear {
            isInputFocused = true
        }
    }
}

/// Button style for critical approval confirm button.
struct CriticalApprovalButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
            .foregroundStyle(isEnabled ? WorkstationTheme.card : WorkstationTheme.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isEnabled
                    ? (configuration.isPressed ? WorkstationTheme.red.opacity(0.9) : WorkstationTheme.red)
                    : WorkstationTheme.borderSoft
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            .shadow(
                color: isEnabled ? WorkstationTheme.red.opacity(0.3) : .clear,
                radius: 8,
                x: 0,
                y: 3
            )
    }
}

#Preview {
    ApprovalConfirmationSheet(
        approval: AgentApprovalRequest(
            stableKey: "test",
            runID: UUID(),
            promptHash: "hash",
            prompt: "Do you want to delete all files in the workspace? [y/N]",
            proposedInput: "y\n",
            rejectInput: "n\n",
            riskLevel: .critical
        ),
        onConfirm: {},
        onCancel: {}
    )
}