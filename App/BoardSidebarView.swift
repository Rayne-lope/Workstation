import SwiftUI

struct BoardSidebarView: View {
    @Bindable var appVM: AppViewModel
    @ObservedObject var workspaceVM: WorkspaceViewModel
    let store: IssueStore

    var body: some View {
        let workspace = appVM.activeWorkspace

        VStack(alignment: .leading, spacing: 18) {
            brandHeader(workspace: workspace)
            navSection
            counters(store: store)

            Spacer()

            if let workspace {
                Button {
                    appVM.openTerminal(at: workspace.inspectionURL)
                } label: {
                    Label("Terminal", systemImage: "terminal")
                }
                .buttonStyle(WorkstationGhostButtonStyle())
            }

            Button {
                appVM.presentDebugPanel()
            } label: {
                Label("Debug Panel", systemImage: "ladybug")
            }
            .buttonStyle(WorkstationGhostButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkstationTheme.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(width: 1)
        }
        .sheet(isPresented: $appVM.isCreatePresented) {
            CreateIssueSheet(
                store: store,
                defaultIssueType: appVM.preferencesStore.preferences.defaultIssueType,
                defaultPriority: appVM.preferencesStore.preferences.defaultIssuePriority,
                onDismiss: { appVM.isCreatePresented = false }
            )
        }
        .sheet(isPresented: $appVM.isDebugPresented) {
            DebugPanelView(
                history: appVM.shellRunner.history,
                latestDecodeFailureRawJSON: store.lastDecodeFailureRawJSON,
                agentRunHistoryStore: appVM.agentRunHistoryStore,
                onDismiss: { appVM.isDebugPresented = false }
            )
        }
    }

    private func brandHeader(workspace: ProjectWorkspace?) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .fill(Color(hex: "1A1608"))
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(Color(hex: "2A2508"), lineWidth: 1)
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Text("B")
                        .font(WorkstationTheme.Fonts.display(15, weight: .heavy))
                        .foregroundStyle(WorkstationTheme.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(workspace?.name ?? "Workspace")
                    .font(WorkstationTheme.Fonts.display(14, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(1)
                Text("Beads Kanban")
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textDisabled)
            }
        }
        .padding(.bottom, 6)
    }

    private var navSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workspace")
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .textCase(.uppercase)
                .tracking(0.8)

            Button {
                workspaceVM.chooseProjectFolder()
            } label: {
                Label("Choose Folder", systemImage: "folder")
            }
            .buttonStyle(SidebarNavButtonStyle())
            .keyboardShortcut("o", modifiers: [.command])

            Button {
                appVM.reloadIssues()
            } label: {
                Label(store.isLoading ? "Reloading" : "Reload Issues", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SidebarNavButtonStyle())
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(store.isLoading)

            Button {
                appVM.presentCreateIssue()
            } label: {
                Label("New Issue", systemImage: "plus.square")
            }
            .buttonStyle(SidebarNavButtonStyle(isActive: true))
            .keyboardShortcut("n", modifiers: [.command])
        }
    }

    @ViewBuilder
    private func counters(store: IssueStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Stats")
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.top, 2)

            counterRow(label: "Backlog", count: store.backlogIssues.count)
            counterRow(label: "Ready", count: store.readyIssues.count)
            counterRow(label: "In Progress", count: store.inProgressIssues.count)
            counterRow(label: "Review", count: store.reviewIssues.count)
            counterRow(label: "Blocked", count: store.blockedIssues.count)
            counterRow(label: "Done", count: store.doneIssues.count)
        }
        .padding(.top, 6)
    }

    private func counterRow(label: String, count: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color(for: label))
                .frame(width: 6, height: 6)
            Text(label)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
            Spacer()
            Text("\(count)")
                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(WorkstationTheme.borderSoft)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
        }
        .padding(.vertical, 2)
    }

    private func color(for label: String) -> Color {
        switch label {
        case "Ready", "In Progress":
            return WorkstationTheme.accent
        case "Review":
            return WorkstationTheme.blue
        case "Blocked":
            return WorkstationTheme.red
        case "Done":
            return WorkstationTheme.green
        default:
            return WorkstationTheme.textMuted
        }
    }
}

private struct SidebarNavButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
            .foregroundStyle(isActive ? WorkstationTheme.accent : (configuration.isPressed ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .fill(isActive ? Color(hex: "1A1608") : (configuration.isPressed ? WorkstationTheme.borderSoft : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(isActive ? Color(hex: "2A2508") : Color.clear, lineWidth: 1)
            )
    }
}
