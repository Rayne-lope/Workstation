import AppKit
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
                    .fill(WorkstationTheme.redBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.redBorder, lineWidth: 1)
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
                statusChip(
                    label: pendingLaunch.profile.name,
                    tone: WorkstationTheme.accent,
                    fill: WorkstationTheme.accentBg,
                    border: WorkstationTheme.accentBorder
                )
                statusChip(
                    label: pendingLaunch.workspace.name,
                    tone: WorkstationTheme.blue,
                    fill: WorkstationTheme.blueBg,
                    border: WorkstationTheme.blueBorder
                )
                statusChip(
                    label: "\(pendingLaunch.gitStatus.changedFiles.count) changed",
                    tone: WorkstationTheme.red,
                    fill: WorkstationTheme.redBg,
                    border: WorkstationTheme.redBorder
                )
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
                .background(fileToneFill(for: file.status))
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(fileToneBorder(for: file.status), lineWidth: 1)
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

    private func statusChip(label: String, tone: Color, fill: Color, border: Color) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                    .stroke(border, lineWidth: 1)
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

    private func fileToneFill(for status: String) -> Color {
        if status.contains("?") {
            return WorkstationTheme.orangeBg
        }
        if status.contains("D") {
            return WorkstationTheme.redBg
        }
        if status.contains("R") || status.contains("C") {
            return WorkstationTheme.blueBg
        }
        return WorkstationTheme.accentBg
    }

    private func fileToneBorder(for status: String) -> Color {
        if status.contains("?") {
            return WorkstationTheme.orangeBorder
        }
        if status.contains("D") {
            return WorkstationTheme.redBorder
        }
        if status.contains("R") || status.contains("C") {
            return WorkstationTheme.blueBorder
        }
        return WorkstationTheme.accentBorder
    }

}

