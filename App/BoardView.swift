import AppKit
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

                if store.selectedIssue != nil || appVM.detailPaneMode == .bulkAction || appVM.detailPaneMode == .copilot {
                    IssueRightPane(appVM: appVM, store: store, issue: store.selectedIssue)
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
    // MARK: – Backgrounds
    /// Page-level canvas (darkest bg in dark mode, lightest in light mode)
    static let background   = adaptive(light: "F4F4F4", dark: "0F0F0F")
    /// Panel / sidebar surface
    static let surface      = adaptive(light: "FFFFFF", dark: "111111")
    /// Card surface (slightly elevated in dark, same white in light)
    static let card         = adaptive(light: "FFFFFF", dark: "141414")
    /// Alternate card / secondary panel (e.g. sidebar tree, mini-cards)
    static let cardAlt      = adaptive(light: "FAFAFA", dark: "151515")
    /// Hover highlight background
    static let hover        = adaptive(light: "F0F0F0", dark: "1A1A1A")
    /// Pressed / active state background
    static let active       = adaptive(light: "EBEBEB", dark: "222222")
    /// Input field fill
    static let inputBg      = adaptive(light: "F7F7F7", dark: "141414")

    // MARK: – Borders
    /// Very subtle separator (section dividers)
    static let borderSoft   = adaptive(light: "EEEEEE", dark: "1A1A1A")
    /// Default border
    static let border       = adaptive(light: "E5E5E5", dark: "1E1E1E")
    /// Emphasis border (focused inputs, strong dividers)
    static let borderStrong = adaptive(light: "D8D8D8", dark: "2A2A2A")

    // MARK: – Text
    /// Primary / heading text
    static let textPrimary  = adaptive(light: "111111", dark: "F0ECE4")
    /// Secondary body text
    static let textSecondary = adaptive(light: "555555", dark: "888888")
    /// Muted metadata / labels
    static let textMuted    = adaptive(light: "999999", dark: "555555")
    /// Disabled / placeholder text
    static let textDisabled = adaptive(light: "C8C8C8", dark: "333333")
    /// Subtle supporting text (slightly darker than muted in dark, same as secondary in light)
    static let textSubtle   = adaptive(light: "555555", dark: "444444")

    // MARK: – Accent
    /// Primary accent — gold in dark mode, near-black in light mode
    static let accent       = adaptive(light: "111111", dark: "ECC864")
    /// Hovered accent
    static let accentHover  = adaptive(light: "333333", dark: "F5D980")

    // MARK: – Semantic colors
    static let green        = adaptive(light: "4CAF74", dark: "86EFAC")
    static let greenBg      = adaptive(light: "F0FAF4", dark: "1A2F22")
    static let greenBorder  = adaptive(light: "C3EACF", dark: "2A4A35")
    static let blue         = adaptive(light: "3B82F6", dark: "7DD3FC")
    static let blueBg       = adaptive(light: "EFF6FF", dark: "0F1A1F")
    static let blueBorder   = adaptive(light: "BFDBFE", dark: "0F2535")
    static let purple       = adaptive(light: "8B5CF6", dark: "D8B4FE")
    static let purpleBg     = adaptive(light: "F5F3FF", dark: "1A0F1F")
    static let purpleBorder = adaptive(light: "DDD6FE", dark: "2E1A40")
    static let red          = adaptive(light: "EF4444", dark: "F87171")
    static let redBg        = adaptive(light: "FEF2F2", dark: "1F0F0F")
    static let redBorder    = adaptive(light: "FECACA", dark: "3A1414")
    static let orange       = adaptive(light: "F97316", dark: "FB923C")
    static let orangeBg     = adaptive(light: "FFF7ED", dark: "1A1008")
    static let orangeBorder = adaptive(light: "FED7AA", dark: "3A220A")
    static let accentBg     = adaptive(light: "F1F1F1", dark: "1A1608")
    static let accentBorder = adaptive(light: "D4D4D4", dark: "3A2F0A")

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

    // MARK: – Adaptive helper
    /// Returns a `Color` that resolves to `light` in Light Mode and `dark` in Dark Mode.
    /// Uses `NSColor`'s dynamic provider so the value updates live when the system appearance changes.
    private static func adaptive(light: String, dark: String) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var value: UInt64 = 0
            Scanner(string: cleaned).scanHexInt64(&value)
            return NSColor(
                red:   CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >>  8) & 0xFF) / 255,
                blue:  CGFloat( value        & 0xFF) / 255,
                alpha: 1
            )
        }))
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
            .background(configuration.isPressed ? WorkstationTheme.hover : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }
}
