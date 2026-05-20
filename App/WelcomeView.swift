import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @Bindable var recentProjectsStore: RecentProjectsStore
    @Bindable var appVM: AppViewModel

    var body: some View {
        ZStack {
            HomeBackdrop()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    localAISettingsCard

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            leftColumn
                            rightColumn
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            leftColumn
                            rightColumn
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                    }

                    if let terminalErrorMessage = appVM.terminalErrorMessage {
                        errorBanner(terminalErrorMessage)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
        .background(WorkstationTheme.background)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            workspaceCard
            validationCard
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            recentsCard
            historyCard
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var heroCard: some View {
        dashboardCard(padding: 18) {
            HStack(alignment: .top, spacing: 16) {
                brandMark

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("HOME / WORKSPACE")
                            .font(WorkstationTheme.Fonts.label)
                            .foregroundStyle(WorkstationTheme.textDisabled)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        if viewModel.isLoading {
                            loadingBadge
                        }

                        Spacer(minLength: 0)
                    }

                    Text("Workspace Home")
                        .font(WorkstationTheme.Fonts.display(26, weight: .heavy))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .lineLimit(1)

                    Text(heroSubtitle)
                        .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(3)

                    HStack(alignment: .center, spacing: 8) {
                        statusChip(title: "Folder", value: folderChipValue, valueWidth: 170)
                        statusChip(title: "Root", value: rootChipValue, valueWidth: 170)
                        statusChip(title: "State", value: validationSummaryChipValue, tint: validationTint, valueWidth: 140)
                        statusChip(title: "BD", value: readinessChipValue, tint: readinessTint, valueWidth: 140)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    if viewModel.isLoading {
                        Button("Cancel") {
                            viewModel.cancelLoading()
                        }
                        .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    }

                    HStack(spacing: 8) {
                        Button {
                            viewModel.reloadValidation()
                        } label: {
                            Label("Reload Validation", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(WorkstationGhostButtonStyle())
                        .keyboardShortcut("r", modifiers: [.command])
                        .disabled(viewModel.selectedFolderPath == nil || viewModel.isLoading)

                        Button {
                            viewModel.chooseProjectFolder()
                        } label: {
                            Label("Choose Project Folder", systemImage: "folder")
                        }
                        .buttonStyle(WorkstationPrimaryButtonStyle())
                        .keyboardShortcut("o", modifiers: [.command])
                    }
                }
            }
        }
    }

    private var workspaceCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Workspace Context",
                    subtitle: "Selected folder, discovered root, and the next action Beads recommends."
                )

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        metricCell(
                            title: "Selected Folder",
                            value: viewModel.selectedFolderPath ?? "No folder selected"
                        )
                        metricCell(
                            title: "Discovered Root",
                            value: viewModel.rootPath ?? "Not discovered yet"
                        )
                    }

                    GridRow {
                        metricCell(
                            title: "Validation",
                            value: validationSummaryDetail,
                            tint: validationTint
                        )
                        metricCell(
                            title: "Next Step",
                            value: nextStepText,
                            tint: WorkstationTheme.accent
                        )
                    }
                }

                if let workspace = viewModel.workspace {
                    VStack(alignment: .leading, spacing: 8) {
                        stateBanner(
                            title: validationHeadline,
                            detail: validationCopy,
                            tint: validationTint,
                            icon: validationIcon
                        )

                        if let detail = workspace.detail {
                            Text(detail)
                                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                                .foregroundStyle(WorkstationTheme.textSecondary)
                                .textSelection(.enabled)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        emptyStateCopy(
                            title: "No workspace loaded yet",
                            detail: "Choose a folder to inspect Beads markers, workspace root discovery, and bd CLI readiness."
                        )

                        Button("Choose Project Folder") {
                            viewModel.chooseProjectFolder()
                        }
                        .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    }
                }
            }
        }
    }

    private var validationCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Validation",
                    subtitle: "Beads contract checks and setup hints, shown in scan-friendly order."
                )

                if let workspace = viewModel.workspace {
                    stateBanner(
                        title: validationHeadline,
                        detail: validationCopy,
                        tint: validationTint,
                        icon: validationIcon
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(workspace.checks) { check in
                            checkRow(check)
                            if check.id != workspace.checks.last?.id {
                                sectionDivider
                            }
                        }
                    }

                    if !workspace.setupHints.isEmpty {
                        sectionDivider
                        setupHints(workspace, workspace.setupHints)
                    }

                    if let suggestion = workspace.suggestion {
                        sectionDivider
                        Text(suggestion)
                            .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                            .foregroundStyle(WorkstationTheme.textSecondary)
                    }
                } else {
                    emptyStateCopy(
                        title: "Choose a folder to inspect validation",
                        detail: "The app will check .git, .beads, AGENTS.md, bd availability, and bd list readiness once a folder is selected."
                    )
                }
            }
        }
    }

    private var recentsCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Recent Projects",
                    subtitle: "Re-open a workspace you used recently without browsing the file picker again."
                )

                let recents = Array(recentProjectsStore.recents.prefix(6))

                if recents.isEmpty {
                    emptyStateCopy(
                        title: "No recent projects yet",
                        detail: "Open a workspace once and it will appear here for quick relaunch."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(recents.enumerated()), id: \.element.id) { index, recent in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recent.name)
                                        .font(WorkstationTheme.Fonts.display(13, weight: .semibold))
                                        .foregroundStyle(WorkstationTheme.textPrimary)
                                        .lineLimit(1)

                                    Text(recent.selectedPath)
                                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                                        .foregroundStyle(WorkstationTheme.textSecondary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                        .monospaced()
                                }

                                Spacer(minLength: 12)

                                VStack(alignment: .trailing, spacing: 8) {
                                    Text(recent.lastOpenedAt, format: .relative(presentation: .named))
                                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                        .foregroundStyle(WorkstationTheme.textMuted)

                                    HStack(spacing: 8) {
                                        Button {
                                            viewModel.loadWorkspace(from: URL(fileURLWithPath: recent.selectedPath, isDirectory: true))
                                        } label: {
                                            Label("Open", systemImage: "arrow.right")
                                        }
                                        .buttonStyle(WorkstationGhostButtonStyle(compact: true))

                                        Button {
                                            recentProjectsStore.remove(id: recent.id)
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                        .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                                    }
                                }
                            }

                            if index < recents.count - 1 {
                                sectionDivider
                            }
                        }
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Command History",
                    subtitle: "Recent shell runs used to validate the selected workspace."
                )

                let snapshots = Array(viewModel.commandHistory.prefix(4))

                if snapshots.isEmpty {
                    emptyStateCopy(
                        title: "No command history yet",
                        detail: "Shell runs will appear here after validation starts, which makes failures easier to diagnose."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(snapshots.enumerated()), id: \.offset) { index, snapshot in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(snapshot.commandWithArguments)
                                        .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                                        .foregroundStyle(WorkstationTheme.textPrimary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .monospaced()

                                    Spacer(minLength: 12)

                                    exitBadge(for: snapshot.exitCode)
                                }

                                HStack(spacing: 10) {
                                    Text(snapshot.workingDirectory.path)
                                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                        .foregroundStyle(WorkstationTheme.textMuted)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .monospaced()

                                    Spacer(minLength: 0)

                                    Text("\(snapshot.durationMs) ms")
                                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                        .foregroundStyle(WorkstationTheme.textMuted)

                                    Text(snapshot.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                        .foregroundStyle(WorkstationTheme.textMuted)
                                }

                                if let errorMessage = snapshot.errorMessage {
                                    Text(errorMessage)
                                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                        .foregroundStyle(WorkstationTheme.red)
                                        .lineLimit(2)
                                }

                                if !snapshot.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("stdout: \(snapshot.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
                                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                        .foregroundStyle(WorkstationTheme.textSecondary)
                                        .lineLimit(2)
                                }

                                if !snapshot.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("stderr: \(snapshot.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
                                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                        .foregroundStyle(WorkstationTheme.textSecondary)
                                        .lineLimit(2)
                                }
                            }

                            if index < snapshots.count - 1 {
                                sectionDivider
                            }
                        }
                    }
                }
            }
        }
    }

    private var localAISettingsCard: some View {
        dashboardCard {
            LocalAISettingsPanelView(appVM: appVM)
        }
    }

    private func setupHints(_ workspace: ProjectWorkspace, _ hints: [WorkspaceSetupHint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup Hints")
                .font(WorkstationTheme.Fonts.display(13, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textPrimary)

            ForEach(Array(hints.enumerated()), id: \.element.id) { index, hint in
                VStack(alignment: .leading, spacing: 8) {
                    Text(hint.title)
                        .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textPrimary)

                    Text(hint.detail)
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(2)

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
                            appVM.openTerminal(at: workspace.inspectionURL, command: hint.command)
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

                if index < hints.count - 1 {
                    sectionDivider
                }
            }
        }
    }

    private func dashboardCard<Content: View>(
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(WorkstationTheme.Fonts.display(14, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)

            Text(subtitle)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
                .lineLimit(2)
        }
    }

    private func emptyStateCopy(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textPrimary)

            Text(detail)
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metricCell(title: String, value: String, tint: Color? = nil) -> some View {
        let backgroundColor = tint.map { $0.opacity(0.08) } ?? WorkstationTheme.cardAlt
        let borderColor = tint.map { $0.opacity(0.35) } ?? WorkstationTheme.borderStrong

        return VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(value)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(tint ?? WorkstationTheme.textPrimary)
                .lineLimit(2)
                .truncationMode(.middle)
                .monospaced()
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func statusChip(title: String, value: String, tint: Color? = nil, valueWidth: CGFloat? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .tracking(0.8)

            Text(value)
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(tint ?? WorkstationTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: valueWidth, alignment: .leading)
                .monospaced()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func stateBanner(title: String, detail: String, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(WorkstationTheme.Fonts.display(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)

                Text(detail)
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func checkRow(_ check: WorkspaceCheck) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(check.title)
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)

                Spacer(minLength: 8)

                stateBadge(for: check.state)
            }

            if let detail = check.detail {
                Text(detail)
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stateBadge(for state: WorkspaceCheckState) -> some View {
        let tint = color(for: state)

        return HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)

            Text(state.rawValue.uppercased())
        }
        .font(WorkstationTheme.Fonts.body(10, weight: .bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(badgeBackground(for: state))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private func badgeBackground(for state: WorkspaceCheckState) -> Color {
        switch state {
        case .ok:
            return Color(hex: "0E170F")
        case .missing:
            return Color(hex: "1A1108")
        case .failed:
            return Color(hex: "1A0F0F")
        }
    }

    private func exitBadge(for code: Int32) -> some View {
        Text("exit \(code)")
            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
            .foregroundStyle(code == 0 ? WorkstationTheme.green : WorkstationTheme.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(code == 0 ? Color(hex: "0E170F") : Color(hex: "1A1108"))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                    .stroke(code == 0 ? WorkstationTheme.green.opacity(0.35) : WorkstationTheme.orange.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private func color(for state: WorkspaceCheckState) -> Color {
        switch state {
        case .ok:
            return WorkstationTheme.green
        case .missing:
            return WorkstationTheme.orange
        case .failed:
            return WorkstationTheme.red
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(WorkstationTheme.borderSoft)
            .frame(height: 1)
    }

    private var brandMark: some View {
        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
            .fill(Color(hex: "1A1608"))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(Color(hex: "2A2508"), lineWidth: 1)
            )
            .frame(width: 44, height: 44)
            .overlay(
                Text("B")
                    .font(WorkstationTheme.Fonts.display(17, weight: .heavy))
                    .foregroundStyle(WorkstationTheme.accent)
            )
    }

    private var loadingBadge: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
                .tint(WorkstationTheme.accent)
            Text("Inspecting")
        }
        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
        .foregroundStyle(WorkstationTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(WorkstationTheme.borderSoft)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private var heroSubtitle: String {
        if viewModel.isLoading {
            return "Inspecting the selected folder for Beads markers, workspace root discovery, and bd CLI readiness."
        }

        guard let workspace = viewModel.workspace else {
            if viewModel.selectedFolderPath == nil {
                return "Choose a local folder and Beads will surface the root, validation state, and setup guidance before the board opens."
            }
            return "The selected folder is being evaluated so the app can show you the discovered root and the next setup step."
        }

        switch workspace.validationState {
        case .valid:
            return "The workspace looks healthy. Switch into the board once you are ready to work the issue flow."
        case .missing:
            return "The workspace root is present, but one or more setup checks still need attention."
        case .failed:
            return "A validation command failed. Use the command history and setup hints below to recover quickly."
        case .notABeadsProject:
            return "This folder does not resolve to a Beads workspace yet. Use the setup hints to bootstrap it."
        }
    }

    private var validationSummaryChipValue: String {
        if viewModel.isLoading {
            return "Inspecting"
        }

        guard let workspace = viewModel.workspace else {
            return viewModel.selectedFolderPath == nil ? "Idle" : "Pending"
        }

        switch workspace.validationState {
        case .valid:
            return "Ready"
        case .missing:
            return "Missing"
        case .failed:
            return "Failed"
        case .notABeadsProject:
            return "No Beads root"
        }
    }

    private var validationSummaryDetail: String {
        if viewModel.isLoading {
            return "Running workspace inspection"
        }

        guard let workspace = viewModel.workspace else {
            return viewModel.selectedFolderPath == nil ? "No folder selected" : "Waiting for validation"
        }

        return workspace.validationState.rawValue
    }

    private var validationHeadline: String {
        if viewModel.isLoading {
            return "Inspecting selected folder"
        }

        guard let workspace = viewModel.workspace else {
            return viewModel.selectedFolderPath == nil ? "Choose a folder to start" : "Validation is pending"
        }

        switch workspace.validationState {
        case .valid:
            return "Workspace ready"
        case .missing:
            return "Workspace found, setup is incomplete"
        case .failed:
            return "Validation probe failed"
        case .notABeadsProject:
            return "No Beads root detected"
        }
    }

    private var validationCopy: String {
        if viewModel.isLoading {
            return "Beads is checking filesystem markers and running the CLI probes needed to identify the workspace root."
        }

        guard let workspace = viewModel.workspace else {
            return "Pick a folder and the app will inspect .git, .beads, AGENTS.md, and bd readiness in one pass."
        }

        switch workspace.validationState {
        case .valid:
            return "The selected folder passed workspace validation and is ready to move into the Kanban board."
        case .missing:
            return "The root exists, but one or more setup checks still need attention before the workspace is fully ready."
        case .failed:
            return "A command returned an error. The command history below keeps the failure trail intact for debugging."
        case .notABeadsProject:
            return "No .git or .beads marker was found in this folder chain yet. Use the setup hints to bootstrap it."
        }
    }

    private var validationIcon: String {
        if viewModel.isLoading {
            return "arrow.triangle.2.circlepath"
        }

        guard let workspace = viewModel.workspace else {
            return "folder"
        }

        switch workspace.validationState {
        case .valid:
            return "checkmark.seal.fill"
        case .missing:
            return "wrench.and.screwdriver"
        case .failed:
            return "exclamationmark.octagon.fill"
        case .notABeadsProject:
            return "folder.badge.questionmark"
        }
    }

    private var validationTint: Color {
        if viewModel.isLoading {
            return WorkstationTheme.accent
        }

        guard let workspace = viewModel.workspace else {
            return WorkstationTheme.textSecondary
        }

        switch workspace.validationState {
        case .valid:
            return WorkstationTheme.green
        case .missing:
            return WorkstationTheme.orange
        case .failed:
            return WorkstationTheme.red
        case .notABeadsProject:
            return WorkstationTheme.textSecondary
        }
    }

    private var readinessTint: Color {
        if let workspace = viewModel.workspace, !workspace.setupHints.isEmpty {
            return WorkstationTheme.orange
        }

        if viewModel.isLoading {
            return WorkstationTheme.accent
        }

        return WorkstationTheme.green
    }

    private var readinessChipValue: String {
        if viewModel.isLoading {
            return "Inspecting"
        }

        guard let workspace = viewModel.workspace else {
            return viewModel.selectedFolderPath == nil ? "Pending" : "Waiting"
        }

        if let firstHint = workspace.setupHints.first {
            if workspace.setupHints.count > 1 {
                return "\(firstHint.command) +\(workspace.setupHints.count - 1)"
            }
            return firstHint.command
        }

        switch workspace.validationState {
        case .valid:
            return "Ready"
        case .missing:
            return "Fix setup"
        case .failed:
            return "Check logs"
        case .notABeadsProject:
            return "Run bd init"
        }
    }

    private var nextStepText: String {
        if viewModel.isLoading {
            return "Inspecting"
        }

        guard let workspace = viewModel.workspace else {
            return viewModel.selectedFolderPath == nil ? "Choose a folder" : "Finish validation"
        }

        if !workspace.setupHints.isEmpty {
            return "Launch Setup"
        }

        switch workspace.validationState {
        case .valid:
            return "Open the board"
        case .missing:
            return "Resolve missing checks"
        case .failed:
            return "Review command history"
        case .notABeadsProject:
            return "Run bd init"
        }
    }

    private var folderChipValue: String {
        viewModel.selectedFolderPath ?? "No folder selected"
    }

    private var rootChipValue: String {
        viewModel.rootPath ?? "Not discovered"
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(WorkstationTheme.Fonts.body(12, weight: .medium))
            .foregroundStyle(WorkstationTheme.red)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: "1A0F0F"))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.red.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }
}

private struct HomeBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WorkstationTheme.background,
                    Color(hex: "101010"),
                    WorkstationTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    WorkstationTheme.accent.opacity(0.10),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    WorkstationTheme.blue.opacity(0.06),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 460
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.02),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private extension CommandSnapshot {
    var commandWithArguments: String {
        ([command] + arguments).joined(separator: " ")
    }
}
