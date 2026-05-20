import SwiftUI

struct AgentRunPromptPreviewView: View {
    let record: AgentRunRecord
    var compact: Bool = false
    let onCopyPrompt: () -> Void
    let onCopyCommand: () -> Void
    let onOpenTerminal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Prompt") {
                Button {
                    onCopyPrompt()
                } label: {
                    Label("Copy Prompt", systemImage: "doc.on.doc")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
            }

            ScrollView(.vertical) {
                Text(record.prompt)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: compact ? 160 : 220)
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

            sectionHeader("Terminal Command") {
                HStack(spacing: 6) {
                    Button {
                        onCopyCommand()
                    } label: {
                        Label("Copy Command", systemImage: "terminal")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .disabled(record.command.isEmpty)

                    Button {
                        onOpenTerminal()
                    } label: {
                        Label("Open Terminal", systemImage: "macwindow")
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .disabled(record.launchProjectPath.isEmpty)
                }
            }

            Text(record.command.isEmpty ? "No command recorded for this run." : record.command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(record.command.isEmpty ? WorkstationTheme.textMuted : WorkstationTheme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    @ViewBuilder
    private func sectionHeader<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textMuted)
                .textCase(.uppercase)
                .tracking(0.7)
            Spacer()
            trailing()
        }
    }
}
