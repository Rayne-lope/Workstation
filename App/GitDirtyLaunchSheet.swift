import SwiftUI

struct GitDirtyLaunchSheet: View {
    let pendingLaunch: PendingAgentLaunch
    let onCancel: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            workspaceCard
            changedFilesCard

            actionRow
        }
        .padding(24)
        .frame(width: 760, height: 620)
        .background(WorkstationTheme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .fill(Color(hex: "26110F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(Color(hex: "4A1C18"), lineWidth: 1)
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(WorkstationTheme.red)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Working tree has uncommitted changes")
                        .font(WorkstationTheme.Fonts.display(18, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)

                    Text("Running an AI agent now may mix new changes with your existing work.")
                        .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                statusChip(label: pendingLaunch.profile.name, tone: WorkstationTheme.accent)
                statusChip(label: pendingLaunch.workspace.name, tone: WorkstationTheme.blue)
                statusChip(label: "\(pendingLaunch.gitStatus.changedFiles.count) changed", tone: WorkstationTheme.red)
            }
        }
    }

    private var workspaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            uppercaseLabel("Context")

            VStack(alignment: .leading, spacing: 8) {
                keyValueRow(label: "Issue", value: "\(pendingLaunch.issue.id) - \(pendingLaunch.issue.title)")
                keyValueRow(label: "Selected folder", value: pendingLaunch.workspace.selectedPath)
                if let rootPath = pendingLaunch.workspace.rootPath {
                    keyValueRow(label: "Workspace root", value: rootPath)
                }
                keyValueRow(label: "Validation", value: pendingLaunch.workspace.validationState.rawValue)
                keyValueRow(label: "Branch", value: pendingLaunch.gitStatus.branchName ?? "Unknown")
                keyValueRow(label: "Last commit", value: pendingLaunch.gitStatus.lastCommitSummary ?? "Unavailable")
            }
            .padding(14)
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    private var changedFilesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                uppercaseLabel("Changed Files")
                Spacer()
                Text("\(pendingLaunch.gitStatus.changedFiles.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WorkstationTheme.borderSoft)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            }

            if pendingLaunch.gitStatus.changedFiles.isEmpty {
                Text("No changed files were reported.")
                    .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(pendingLaunch.gitStatus.changedFiles) { file in
                            changedFileRow(file)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .frame(maxHeight: 250)
            }
        }
        .padding(14)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func changedFileRow(_ file: GitChangedFile) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(file.status)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(fileTone(for: file.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(fileTone(for: file.status).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(fileTone(for: file.status).opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))

            Text(file.path)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .lineLimit(2)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionRow: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .buttonStyle(WorkstationGhostButtonStyle())

            Spacer()

            Button("Continue Anyway", action: onContinue)
                .buttonStyle(WorkstationPrimaryButtonStyle())
        }
    }

    private func keyValueRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .textCase(.uppercase)
                .tracking(0.7)
            Text(value)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusChip(label: String, tone: Color) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tone.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                    .stroke(tone.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private func uppercaseLabel(_ label: String) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.label)
            .foregroundStyle(WorkstationTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.7)
    }

    private func fileTone(for status: String) -> Color {
        if status.contains("?") {
            return WorkstationTheme.orange
        }
        if status.contains("D") {
            return WorkstationTheme.red
        }
        if status.contains("R") || status.contains("C") {
            return WorkstationTheme.blue
        }
        return WorkstationTheme.accent
    }
}
