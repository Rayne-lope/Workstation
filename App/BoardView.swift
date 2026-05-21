import SwiftUI

struct BoardView: View {
    @Bindable var appVM: AppViewModel
    @ObservedObject var workspaceVM: WorkspaceViewModel
    let store: IssueStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                BoardSidebarView(appVM: appVM, workspaceVM: workspaceVM, store: store)
                    .frame(width: 240)

                VStack(spacing: 0) {
                    workspaceHeader
                    contentPane
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let selected = store.selectedIssue {
                    IssueRightPane(appVM: appVM, store: store, issue: selected)
                        .frame(width: 440)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBarView(appVM: appVM)
        }
        .background(WorkstationTheme.background)
        .frame(minWidth: 1180, minHeight: 640)
        .sheet(isPresented: $appVM.isClosePresented, onDismiss: { appVM.closeIssue = nil }) {
            if let issue = appVM.closeIssue {
                CloseIssueSheet(
                    issue: issue,
                    store: store,
                    defaultReason: appVM.preferencesStore.preferences.defaultCloseReasonTemplate,
                    appVM: appVM,
                    onDismiss: { appVM.dismissCloseSheet() }
                )
            }
        }
        .sheet(isPresented: $appVM.isBlockerPickerPresented, onDismiss: { appVM.dismissBlockerPicker() }) {
            if let issueID = appVM.blockerPickerIssueID {
                BlockerPickerSheet(
                    store: store,
                    issueID: issueID,
                    existingBlockerIDs: appVM.blockerPickerExistingBlockerIDs,
                    onPick: { blockerID in
                        appVM.dismissBlockerPicker()
                        Task { await store.addDependency(blockerID: blockerID, to: issueID) }
                    },
                    onCancel: { appVM.dismissBlockerPicker() }
                )
            }
        }
        .sheet(isPresented: $appVM.isReviewFollowupPresented, onDismiss: { appVM.dismissReviewFollowup() }) {
            if let id = appVM.reviewFollowupIssueID {
                ReviewFollowupSheet(
                    issueID: id,
                    appVM: appVM,
                    store: store,
                    onDismiss: { appVM.dismissReviewFollowup() }
                )
            }
        }
        .sheet(item: $appVM.pendingAgentLaunch, onDismiss: { appVM.cancelPendingAgentLaunch() }) { pendingLaunch in
            GitDirtyLaunchSheet(
                pendingLaunch: pendingLaunch,
                onCancel: { appVM.cancelPendingAgentLaunch() },
                onContinue: { appVM.continuePendingAgentLaunch() }
            )
        }
        .sheet(item: $appVM.pendingWorktreeLaunch, onDismiss: { appVM.cancelPendingWorktreeLaunch() }) { pendingLaunch in
            GitWorktreeLaunchSheet(
                pendingLaunch: pendingLaunch,
                onCancel: { appVM.cancelPendingWorktreeLaunch() },
                onRetry: { appVM.retryPendingWorktreeLaunch() },
                onContinue: { appVM.continuePendingWorktreeLaunch() },
                onLaunchSetup: { hint in appVM.launchWorktreeSetup(for: hint) }
            )
        }
        .sheet(isPresented: $appVM.isBulkClosePresented, onDismiss: { appVM.dismissBulkCloseSheet() }) {
            BulkCloseSheet(
                appVM: appVM,
                store: store,
                defaultReason: appVM.preferencesStore.preferences.defaultCloseReasonTemplate,
                onDismiss: { appVM.dismissBulkCloseSheet() }
            )
        }
        .background(
            Button("") { appVM.clearMultiSelection() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .allowsHitTesting(false)
        )
    }

    private var workspaceHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Beads / \(appVM.activeWorkspace?.name ?? "Workspace")")
                        .font(WorkstationTheme.Fonts.label)
                        .foregroundStyle(WorkstationTheme.textDisabled)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Text("Beads Kanban")
                        .font(WorkstationTheme.Fonts.display(26, weight: .heavy))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(WorkstationTheme.accent)
                }

