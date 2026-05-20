import SwiftUI

struct AgentRunConsolePane: View {
    @Bindable var appVM: AppViewModel
    let issue: BeadIssue

    var body: some View {
        VStack(spacing: 0) {
            AgentRunPaneHeader(
                issue: issue,
                record: appVM.activeConsoleRecord(),
                onBack: { appVM.showIssuePane() }
            )

            if let record = appVM.activeConsoleRecord() {
                AgentRunConsoleContent(appVM: appVM, record: record, compact: true)
            } else {
                EmptyConsolePlaceholder(onBack: { appVM.showIssuePane() })
            }
        }
        .background(WorkstationTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(WorkstationTheme.border)
                .frame(width: 1)
        }
    }
}

private struct AgentRunPaneHeader: View {
    let issue: BeadIssue
    let record: AgentRunRecord?
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Issue")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
            }
            .buttonStyle(InlinePaneButtonStyle())
            .keyboardShortcut(.cancelAction)
            .help("Back to issue detail")

            Text("Run Console")
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.leading, 4)

            Spacer()

            if let record {
                statusBadge(for: record.status)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    private func statusBadge(for status: AgentRunStatus) -> some View {
        let color: Color
        switch status {
        case .prepared, .terminalOpened: color = WorkstationTheme.accent
        case .needsReview: color = WorkstationTheme.blue
        case .accepted: color = WorkstationTheme.green
        case .failed: color = WorkstationTheme.red
        case .abandoned: color = WorkstationTheme.textMuted
        }
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(status.displayName)
                .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct InlinePaneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
            .background(configuration.isPressed ? WorkstationTheme.borderSoft : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct EmptyConsolePlaceholder: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.slash")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textDisabled)
            Text("No agent run recorded yet")
                .font(WorkstationTheme.Fonts.display(14, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSecondary)
            Text("Run an agent for this issue to populate the console.")
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Back to Issue") { onBack() }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
