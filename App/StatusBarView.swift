import SwiftUI

struct StatusBarView: View {
    @Bindable var appVM: AppViewModel

    var body: some View {
        let store = appVM.issueStore
        let lastCommand = appVM.shellRunner.history.last
        let issueError = store?.errorMessage
        let agentError = appVM.agentProfileStore.errorMessage
        let launchError = appVM.launchErrorMessage
        let terminalError = appVM.terminalErrorMessage
        let worktreeMessage = appVM.worktreeMessage
        let localAIMessage = appVM.localAIStatusMessage
        let localAIMessageIsError = appVM.localAIStatusMessageIsError

        VStack(alignment: .leading, spacing: 4) {
            if let issueError {
                errorRow(label: "CLI", message: issueError)
            }
            if let agentError {
                errorRow(label: "Agent", message: agentError)
            }
            if let launchError {
                errorRow(label: "Launch", message: launchError) {
                    appVM.clearLaunchError()
                }
            }
            if let terminalError {
                errorRow(label: "Terminal", message: terminalError) {
                    appVM.clearTerminalError()
                }
            }
            if let worktreeMessage {
                infoRow(label: "Worktree", message: worktreeMessage) {
                    appVM.clearWorktreeMessage()
                }
            }
            if let localAIMessage {
                if localAIMessageIsError {
                    errorRow(label: "Local AI", message: localAIMessage) {
                        appVM.clearLocalAIStatus()
                    }
                } else {
                    infoRow(label: "Local AI", message: localAIMessage) {
                        appVM.clearLocalAIStatus()
                    }
                }
            }

            HStack(spacing: 12) {
                if store?.isLoading == true {
                    ProgressView().controlSize(.small)
                    Text("Loading...")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                } else if let snapshot = lastCommand {
                    Text(([snapshot.command] + snapshot.arguments).joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("exit \(snapshot.exitCode)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(snapshot.exitCode == 0 ? WorkstationTheme.green : WorkstationTheme.orange)
                    Text("\(snapshot.durationMs) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(WorkstationTheme.textMuted)
                } else {
                    Text("Idle")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }

                Spacer()

                if let last = store?.lastReloadedAt {
                    Text("Reloaded \(last.formatted(date: .omitted, time: .standard))")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }

                Button("Debug") {
                    appVM.presentDebugPanel()
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(WorkstationTheme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    private func errorRow(label: String, message: String, dismiss: (() -> Void)? = nil) -> some View {
        HStack {
            Text("\(label): \(message)")
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.red)
                .lineLimit(2)
            Spacer()
            if let dismiss {
                Button("Dismiss", action: dismiss)
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(WorkstationTheme.redBg)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(WorkstationTheme.redBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private func infoRow(label: String, message: String, dismiss: (() -> Void)? = nil) -> some View {
        HStack {
            Text("\(label): \(message)")
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.blue)
                .lineLimit(2)
            Spacer()
            if let dismiss {
                Button("Dismiss", action: dismiss)
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(WorkstationTheme.blueBg)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(WorkstationTheme.blueBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }
}