struct GitWorktreeLaunchSheet: View {
    let pendingLaunch: PendingWorktreeLaunch
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onContinue: () -> Void
    let onLaunchSetup: (WorkspaceSetupHint) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    contextCard
                    setupCard
                    statusCard
                    conflictCard
                }
                .padding(.trailing, 4)
            }

            actionRow
        }
        .padding(24)
        .frame(width: 820, height: 680)
        .background(WorkstationTheme.background)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .fill(headerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(headerBorder, lineWidth: 1)
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: pendingLaunch.preflight.isBlocked ? "exclamationmark.triangle.fill" : "folder.badge.gearshape")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(headerTint)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(WorkstationTheme.Fonts.display(18, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)

                Text(headerDetail)
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerTitle: String {
        if pendingLaunch.preflight.isBlocked {
            return "Worktree launch needs attention"
        }
        if pendingLaunch.preflight.requiresConfirmation {
            return "Worktree launch can continue"
        }
        return "Worktree launch ready"
    }

    private var headerDetail: String {
        if let statusError = pendingLaunch.preflight.statusError {
            return statusError
        }
        if pendingLaunch.preflight.isBlocked {
            return "Resolve the items below before the safe terminal launch runs."
        }
        if pendingLaunch.preflight.requiresConfirmation {
            return "The current tree is dirty. You can continue and create the worktree anyway, or stop and review the changes first."
        }
        return "The worktree can be created and launched through the safe terminal path."
    }

    private var headerTint: Color {
        if pendingLaunch.preflight.isBlocked {
            return WorkstationTheme.red
        }
        if pendingLaunch.preflight.requiresConfirmation {
            return WorkstationTheme.orange
        }
        return WorkstationTheme.green
    }

    private var headerFill: Color {
        if pendingLaunch.preflight.isBlocked {
            return WorkstationTheme.redBg
        }
        if pendingLaunch.preflight.requiresConfirmation {
            return WorkstationTheme.orangeBg
        }
        return WorkstationTheme.greenBg
    }

    private var headerBorder: Color {
        if pendingLaunch.preflight.isBlocked {
            return WorkstationTheme.redBorder
        }
        if pendingLaunch.preflight.requiresConfirmation {
            return WorkstationTheme.orangeBorder
        }
        return WorkstationTheme.greenBorder
    }

    private var contextCard: some View {
        card(title: "Context") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    fieldLabel("Issue")
                    fieldValue("\(pendingLaunch.issue.id) - \(pendingLaunch.issue.title)")
                }
                GridRow {
                    fieldLabel("Profile")
                    fieldValue(pendingLaunch.profile.name)
                }
                GridRow {
                    fieldLabel("Selected folder")
                    fieldValue(pendingLaunch.workspace.selectedPath)
                }
                if let rootPath = pendingLaunch.workspace.rootPath {
                    GridRow {
                        fieldLabel("Workspace root")
                        fieldValue(rootPath)
                    }
                }
                GridRow {
                    fieldLabel("Target branch")
                    fieldValue(pendingLaunch.preflight.location.branchName)
                }
                GridRow {
                    fieldLabel("Target worktree")
                    fieldValue(pendingLaunch.preflight.location.worktreeURL.path)
                }
            }
        }
    }

    @ViewBuilder
    private var setupCard: some View {
        if !pendingLaunch.preflight.workspaceSetupHints.isEmpty {
            card(title: "Setup") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(pendingLaunch.preflight.workspaceSetupHints.enumerated()), id: \.element.id) { index, hint in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(hint.title)
                                .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                                .foregroundStyle(WorkstationTheme.textPrimary)

                            Text(hint.detail)
                                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                .foregroundStyle(WorkstationTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(hint.command)
                                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                                .foregroundStyle(WorkstationTheme.accent)
                                .monospaced()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(WorkstationTheme.borderSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                                        .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))

                            HStack(spacing: 8) {
                                Button {
                                    onLaunchSetup(hint)
                                } label: {
                                    Label("Launch Setup", systemImage: "terminal")
                                }
                                .buttonStyle(WorkstationPrimaryButtonStyle())

                                Button {
                                    Clipboard.copy(hint.command)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                            }
                        }

                        if index < pendingLaunch.preflight.workspaceSetupHints.count - 1 {
                            divider
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        if let statusSummary = pendingLaunch.preflight.statusSummary, statusSummary.isDirty || pendingLaunch.preflight.requiresConfirmation {
            card(title: "Working Tree") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        statusChip(
                            label: statusSummary.branchName ?? "Unknown branch",
                            tone: WorkstationTheme.accent,
                            fill: WorkstationTheme.accentBg,
                            border: WorkstationTheme.accentBorder
                        )
                        statusChip(
                            label: "\(statusSummary.changedFiles.count) changed",
                            tone: WorkstationTheme.red,
                            fill: WorkstationTheme.redBg,
                            border: WorkstationTheme.redBorder
                        )
                    }

                    if let lastCommitSummary = statusSummary.lastCommitSummary {
                        fieldLine(label: "Last commit", value: lastCommitSummary)
                    }

                    if statusSummary.changedFiles.isEmpty {
                        Text("No changed files were reported.")
                            .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                            .foregroundStyle(WorkstationTheme.textMuted)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(statusSummary.changedFiles.prefix(6)) { file in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(file.status)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(fileTone(for: file.status))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(fileToneFill(for: file.status))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                                                .stroke(fileToneBorder(for: file.status), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))

                                    Text(file.path)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(WorkstationTheme.textPrimary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var conflictCard: some View {
        if pendingLaunch.preflight.existingWorktreePath != nil || pendingLaunch.preflight.branchConflictName != nil || pendingLaunch.preflight.statusError != nil {
            card(title: "Recovery") {
                VStack(alignment: .leading, spacing: 12) {
                    if let statusError = pendingLaunch.preflight.statusError {
                        recoveryRow(
                            title: "Status check failed",
                            detail: statusError,
                            tone: WorkstationTheme.red
                        )
                    }

                    if let existingWorktreePath = pendingLaunch.preflight.existingWorktreePath {
                        recoveryRow(
                            title: "Worktree already exists",
                            detail: existingWorktreePath,
                            tone: WorkstationTheme.orange
                        ) {
                            Button {
                                NSWorkspace.shared.open(URL(fileURLWithPath: existingWorktreePath, isDirectory: true))
                            } label: {
                                Label("Open", systemImage: "folder")
                            }
                            .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                        }
                    }

                    if let branchConflictName = pendingLaunch.preflight.branchConflictName {
                        recoveryRow(
                            title: "Branch already exists",
                            detail: branchConflictName,
                            tone: WorkstationTheme.red
                        ) {
                            Button {
                                Clipboard.copy(branchConflictName)
                            } label: {
                                Label("Copy Branch", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                        }
                    }

                    Text("Use Retry Check after you fix the underlying state.")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .buttonStyle(WorkstationGhostButtonStyle())

            Spacer()

            Button("Retry Check", action: onRetry)
                .buttonStyle(WorkstationGhostButtonStyle())

            if !pendingLaunch.preflight.isBlocked {
                Button("Launch Worktree", action: onContinue)
                    .buttonStyle(WorkstationPrimaryButtonStyle())
            }
        }
    }

    private func card<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textMuted)
                .textCase(.uppercase)
                .tracking(0.7)

            content()
        }
        .padding(14)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func fieldLabel(_ label: String) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(WorkstationTheme.textSubtle)
            .frame(width: 96, alignment: .leading)
    }

    private func fieldValue(_ value: String) -> some View {
        Text(value)
            .font(WorkstationTheme.Fonts.body(12, weight: .medium))
            .foregroundStyle(WorkstationTheme.textSecondary)
            .lineLimit(2)
            .textSelection(.enabled)
    }

    private func fieldLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
            Text(value)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private func recoveryRow(
        title: String,
        detail: String,
        tone: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(tone)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Spacer()
            }

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tone.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(tone.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private func recoveryRow<Actions: View>(
        title: String,
        detail: String,
        tone: Color,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(tone)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Spacer()
                actions()
            }

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tone.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(tone.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(WorkstationTheme.borderSoft)
            .frame(height: 1)
    }

    private func statusChip(label: String, tone: Color, fill: Color, border: Color) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
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

    private func fileToneFill(for status: String) -> Color {
        if status.contains("?") {
            return WorkstationTheme.orangeBg
        }
        if status.contains("D") {
            return WorkstationTheme.redBg
        }
        if status.contains("R") || status.contains("C") {
            return WorkstationTheme.blueBg
        }
        return WorkstationTheme.accentBg
    }

    private func fileToneBorder(for status: String) -> Color {
        if status.contains("?") {
            return WorkstationTheme.orangeBorder
        }
        if status.contains("D") {
            return WorkstationTheme.redBorder
        }
        if status.contains("R") || status.contains("C") {
            return WorkstationTheme.blueBorder
        }
        return WorkstationTheme.accentBorder
    }
}
