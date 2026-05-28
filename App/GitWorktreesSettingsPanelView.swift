import SwiftUI
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif
#if canImport(BeadsContract)
import BeadsContract
#endif

struct GitWorktreesSettingsPanelView: View {
    @Bindable var appVM: AppViewModel

    private var issues: [BeadIssue] {
        appVM.issueStore?.issues ?? []
    }

    private var hasStaleWorktrees: Bool {
        guard let workspace = appVM.activeWorkspace else { return false }
        let mainPath = workspace.inspectionURL.resolvingSymlinksInPath().path
        return appVM.gitWorktrees.contains { wt in
            if wt.path == mainPath { return false }
            if let slug = wt.issueSlug {
                if let issue = issues.first(where: { $0.id.lowercased() == slug }) {
                    return issue.status?.lowercased() == "closed"
                } else {
                    return true
                }
            }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection

            if appVM.isRefreshingWorktrees && appVM.gitWorktrees.isEmpty {
                loadingView
            } else if appVM.gitWorktrees.isEmpty {
                emptyView
            } else {
                worktreesList
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkstationTheme.background)
        .task {
            await appVM.refreshGitWorktrees()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Git Worktrees")
                    .font(WorkstationTheme.Fonts.display(22, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Manage agent checkouts, track status against Beads issues, and clean up stale directories.")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await appVM.refreshGitWorktrees() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                .disabled(appVM.isRefreshingWorktrees)

                if hasStaleWorktrees {
                    Button {
                        Task { await appVM.pruneAllStaleWorktrees() }
                    } label: {
                        Label("Prune Stale Worktrees", systemImage: "trash")
                    }
                    .buttonStyle(WorkstationPrimaryButtonStyle())
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading git worktrees...")
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 32))
                .foregroundStyle(WorkstationTheme.textDisabled)
            Text("No git worktrees found.")
                .font(WorkstationTheme.Fonts.body(14, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private var worktreesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let err = appVM.worktreeErrorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(WorkstationTheme.red)
                        Text(err)
                            .font(WorkstationTheme.Fonts.body(12))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                        Spacer()
                        Button {
                            appVM.worktreeErrorMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(WorkstationTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(WorkstationTheme.redBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.redBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                }

                ForEach(appVM.gitWorktrees) { wt in
                    worktreeRow(for: wt)
                }
            }
        }
    }

    @ViewBuilder
    private func worktreeRow(for wt: GitWorktreeInfo) -> some View {
        let isMain = wt.path == appVM.activeWorkspace?.inspectionURL.resolvingSymlinksInPath().path
        let slug = wt.issueSlug
        let matchingIssue = slug.flatMap { s in issues.first(where: { $0.id.lowercased() == s }) }

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: isMain ? "folder.fill" : "arrow.triangle.branch")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isMain ? WorkstationTheme.accent : WorkstationTheme.textSecondary)

                    Text(wt.branchName ?? "Detached HEAD")
                        .font(WorkstationTheme.Fonts.body(14, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                }

                Text(wt.path)
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let issue = matchingIssue {
                    Text("\(issue.id) — \(issue.title)")
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                } else if isMain {
                    Text("Main Repository Checkout")
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                } else {
                    Text("Unknown Issue / Orphans")
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
            }

            if isMain {
                BadgeView(style: .id) {
                    Text("Root")
                        .font(WorkstationTheme.Fonts.label)
                }
            } else if let issue = matchingIssue {
                if issue.status?.lowercased() == "closed" {
                    BadgeView(style: .blocked) {
                        Text("Closed")
                            .font(WorkstationTheme.Fonts.label)
                    }
                } else {
                    BadgeView(style: .accent) {
                        Text("Active")
                            .font(WorkstationTheme.Fonts.label)
                    }
                }
            } else {
                BadgeView(style: .warning) {
                    Text("Missing")
                        .font(WorkstationTheme.Fonts.label)
                }
            }

            if !isMain {
                Button {
                    Task { await appVM.pruneWorktree(path: wt.path, branch: wt.branchName) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                .help("Prune worktree folder and delete local branch")
            } else {
                // Dummy spacing to align buttons
                Spacer()
                    .frame(width: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }
}
