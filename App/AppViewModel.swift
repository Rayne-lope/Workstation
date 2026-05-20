import Combine
import Foundation
import Observation

enum BoardViewMode: String, CaseIterable, Identifiable, Hashable {
    case list
    case kanban

    var id: String { rawValue }
    var label: String {
        switch self {
        case .list: return "List"
        case .kanban: return "Kanban"
        }
    }
}

enum DetailPaneMode: String, Hashable {
    case issue
    case console
}

@MainActor
@Observable
final class AppViewModel {
    var issueStore: IssueStore?
    let agentProfileStore: AgentProfileStore
    let recentProjectsStore: RecentProjectsStore
    let preferencesStore: PreferencesStore
    let shellRunner: ShellCommandRunner
    let gitWorktreeService: GitWorktreeService
    let agentRunHistoryStore: AgentRunHistoryStore
    private let terminalLauncher: any TerminalLaunching
    private let agentLaunchFlowCoordinator: AgentLaunchFlowCoordinator

    var viewMode: BoardViewMode = .list
    var selectedAgentProfileID: UUID = AgentProfile.codingExecutorID

    var isCreatePresented = false
    var isClosePresented = false
    var closeIssueID: String?
    var isReviewFollowupPresented = false
    var reviewFollowupIssueID: String?
    var isBlockerPickerPresented = false
    var blockerPickerIssueID: String?
    var blockerPickerExistingBlockerIDs: Set<String> = []
    var isDebugPresented = false

    var pendingAgentLaunch: PendingAgentLaunch?
    var launchErrorMessage: String?
    var terminalErrorMessage: String?
    var worktreeMessage: String?
    var activeConsoleRunID: UUID?
    var detailPaneMode: DetailPaneMode = .issue
    private(set) var activeWorkspace: ProjectWorkspace?
    private var activeWorkspaceStorageKey: String?

    @ObservationIgnored private var workspaceCancellable: AnyCancellable?
    @ObservationIgnored private var fileWatcher: IssueFileWatcher?

    init(
        shellRunner: ShellCommandRunner = ShellCommandRunner(),
        recentProjectsStore: RecentProjectsStore = RecentProjectsStore(),
        preferencesStore: PreferencesStore = PreferencesStore(),
        agentRunHistoryStore: AgentRunHistoryStore = AgentRunHistoryStore(),
        gitWorktreeService: GitWorktreeService = GitWorktreeService(),
        terminalLauncher: any TerminalLaunching = TerminalLauncherAdapter()
    ) {
        self.shellRunner = shellRunner
        self.gitWorktreeService = gitWorktreeService
        self.agentProfileStore = AgentProfileStore()
        self.recentProjectsStore = recentProjectsStore
        self.preferencesStore = preferencesStore
        self.agentRunHistoryStore = agentRunHistoryStore
        self.terminalLauncher = terminalLauncher
        self.agentLaunchFlowCoordinator = AgentLaunchFlowCoordinator(
            historyStore: agentRunHistoryStore,
            promptGenerator: PromptGenerator(),
            terminalLauncher: terminalLauncher,
            commandRunner: shellRunner
        )
    }