                Button {
                    appVM.reloadIssues()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(WorkstationGhostButtonStyle())
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.isLoading)

                Button {
                    appVM.presentCreateIssue()
                } label: {
                    Label("New Issue", systemImage: "plus")
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .keyboardShortcut("n", modifiers: [.command])

                IssueFilterBarView(
                    store: store,
                    onClearAll: { store.clearFilters() }
                )
            }

            HStack(spacing: 26) {
                viewModeTab(.kanban, systemName: "rectangle.grid.1x2")
                viewModeTab(.list, systemName: "list.bullet")

                Spacer()

                Button {
                    appVM.presentDebugPanel()
                } label: {
                    Label("Debug", systemImage: "ladybug")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .background(WorkstationTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
        .onChange(of: store.filterState) { _, newValue in
            appVM.persistFilterState(newValue)
        }
    }

    private func viewModeTab(_ mode: BoardViewMode, systemName: String) -> some View {
        let isActive = appVM.viewMode == mode
        return Button {
            appVM.viewMode = mode
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                Text(mode.label)
                    .font(WorkstationTheme.Fonts.display(14, weight: .semibold))
            }
            .foregroundStyle(isActive ? WorkstationTheme.textPrimary : WorkstationTheme.textDisabled)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? WorkstationTheme.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentPane: some View {
        switch appVM.viewMode {
        case .list:
            IssueListView(appVM: appVM, store: store, profiles: appVM.agentProfileStore.profiles)
        case .kanban:
            KanbanBoardView(
                appVM: appVM,
                store: store,
                profiles: appVM.agentProfileStore.profiles,
                onRequestClose: { appVM.presentCloseSheet(for: $0) }
            )
        }
    }

}

enum WorkstationTheme {
    static let background = Color(hex: "0F0F0F")
    static let surface = Color(hex: "111111")
    static let card = Color(hex: "141414")
    static let cardAlt = Color(hex: "151515")
    static let borderSoft = Color(hex: "1A1A1A")
    static let border = Color(hex: "1E1E1E")
    static let borderStrong = Color(hex: "2A2A2A")

    static let textPrimary = Color(hex: "F0ECE4")
    static let textSecondary = Color(hex: "888888")
    static let textMuted = Color(hex: "555555")
    static let textDisabled = Color(hex: "333333")
    static let textSubtle = Color(hex: "444444")

    static let accent = Color(hex: "ECC864")
    static let accentHover = Color(hex: "F5D980")
    static let blue = Color(hex: "7DD3FC")
    static let green = Color(hex: "86EFAC")
    static let purple = Color(hex: "D8B4FE")
    static let red = Color(hex: "F87171")
    static let orange = Color(hex: "FB923C")

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 10
        static let panel: CGFloat = 12
    }

    enum Fonts {
        static let label = body(10.5, weight: .semibold)

        static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            Font.custom("Syne", size: size).weight(weight)
        }

        static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.custom("DM Sans", size: size).weight(weight)
        }
    }

    static func accent(for column: KanbanColumn) -> Color {
        switch column {
        case .backlog:
            return textMuted
        case .ready:
            return accent
        case .inProgress:
            return accent
        case .review:
            return blue
        case .blocked:
            return red
        case .done:
            return green
        }
    }

    static func difficultyColor(_ priority: Int) -> Color {
        switch priority {
        case 0, 1:
            return accent
        case 2:
            return blue
        case 3:
            return textSecondary
        case 4:
            return textMuted
        default:
            return textMuted
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

struct WorkstationPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
            .foregroundStyle(WorkstationTheme.background)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? WorkstationTheme.accentHover : WorkstationTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            .shadow(color: WorkstationTheme.accent.opacity(configuration.isPressed ? 0.12 : 0.24), radius: 12, x: 0, y: 4)
    }
}

struct WorkstationGhostButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WorkstationTheme.Fonts.body(compact ? 12 : 13, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? WorkstationTheme.textPrimary : WorkstationTheme.textSecondary)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 6 : 8)
            .background(configuration.isPressed ? WorkstationTheme.borderSoft : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }
}
