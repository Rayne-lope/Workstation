import AppKit
import SwiftUI

struct BoardSidebarView: View {
    @Bindable var appVM: AppViewModel
    @ObservedObject var workspaceVM: WorkspaceViewModel
    let store: IssueStore

    var body: some View {
        let workspace = appVM.activeWorkspace

        VStack(alignment: .leading, spacing: 18) {
            brandHeader(workspace: workspace)
            
            viewsSection
            
            Divider()
                .padding(.vertical, 2)
                .overlay(WorkstationTheme.borderSoft)
                
            actionsSection
            
            Divider()
                .padding(.vertical, 2)
                .overlay(WorkstationTheme.borderSoft)

            counters(store: store)

            Spacer()

            Button {
                appVM.presentSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
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
                appVM: appVM,
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
                onChangeStatus: { appVM.updateAgentRunStatus(id: $0, status: $1) },
                onDismiss: { appVM.isDebugPresented = false }
            )
        }
        .sheet(isPresented: $appVM.isSettingsPresented, onDismiss: { appVM.dismissSettings() }) {
            SettingsShellView(appVM: appVM)
                .frame(minWidth: 800, minHeight: 600)
        }
    }

    @ViewBuilder
    private func brandHeader(workspace: ProjectWorkspace?) -> some View {
        let isWorkly = PreferencesStore.activeTheme == .workly
        HStack(spacing: 10) {
            let size = CGSize(width: 36, height: 36)
            if let image = bundledImage(named: "workstation_logo", fitting: size) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: isWorkly ? 6 : WorkstationTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: isWorkly ? 6 : WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(isWorkly ? Color.white.opacity(0.08) : WorkstationTheme.borderStrong, lineWidth: 1)
                    )
            } else {
                Group {
                    if isWorkly {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "6f5bf6"), Color(hex: "5b48e8")], startPoint: .top, endPoint: .bottom))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .fill(WorkstationTheme.accentBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                                    .stroke(WorkstationTheme.accentBorder, lineWidth: 1)
                            )
                    }
                }
                .frame(width: 36, height: 36)
                .overlay(
                    Text("B")
                        .font(WorkstationTheme.Fonts.display(15, weight: .heavy))
                        .foregroundStyle(isWorkly ? .white : WorkstationTheme.accent)
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(workspace?.name ?? "Workspace")
                    .font(WorkstationTheme.Fonts.display(14, weight: isWorkly ? .heavy : .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(1)
                    .tracking(isWorkly ? -0.3 : 0)
                Text("Beads Kanban")
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textDisabled)
            }
        }
        .padding(.bottom, 6)
    }

    private func bundledImage(named name: String, fitting size: CGSize) -> NSImage? {
        guard let sourceImage = Bundle.main
            .url(forResource: name, withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        else {
            return nil
        }

        let targetRect = NSRect(origin: .zero, size: size)
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        sourceImage.draw(
            in: targetRect,
            from: NSRect(origin: .zero, size: sourceImage.size),
            operation: .sourceOver,
            fraction: 1
        )
        resizedImage.unlockFocus()
        return resizedImage
    }

    private var viewsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Views")
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.bottom, 2)

            viewModeButton(.kanban, systemName: "rectangle.grid.1x2")
            viewModeButton(.list, systemName: "list.bullet")
            viewModeButton(.graph, systemName: "point.3.connected.trianglepath.dotted")
            viewModeButton(.workspaceDetail, systemName: "building.2")
            viewModeButton(.archive, systemName: "archivebox")
        }
    }

    private func viewModeButton(_ mode: BoardViewMode, systemName: String) -> some View {
        Button {
            appVM.viewMode = mode
        } label: {
            Label(mode.label, systemImage: systemName)
        }
        .buttonStyle(SidebarNavButtonStyle(isActive: appVM.viewMode == mode))
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workspace")
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.bottom, 2)

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
            .buttonStyle(SidebarNavButtonStyle())
            .keyboardShortcut("n", modifiers: [.command])
        }
    }

    @ViewBuilder
    private func counters(store: IssueStore) -> some View {
        let isWorkly = PreferencesStore.activeTheme == .workly
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Stats")
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.top, isWorkly ? 0 : 2)

            counterRow(label: "Backlog", count: store.backlogIssues.count)
            counterRow(label: "Ready", count: store.readyIssues.count)
            counterRow(label: "In Progress", count: store.inProgressIssues.count)
            counterRow(label: "Review", count: store.reviewIssues.count)
            counterRow(label: "Blocked", count: store.blockedIssues.count)
            counterRow(label: "Done", count: store.doneIssues.count)
            if let archiveStore = appVM.archiveStore {
                counterRow(label: "Archived", count: archiveStore.archivedIssues.count)
            }
        }
        .padding(.top, isWorkly ? 0 : 6)
        .padding(isWorkly ? 12 : 0)
        .background(isWorkly ? Color.white.opacity(0.03) : Color.clear)
        .overlay {
            if isWorkly {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isWorkly ? 12 : 0, style: .continuous))
    }

    private func counterRow(label: String, count: Int) -> some View {
        let isWorkly = PreferencesStore.activeTheme == .workly
        let baseText = Text("\(count)")
            .font(WorkstationTheme.Fonts.body(11, weight: .bold))
            .foregroundStyle(WorkstationTheme.textSecondary)
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(WorkstationTheme.borderSoft)

        return HStack(spacing: 10) {
            Circle()
                .fill(color(for: label))
                .frame(width: 6, height: 6)
            Text(label)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
            Spacer()
            
            Group {
                if isWorkly {
                    baseText
                        .overlay(Capsule().stroke(WorkstationTheme.border, lineWidth: 1))
                        .clipShape(Capsule())
                } else {
                    baseText
                        .overlay(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous).stroke(WorkstationTheme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                }
            }
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
        case "Archived":
            return WorkstationTheme.textDisabled
        default:
            return WorkstationTheme.textMuted
        }
    }
}

private struct SidebarNavButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let isWorkly = PreferencesStore.activeTheme == .workly
        configuration.label
            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
            .foregroundStyle(
                isActive
                    ? (isWorkly ? Color(hex: "6f5bf6") : WorkstationTheme.accent)
                    : (configuration.isPressed ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .fill(
                        isActive
                            ? (isWorkly ? Color(hex: "6f5bf6").opacity(0.15) : WorkstationTheme.accentBg)
                            : (configuration.isPressed ? WorkstationTheme.hover : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(
                        isActive
                            ? (isWorkly ? Color(hex: "6f5bf6").opacity(0.3) : WorkstationTheme.accentBorder)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
    }
}