    func bind(workspaceVM: WorkspaceViewModel) {
        workspaceCancellable?.cancel()
        workspaceCancellable = workspaceVM.$workspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] workspace in
                MainActor.assumeIsolated {
                    self?.syncWithWorkspace(workspace)
                }
            }
    }

    func syncWithWorkspace(_ workspace: ProjectWorkspace?) {
        guard let workspace, workspace.validationState == .valid else {
            if issueStore != nil {
                fileWatcher?.stop()
                fileWatcher = nil
                issueStore = nil
                activeWorkspace = nil
                activeWorkspaceStorageKey = nil
                worktreeMessage = nil
            }
            return
        }
        let workspaceKey = workspace.storageKey
        if activeWorkspaceStorageKey == workspaceKey { return }
        activeWorkspace = workspace
        activeWorkspaceStorageKey = workspaceKey
        worktreeMessage = nil
        recentProjectsStore.record(workspace)
        preferencesStore.update { $0.lastSelectedPath = workspace.selectedURL.path }
        let persistedFilterState = preferencesStore.preferences.filterState[workspaceKey] ?? FilterState()
        let store = IssueStore(
            service: BeadsService(commandRunner: shellRunner),
            workingDirectory: workspace.inspectionURL,
            doneVisibilityWindow: preferencesStore.preferences.doneVisibilityWindowSeconds,
            filterState: persistedFilterState
        )
        issueStore = store
        Task { await store.reload() }
        startFileWatcher(for: workspace)
    }

    func reloadIssues() {
        guard let store = issueStore else { return }
        Task { await store.reload() }
    }

    private func startFileWatcher(for workspace: ProjectWorkspace) {
        fileWatcher?.stop()
        fileWatcher = nil
        let target = workspace.inspectionURL
            .appendingPathComponent(".beads", isDirectory: true)
            .appendingPathComponent("issues.jsonl", isDirectory: false)
        let watcher = IssueFileWatcher(path: target) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard self.preferencesStore.preferences.autoReloadEnabled else { return }
                self.reloadIssues()
            }
        }
        do {
            try watcher.start()
            fileWatcher = watcher
        } catch {
            // Fail-soft: focus-hook reload still covers refresh — no UI noise.
            NSLog("IssueFileWatcher start failed: %@", error.localizedDescription)
        }
    }

    func selectedAgentProfile() -> AgentProfile {
        agentProfileStore.profiles.first { $0.id == selectedAgentProfileID }
            ?? agentProfileStore.profiles.first
            ?? AgentProfile.builtInProfiles[0]
    }

    func copyPrompt(for issue: BeadIssue) {
        let payload = agentLaunchPayload(for: issue)
        Clipboard.copy(payload.prompt)
    }

    func copyAgentCommand(for issue: BeadIssue) {
        let payload = agentLaunchPayload(for: issue)
        Clipboard.copy(payload.command)
    }

    func launchSelectedAgent(for issue: BeadIssue) {
        launchAgent(for: issue, profile: selectedAgentProfile())
    }

    func launchAgent(for issue: BeadIssue, profile: AgentProfile) {
        Task { await beginAgentLaunch(for: issue, profile: profile) }
    }

    func launchSelectedAgentInWorktree(for issue: BeadIssue) {
        launchAgentInWorktree(for: issue, profile: selectedAgentProfile())
    }

    func launchAgentInWorktree(for issue: BeadIssue, profile: AgentProfile) {
        Task { await beginWorktreeAgentLaunch(for: issue, profile: profile) }
    }

    func openTerminal(at url: URL, command: String? = nil) {
        do {
            try terminalLauncher.openTerminal(at: url, command: command)
            terminalErrorMessage = nil
        } catch {
            terminalErrorMessage = error.localizedDescription
        }
    }

    func presentCreateIssue() {
        isCreatePresented = true
    }

    func presentCloseSheet(for id: String) {
        closeIssueID = id
        isClosePresented = true
    }

    func presentReviewFollowup(for id: String) {
        reviewFollowupIssueID = id
        isReviewFollowupPresented = true
    }

    func dismissReviewFollowup() {
        isReviewFollowupPresented = false
        reviewFollowupIssueID = nil
    }

    func copyReviewFollowupPrompt(for issueID: String, notes: String) {
        guard let store = issueStore,
              let issue = store.issues.first(where: { $0.id == issueID }) else { return }
        let prompt = PromptGenerator().generateReviewFollowupPrompt(
            issue: issue,
            projectPath: activeWorkspace?.inspectionURL.path,
            userNotes: notes
        )
        Clipboard.copy(prompt)
    }

    func presentBlockerPicker(for issueID: String, existingBlockerIDs: Set<String> = []) {
        blockerPickerIssueID = issueID
        blockerPickerExistingBlockerIDs = existingBlockerIDs
        isBlockerPickerPresented = true
    }

    func presentDebugPanel() {
        isDebugPresented = true
    }

    func dismissCloseSheet() {
        isClosePresented = false
        closeIssueID = nil
    }

    func dismissBlockerPicker() {
        isBlockerPickerPresented = false
        blockerPickerIssueID = nil
        blockerPickerExistingBlockerIDs = []
    }

    func clearTerminalError() {
        terminalErrorMessage = nil
    }

    func clearLaunchError() {
        launchErrorMessage = nil
    }

    func clearWorktreeMessage() {
        worktreeMessage = nil
    }

    func persistFilterState(_ filterState: FilterState) {
        guard let workspaceKey = activeWorkspaceStorageKey else { return }
        preferencesStore.update { preferences in
            if filterState.isEmpty {
                preferences.filterState.removeValue(forKey: workspaceKey)
            } else {
                preferences.filterState[workspaceKey] = filterState.normalizedCopy()
            }
        }
    }

    func presentAgentRunConsole(runID: UUID) {
        activeConsoleRunID = runID
        detailPaneMode = .console
    }

    func presentLatestAgentRunConsole(forIssueID issueID: String) {
        if let record = agentRunHistoryStore.latestRecord(forIssueID: issueID) {
            activeConsoleRunID = record.id
            detailPaneMode = .console
        }
    }

    func dismissAgentRunConsole() {
        activeConsoleRunID = nil
        detailPaneMode = .issue
    }

    func showIssuePane() {
        detailPaneMode = .issue
    }

    func showConsolePane(forIssueID issueID: String) {
        if let record = agentRunHistoryStore.latestRecord(forIssueID: issueID) {
            activeConsoleRunID = record.id
            detailPaneMode = .console
        }
    }

    func resetDetailPaneToIssue() {
        detailPaneMode = .issue
    }

    func activeConsoleRecord() -> AgentRunRecord? {
        guard let id = activeConsoleRunID else { return nil }
        return agentRunHistoryStore.record(id: id)
    }

    func updateAgentRunStatus(id: UUID, status: AgentRunStatus) {
        agentRunHistoryStore.updateStatus(id: id, status: status)
    }

    func updateAgentRunNotes(id: UUID, notes: String) {
        agentRunHistoryStore.updateNotes(id: id, notes: notes)
    }

    func openTerminalForAgentRun(_ record: AgentRunRecord) {
        guard !record.projectPath.isEmpty else {
            terminalErrorMessage = "No project path recorded for this run."
            return
        }
        let url = URL(fileURLWithPath: record.projectPath, isDirectory: true)
        let command = record.command.isEmpty ? nil : record.command
        openTerminal(at: url, command: command)
    }

    func cancelPendingAgentLaunch() {
        pendingAgentLaunch = nil
    }

    func continuePendingAgentLaunch() {
        guard let pending = pendingAgentLaunch else { return }
        pendingAgentLaunch = nil
        launchErrorMessage = nil
        terminalErrorMessage = nil
        Task {
            await performAgentLaunch(
                for: pending.issue,
                profile: pending.profile,
                workspace: pending.workspace
            )
        }
    }

    private func agentLaunchPayload(for issue: BeadIssue) -> AgentRunLaunchPayload {
        let profile = selectedAgentProfile()
        return agentLaunchFlowCoordinator.buildPayload(
            for: issue,
            profile: profile,
            projectPath: activeWorkspace?.inspectionURL.path
        )
    }

    private func beginAgentLaunch(for issue: BeadIssue, profile: AgentProfile) async {
        guard let workspace = activeWorkspace else { return }
        guard profile.canExecuteCode else { return }

        pendingAgentLaunch = nil
        launchErrorMessage = nil
        terminalErrorMessage = nil
        worktreeMessage = nil

        do {
            let gitStatus = try await agentLaunchFlowCoordinator.statusSummary(in: workspace.inspectionURL)
            if gitStatus.isDirty {
                pendingAgentLaunch = PendingAgentLaunch(
                    issue: issue,
                    profile: profile,
                    workspace: workspace,
                    gitStatus: gitStatus
                )
                return
            }

            await performAgentLaunch(
                for: issue,
                profile: profile,
                workspace: workspace
            )
        } catch {
            launchErrorMessage = error.localizedDescription
        }
    }

    private func beginWorktreeAgentLaunch(for issue: BeadIssue, profile: AgentProfile) async {
        guard let workspace = activeWorkspace else { return }
        guard profile.canExecuteCode else { return }

        pendingAgentLaunch = nil
        launchErrorMessage = nil
        terminalErrorMessage = nil
        worktreeMessage = nil

        do {
            let worktree = try await gitWorktreeService.createWorktree(for: issue, in: workspace)
            let session = await agentLaunchFlowCoordinator.prepareLaunchSession(
                for: issue,
                profile: profile,
                projectPath: worktree.worktreeURL.path,
                issueStore: issueStore
            )

            guard let session else { return }

            worktreeMessage = "Worktree created at \(worktree.worktreeURL.path)"
            activeConsoleRunID = session.id
            detailPaneMode = .console
            Clipboard.copy(session.payload.prompt)
            do {
                try agentLaunchFlowCoordinator.openTerminal(
                    for: session,
                    projectURL: worktree.worktreeURL,
                    terminalCommand: session.payload.command
                )
                terminalErrorMessage = nil
            } catch {
                terminalErrorMessage = error.localizedDescription
            }
        } catch {
            launchErrorMessage = error.localizedDescription
        }
    }

    private func performAgentLaunch(
        for issue: BeadIssue,
        profile: AgentProfile,
        workspace: ProjectWorkspace
    ) async {
        guard let session = await agentLaunchFlowCoordinator.prepareLaunchSession(
            for: issue,
            profile: profile,
            projectPath: workspace.inspectionURL.path,
            issueStore: issueStore
        ) else {
            return
        }

        activeConsoleRunID = session.id
        detailPaneMode = .console
        Clipboard.copy(session.payload.prompt)
        do {
            try agentLaunchFlowCoordinator.openTerminal(
                for: session,
                projectURL: workspace.inspectionURL,
                terminalCommand: session.payload.command
            )
            terminalErrorMessage = nil
        } catch {
            terminalErrorMessage = error.localizedDescription
        }
    }
}

private struct TerminalLauncherAdapter: TerminalLaunching {
    func openTerminal(at projectURL: URL, command: String?) throws {
        if let command, !command.isEmpty {
            try TerminalLauncher.openTerminal(at: projectURL, command: command)
        } else {
            try TerminalLauncher.openTerminal(at: projectURL)
        }
    }
}
