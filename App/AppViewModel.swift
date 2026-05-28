import Combine
import Foundation
import Observation
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

enum BoardViewMode: String, CaseIterable, Identifiable, Hashable {
    case list
    case kanban
    case graph
    case workspaceDetail
    case archive

    var id: String { rawValue }
    var label: String {
        switch self {
        case .list: return "List"
        case .kanban: return "Kanban"
        case .graph: return "Graph"
        case .workspaceDetail: return "Workspace"
        case .archive: return "Archive"
        }
    }
}

enum DetailPaneMode: String, Hashable {
    case issue
    case console
    case bulkAction
    case copilot
}

@MainActor
@Observable
final class AppViewModel {
    var issueStore: IssueStore?
    var recurringStore: RecurringStore?
    var focusSessionStore: FocusSessionStore?
    var archiveStore: ArchiveStore?
    let agentProfileStore: AgentProfileStore
    let recentProjectsStore: RecentProjectsStore
    let preferencesStore: PreferencesStore
    let shellRunner: ShellCommandRunner
    let gitWorktreeService: GitWorktreeService
    let agentRunHistoryStore: AgentRunHistoryStore
    let agentRunTranscriptStore: AgentRunTranscriptStore
    let copilotTranscriptStore: CopilotTranscriptStore
    let localAIConnectionTester: any LocalAIConnectionTesting
    let localAIService: LocalAIService
    private let terminalLauncher: any TerminalLaunching
    private let agentLaunchFlowCoordinator: AgentLaunchFlowCoordinator

    var sessionPromptTokens: Int = 0
    var sessionCompletionTokens: Int = 0

    var viewMode: BoardViewMode = .list
    var selectedAgentProfileID: UUID = AgentProfile.codingExecutorID
    var bulkAgentProfileID: UUID = AgentProfile.codingExecutorID

    var isCreatePresented = false
    var isClosePresented = false
    var closeIssue: BeadIssue?
    var isBulkClosePresented = false
    var isReviewFollowupPresented = false
    var reviewFollowupIssueID: String?
    var isBlockerPickerPresented = false
    var blockerPickerIssueID: String?
    var blockerPickerExistingBlockerIDs: Set<String> = []
    var isDebugPresented = false
    var isLocalAISettingsPresented = false
    var isSettingsPresented = false
    var settingsSelectedTab: SettingsTab = .general
    var localAISuggestionPreview: LocalAISuggestionPreviewState?
    var commandPaletteStore: CommandPaletteStore?
    var isQuickCapturePresented = false
    var activeFocusIssueID: String?
    var isFocusPaused: Bool = false
    var focusElapsedMs: Int64 = 0
    var localAIStatusMessage: String?
    var localAIStatusMessageIsError = false

    var gitWorktrees: [GitWorktreeInfo] = []
    var isRefreshingWorktrees = false
    var worktreeErrorMessage: String? = nil

    var pendingAgentLaunch: PendingAgentLaunch?
    var pendingWorktreeLaunch: PendingWorktreeLaunch?
    var launchErrorMessage: String?
    var terminalErrorMessage: String?
    var worktreeMessage: String?
    var activeConsoleRunID: UUID?
    var detailPaneMode: DetailPaneMode = .issue
    var rightPaneWidth: CGFloat = 440
    var localAIConnectionMessage: String?
    var localAIConnectionMessageIsError = false
    var isTestingLocalAIConnection = false

    // Approval confirmation state for critical risk approvals
    var pendingCriticalApproval: AgentApprovalRequest?
    var isApprovalConfirmationPresented: Bool = false

    private(set) var activeWorkspace: ProjectWorkspace?
    private var activeWorkspaceStorageKey: String?

    @ObservationIgnored private var workspaceCancellable: AnyCancellable?
    @ObservationIgnored private var fileWatcher: IssueFileWatcher?
    @ObservationIgnored private var ptyFlushTimers: [UUID: Timer] = [:]
    @ObservationIgnored private var timelineIngestors: [UUID: AgentTimelineIngestor] = [:]

    init(
        shellRunner: ShellCommandRunner = ShellCommandRunner(),
        recentProjectsStore: RecentProjectsStore = RecentProjectsStore(),
        preferencesStore: PreferencesStore = PreferencesStore(),
        agentRunHistoryStore: AgentRunHistoryStore = AgentRunHistoryStore(),
        agentRunTranscriptStore: AgentRunTranscriptStore = AgentRunTranscriptStore(),
        copilotTranscriptStore: CopilotTranscriptStore = CopilotTranscriptStore(),
        gitWorktreeService: GitWorktreeService? = nil,
        terminalLauncher: any TerminalLaunching = TerminalLauncherAdapter(),
        localAIConnectionTester: any LocalAIConnectionTesting = OpenCodeConnectionTester(),
        localAIService: LocalAIService = LocalAIService()
    ) {
        self.shellRunner = shellRunner
        self.gitWorktreeService = gitWorktreeService ?? GitWorktreeService(commandRunner: shellRunner)
        self.agentProfileStore = AgentProfileStore()
        self.recentProjectsStore = recentProjectsStore
        self.preferencesStore = preferencesStore
        self.agentRunHistoryStore = agentRunHistoryStore
        self.agentRunTranscriptStore = agentRunTranscriptStore
        self.copilotTranscriptStore = copilotTranscriptStore
        self.localAIConnectionTester = localAIConnectionTester
        self.localAIService = localAIService
        self.terminalLauncher = terminalLauncher
        self.agentLaunchFlowCoordinator = AgentLaunchFlowCoordinator(
            historyStore: agentRunHistoryStore,
            promptGenerator: PromptGenerator(),
            terminalLauncher: terminalLauncher,
            commandRunner: shellRunner
        )
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ComBeadsAppTokenUsageNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let prompt = userInfo["promptTokens"] as? Int,
                  let completion = userInfo["completionTokens"] as? Int else {
                return
            }
            self.sessionPromptTokens += prompt
            self.sessionCompletionTokens += completion
            self.preferencesStore.update { prefs in
                prefs.localAI.totalPromptTokens += prompt
                prefs.localAI.totalCompletionTokens += completion
            }
        }



        NotificationCenter.default.addObserver(
            forName: .ptyProcessTerminated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let runID = userInfo["runID"] as? UUID else {
                return
            }
            self.flushBufferImmediately(runID: runID)
            self.agentRunTranscriptStore.skipPersist = false
            self.agentRunTranscriptStore.forcePersist()
            let exitCode = userInfo["exitCode"] as? Int ?? 0
            if exitCode == 0 {
                self.updateAgentRunStatus(id: runID, status: .needsReview)
            } else {
                self.updateAgentRunStatus(id: runID, status: .failed)
            }
        }
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
                recurringStore = nil
                focusSessionStore = nil
                archiveStore = nil
                activeWorkspace = nil
                activeWorkspaceStorageKey = nil
                worktreeMessage = nil
                clearFocusState()
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
        let recurring = RecurringStore(workingDirectory: workspace.inspectionURL)
        recurring.load()
        recurringStore = recurring
        store.recurringIDs = recurring.recurringIDs
        let focusStore = FocusSessionStore(workingDirectory: workspace.inspectionURL)
        focusStore.load()
        focusSessionStore = focusStore
        let archive = ArchiveStore(workingDirectory: workspace.inspectionURL)
        archive.load()
        archiveStore = archive
        Task { await store.reload() }
        startFileWatcher(for: workspace)
    }

    func reloadIssues() {
        guard let store = issueStore else { return }
        Task { await store.reload() }
    }

    func archiveClosedIssues() async {
        guard let store = issueStore, let archive = archiveStore else { return }
        do {
            let closed = try await store.service.closedIssues(in: store.workingDirectory)
            guard !closed.isEmpty else { return }
            await archive.archiveIssues(closed, service: store.service)
            await store.reload()
        } catch {
            NSLog("Archive sweep failed: %@", error.localizedDescription)
        }
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

    func analyzeBacklog() {
        guard let store = issueStore else { return }
        let snapshot = backlogAnalysisSnapshot(from: store)
        let action = LocalAIAction.backlogAnalysis(issues: snapshot.issues)
        localAIStatusMessage = "Analyzing \(snapshot.sourceLabel.lowercased())..."
        localAIStatusMessageIsError = false

        Task {
            do {
                let suggestion = try await self.requestLocalAIResponse(for: action)
                await MainActor.run {
                    self.presentLocalAISuggestionPreview(
                        title: "Backlog Organization Suggestions",
                        subtitle: snapshot.subtitle,
                        sourceLabel: snapshot.sourceLabel,
                        generatedText: suggestion,
                        primaryActionTitle: "Done",
                        regenerate: { [weak self] in
                            guard let self else { throw CancellationError() }
                            return try await self.requestLocalAIResponse(for: action)
                        },
                        onApply: { [weak self] _ in
                            self?.dismissLocalAISuggestionPreview()
                        }
                    )
                    self.clearLocalAIStatus()
                }
            } catch {
                await MainActor.run {
                    self.localAIStatusMessage = error.localizedDescription
                    self.localAIStatusMessageIsError = true
                }
            }
        }
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

    /// Combined assign + launch handoff. If the assignee maps to an AI executor profile,
    /// launches the agent in a worktree (which auto-claims via prepareLaunchSession).
    /// Otherwise performs a plain assignee update.
    func assignAndLaunchIfExecutor(for issue: BeadIssue, assignee: String) {
        if let profile = agentProfileStore.executorProfile(forAssignee: assignee) {
            launchAgentInWorktree(for: issue, profile: profile)
        } else {
            guard let store = issueStore else { return }
            Task { await store.update(id: issue.id, UpdateIssueInput(assignee: assignee)) }
        }
    }

    func retryPendingWorktreeLaunch() {
        guard let pending = pendingWorktreeLaunch else { return }
        let issue = pending.issue
        let profile = pending.profile
        pendingWorktreeLaunch = nil
        Task {
            await beginWorktreeAgentLaunch(for: issue, profile: profile)
        }
    }

    func continuePendingWorktreeLaunch() {
        guard let pending = pendingWorktreeLaunch else { return }
        guard !pending.preflight.isBlocked else { return }
        pendingWorktreeLaunch = nil
        Task {
            await performWorktreeAgentLaunch(
                for: pending.issue,
                profile: pending.profile,
                workspace: pending.workspace,
                preflight: pending.preflight
            )
        }
    }

    func cancelPendingWorktreeLaunch() {
        pendingWorktreeLaunch = nil
    }

    func launchWorktreeSetup(for hint: WorkspaceSetupHint) {
        guard let pending = pendingWorktreeLaunch else { return }
        openTerminal(at: pending.workspace.inspectionURL, command: hint.command)
    }

    func openTerminal(at url: URL, command: String? = nil) {
        do {
            try terminalLauncher.openTerminal(at: url, command: command)
            terminalErrorMessage = nil
        } catch {
            terminalErrorMessage = error.localizedDescription
        }
    }

    func cleanupAndRetryWorktreeLaunch() {
        guard let pending = pendingWorktreeLaunch else { return }
        let issue = pending.issue
        let profile = pending.profile
        let workspace = pending.workspace
        pendingWorktreeLaunch = nil
        Task {
            await gitWorktreeService.cleanupOrphanWorktree(for: issue, in: workspace)
            await beginWorktreeAgentLaunch(for: issue, profile: profile)
        }
    }

    func presentCreateIssue() {
        isCreatePresented = true
    }

    func presentCloseSheet(for issue: BeadIssue) {
        closeIssue = issue
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

    // MARK: - Recurring tasks

    func isRecurring(id: String) -> Bool {
        recurringStore?.isRecurring(id: id) ?? false
    }

    func recurringMetadata(for id: String) -> RecurringMetadata? {
        recurringStore?.metadata(id: id)
    }

    func toggleRecurring(for id: String) {
        guard let recurringStore else { return }
        if recurringStore.isRecurring(id: id) {
            recurringStore.unmarkRecurring(id: id)
        } else {
            recurringStore.markRecurring(id: id)
        }
        issueStore?.recurringIDs = recurringStore.recurringIDs
    }

    func setCadence(for id: String, days: Int?) {
        recurringStore?.setCadence(id: id, days: days)
        if let recurringStore {
            issueStore?.recurringIDs = recurringStore.recurringIDs
        }
    }

    // ── Epic helpers ──────────────────────────────────────────────────────────

    /// Progress for an epic issue. Returns `nil` if the issue isn't an epic or isn't found.
    func epicProgress(for id: String) -> (done: Int, total: Int)? {
        guard let store = issueStore,
              store.issues.first(where: { $0.id == id })?.issueType?.lowercased() == "epic"
        else { return nil }
        return store.epicProgress(id: id)
    }

    /// Title of the parent epic, if any.
    func epicTitle(for parentID: String) -> String? {
        issueStore?.issues.first(where: { $0.id == parentID })?.title
    }

    /// Set (or clear) the parent of an issue. Pass `nil` epicID to remove parent.
    func setParent(childID: String, epicID: String?) async {
        guard let store = issueStore else { return }
        await store.update(id: childID, UpdateIssueInput(parentID: epicID ?? ""))
    }

    /// Mark a recurring issue's run as complete: append history entry then reset the issue
    /// back to Ready (status=open) so it shows up again on the board. Does NOT call `bd close`.
    /// Returns true on success.
    @discardableResult
    func completeRecurringRun(for issueID: String, notes: String?) async -> Bool {
        guard let store = issueStore, let recurringStore else { return false }
        guard let issue = store.issues.first(where: { $0.id == issueID }) else { return false }

        let entry = RecurringHistoryEntry(
            completedAt: Date(),
            completedBy: issue.assignee,
            notes: notes.flatMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        )
        recurringStore.appendHistory(id: issueID, entry: entry)
        store.recurringIDs = recurringStore.recurringIDs

        // Reset status + drop the human-review label so the issue lands back in Ready.
        if (issue.labels ?? []).contains(KanbanStateMapper.humanReviewLabel) {
            await store.clearHumanReview(id: issueID)
        }
        await store.update(id: issueID, UpdateIssueInput(status: "open"))
        return store.errorMessage == nil
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
        closeIssue = nil
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

    func presentLocalAISettings() {
        isLocalAISettingsPresented = true
    }

    func dismissLocalAISettings() {
        isLocalAISettingsPresented = false
    }

    func presentCommandPalette() {
        guard let store = issueStore else { return }
        commandPaletteStore = CommandPaletteStore(store: store, appVM: self)
    }

    func dismissCommandPalette() {
        commandPaletteStore = nil
    }

    func presentQuickCapture() {
        _quickCaptureStore = nil
        guard issueStore != nil else { return }
        isQuickCapturePresented = true
    }

    func dismissQuickCapture() {
        _quickCaptureStore = nil
        isQuickCapturePresented = false
    }

    var localAISettings: LocalAISettings {
        preferencesStore.preferences.localAI
    }

    var quickCaptureStore: QuickCaptureStore? {
        guard let store = issueStore else { return nil }
        if _quickCaptureStore == nil || _quickCaptureStore?.store !== store {
            _quickCaptureStore = QuickCaptureStore(store: store, appVM: self)
        }
        return _quickCaptureStore
    }

    private var _quickCaptureStore: QuickCaptureStore?

    func setLocalAIEnabled(_ isEnabled: Bool) {
        preferencesStore.update { $0.localAI.isEnabled = isEnabled }
        clearLocalAIConnectionStatus()
    }

    func setLocalAIProvider(_ provider: LocalAIProvider) {
        preferencesStore.update {
            $0.localAI.provider = provider
        }
        clearLocalAIConnectionStatus()
    }

    func setLocalAIBaseURL(_ baseURL: String) {
        preferencesStore.update { $0.localAI.baseURL = baseURL }
        clearLocalAIConnectionStatus()
    }

    func setLocalAIFastModel(_ model: String) {
        preferencesStore.update { $0.localAI.fastModel = model }
        clearLocalAIConnectionStatus()
    }

    func setLocalAIStrongModel(_ model: String) {
        preferencesStore.update { $0.localAI.strongModel = model }
        clearLocalAIConnectionStatus()
    }

    func setLocalAIAPIKey(_ apiKey: String) {
        preferencesStore.update { $0.localAI.apiKey = apiKey }
        clearLocalAIConnectionStatus()
    }

    func setLocalAICopilotSystemPrompt(_ prompt: String) {
        preferencesStore.update { $0.localAI.copilotSystemPrompt = prompt }
    }

    func setLocalAICopilotTokenBudget(_ budget: Int) {
        preferencesStore.update { $0.localAI.copilotTokenBudget = budget }
    }

    func resetLocalAITokenUsage() {
        preferencesStore.update {
            $0.localAI.totalPromptTokens = 0
            $0.localAI.totalCompletionTokens = 0
        }
    }

    // MARK: - Settings

    func presentSettings(tab: SettingsTab = .general) {
        settingsSelectedTab = tab
        isSettingsPresented = true
    }

    func dismissSettings() {
        isSettingsPresented = false
    }

    func setAutoRestoreOnLaunch(_ value: Bool) {
        preferencesStore.update { $0.autoRestoreOnLaunch = value }
    }

    func setAutoReloadEnabled(_ value: Bool) {
        preferencesStore.update { $0.autoReloadEnabled = value }
    }

    func setDoneVisibilityWindowSeconds(_ value: TimeInterval) {
        preferencesStore.update { $0.doneVisibilityWindowSeconds = value }
    }

    func setTheme(_ theme: AppTheme) {
        preferencesStore.update { $0.theme = theme }
    }

    func setKanbanCompactMode(_ value: Bool) {
        preferencesStore.update { $0.kanbanCompactMode = value }
    }

    func resetSettingsToDefaults() {
        preferencesStore.resetToDefaults()
        agentProfileStore.resetToDefaults()
    }

    func refreshGitWorktrees() async {
        guard let workspace = activeWorkspace else {
            gitWorktrees = []
            return
        }
        isRefreshingWorktrees = true
        defer { isRefreshingWorktrees = false }
        do {
            gitWorktrees = try await gitWorktreeService.listWorktrees(in: workspace.inspectionURL)
            worktreeErrorMessage = nil
        } catch {
            worktreeErrorMessage = error.localizedDescription
        }
    }

    func pruneWorktree(path: String, branch: String?) async {
        guard let workspace = activeWorkspace else { return }
        do {
            try await gitWorktreeService.pruneWorktree(path: path, branchName: branch, in: workspace.inspectionURL)
            await refreshGitWorktrees()
        } catch {
            worktreeErrorMessage = error.localizedDescription
        }
    }

    func pruneAllStaleWorktrees() async {
        guard let workspace = activeWorkspace else { return }
        let currentWorktrees = gitWorktrees
        for wt in currentWorktrees {
            if wt.path == workspace.inspectionURL.resolvingSymlinksInPath().path {
                continue
            }
            
            var isStale = false
            if let slug = wt.issueSlug {
                if let store = issueStore {
                    if let issue = store.issues.first(where: { $0.id.lowercased() == slug }) {
                        if issue.status?.lowercased() == "closed" {
                            isStale = true
                        }
                    } else {
                        isStale = true
                    }
                }
            }
            
            if isStale {
                do {
                    try await gitWorktreeService.pruneWorktree(path: wt.path, branchName: wt.branchName, in: workspace.inspectionURL)
                } catch {
                    NSLog("Failed to batch-prune worktree at %@: %@", wt.path, error.localizedDescription)
                }
            }
        }
        await refreshGitWorktrees()
    }

    func setDefaultIssueType(_ type: String) {
        preferencesStore.update { $0.defaultIssueType = type }
    }

    func setDefaultIssuePriority(_ priority: Int) {
        preferencesStore.update { $0.defaultIssuePriority = priority }
    }

    func setDefaultCloseReasonTemplate(_ template: String) {
        preferencesStore.update { $0.defaultCloseReasonTemplate = template }
    }

    func testLocalAIConnection() {
        let settings = preferencesStore.preferences.localAI
        localAIConnectionMessage = "Testing \(settings.provider.displayName) connection..."
        localAIConnectionMessageIsError = false
        isTestingLocalAIConnection = true
        let tester = localAIConnectionTester

        Task {
            do {
                let result = try await tester.testConnection(settings: settings)
                await MainActor.run {
                    self.isTestingLocalAIConnection = false
                    self.localAIConnectionMessage = result.message
                    self.localAIConnectionMessageIsError = false
                }
            } catch {
                await MainActor.run {
                    self.isTestingLocalAIConnection = false
                    self.localAIConnectionMessage = error.localizedDescription
                    self.localAIConnectionMessageIsError = true
                }
            }
        }
    }

    func requestLocalAIResponse(for action: LocalAIAction) async throws -> String {
        try await localAIService.generate(for: action, settings: preferencesStore.preferences.localAI)
    }

    func requestLocalAIResponseStream(for action: LocalAIAction) throws -> AsyncThrowingStream<String, Error> {
        try localAIService.generateStream(for: action, settings: preferencesStore.preferences.localAI)
    }

    func presentLocalAISuggestionPreview(
        title: String,
        subtitle: String,
        sourceLabel: String,
        generatedText: String,
        primaryActionTitle: String = "Apply",
        regenerate: @escaping @MainActor () async throws -> String,
        onApply: @escaping @MainActor (String) -> Void
    ) {
        localAISuggestionPreview = LocalAISuggestionPreviewState(
            title: title,
            subtitle: subtitle,
            sourceLabel: sourceLabel,
            generatedText: generatedText,
            primaryActionTitle: primaryActionTitle,
            regenerate: regenerate,
            onApply: onApply
        )
    }

    func dismissLocalAISuggestionPreview() {
        localAISuggestionPreview = nil
    }

    func clearLocalAIStatus() {
        localAIStatusMessage = nil
        localAIStatusMessageIsError = false
    }

    private func clearLocalAIConnectionStatus() {
        clearLocalAIStatus()
        localAIConnectionMessage = nil
        localAIConnectionMessageIsError = false
        isTestingLocalAIConnection = false
    }

    private func backlogAnalysisSnapshot(from store: IssueStore) -> (issues: [BeadIssue], sourceLabel: String, subtitle: String) {
        let selectedIssues = store.selectedIssues()
        if !selectedIssues.isEmpty {
            let selectedBacklogIssues = selectedIssues.filter { issue in
                KanbanStateMapper.column(
                    for: issue,
                    readyIDs: store.readyIssueIDs,
                    blockedIDs: store.blockedByDependencyIDs
                ) == .backlog
            }
            if !selectedBacklogIssues.isEmpty {
                return (
                    issues: selectedBacklogIssues,
                    sourceLabel: "Selected Backlog",
                    subtitle: analysisSubtitle(for: selectedBacklogIssues.count, source: "selected backlog")
                )
            }
        }

        let backlogIssues = store.backlogIssues
        return (
            issues: backlogIssues,
            sourceLabel: "Visible Backlog",
            subtitle: analysisSubtitle(for: backlogIssues.count, source: "visible backlog")
        )
    }

    private func analysisSubtitle(for issueCount: Int, source: String) -> String {
        let noun = issueCount == 1 ? "issue" : "issues"
        return "\(issueCount) \(noun) · \(source)"
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

    // MARK: - Approval Confirmation

    /// Presents the confirmation sheet for critical risk approvals.
    func presentCriticalApprovalConfirmation(for approval: AgentApprovalRequest) {
        pendingCriticalApproval = approval
        isApprovalConfirmationPresented = true
    }

    /// Dismisses the approval confirmation sheet.
    func dismissApprovalConfirmation() {
        pendingCriticalApproval = nil
        isApprovalConfirmationPresented = false
    }

    /// Confirms a critical approval after user has typed "APPROVE".
    func confirmCriticalApproval() {
        guard let approval = pendingCriticalApproval else { return }
        let runID = approval.runID

        // Validate approval is still active
        guard let activeApproval = AgentTimelineStore.shared.activeApproval(forRunID: runID) else {
            dismissApprovalConfirmation()
            return
        }

        guard activeApproval.state == .active && activeApproval.promptHash == approval.promptHash else {
            dismissApprovalConfirmation()
            return
        }

        // Set state to responding
        AgentTimelineStore.shared.updateApprovalState(forRunID: runID, newState: .responding)

        // Write to PTY
        let success = PTYProcessRegistry.shared.writeInput(for: runID, text: approval.proposedInput)

        // Update final state
        let finalState: ApprovalState = success ? .accepted : .failedToSend
        AgentTimelineStore.shared.updateApprovalState(forRunID: runID, newState: finalState)

        dismissApprovalConfirmation()
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

    func showCopilotPane() {
        detailPaneMode = .copilot
    }

    // MARK: - Multi-select bulk actions

    func showBulkActionPane() {
        detailPaneMode = .bulkAction
    }

    func presentBulkCloseSheet() {
        isBulkClosePresented = true
    }

    func dismissBulkCloseSheet() {
        isBulkClosePresented = false
    }

    func bulkClaim() {
        guard let store = issueStore else { return }
        let ids = Array(store.selectedIssueIDs)
        Task {
            for id in ids {
                await store.claim(id: id)
            }
        }
    }

    func bulkMarkHumanReview() {
        guard let store = issueStore else { return }
        let ids = Array(store.selectedIssueIDs)
        Task {
            for id in ids {
                await store.requestHumanReview(id: id)
            }
        }
    }

    func bulkClose(reason: String) {
        guard let store = issueStore else { return }
        let ids = Array(store.selectedIssueIDs)
        guard !ids.isEmpty else { return }
        Task { @MainActor in
            for id in ids {
                await store.close(id: id, reason: reason)
            }
            store.clearSelection()
            detailPaneMode = .issue
        }
    }

    func copyBulkPrompts() {
        guard let store = issueStore else { return }
        let issues = store.selectedIssues()
        guard !issues.isEmpty else { return }
        let total = issues.count
        let blocks = issues.enumerated().map { idx, issue -> String in
            let payload = agentLaunchPayload(for: issue)
            return "--- ISSUE \(idx + 1)/\(total): \(issue.id) ---\n\(payload.prompt)"
        }
        Clipboard.copy(blocks.joined(separator: "\n\n"))
    }

    func bulkLaunchAgents() {
        guard let store = issueStore, let workspace = activeWorkspace else { return }
        let selectedIssues = store.selectedIssues()
        guard !selectedIssues.isEmpty else { return }
        
        let profile = agentProfileStore.profiles.first(where: { $0.id == bulkAgentProfileID }) ?? selectedAgentProfile()
        guard profile.canExecuteCode else { return }

        // Clear previous states
        pendingAgentLaunch = nil
        pendingWorktreeLaunch = nil
        launchErrorMessage = nil
        terminalErrorMessage = nil
        worktreeMessage = nil

        // Compile and copy bulk prompts to clipboard first so they are all preserved together!
        let total = selectedIssues.count
        let blocks = selectedIssues.enumerated().map { idx, issue -> String in
            let payload = agentLaunchPayload(for: issue)
            return "--- ISSUE \(idx + 1)/\(total): \(issue.id) ---\n\(payload.prompt)"
        }
        Clipboard.copy(blocks.joined(separator: "\n\n"))

        // Clear multi-selection and hide the bulk action panel
        store.clearSelection()
        detailPaneMode = .issue

        Task {
            for issue in selectedIssues {
                let preflight = await gitWorktreeService.preflightLaunch(for: issue, in: workspace)
                if preflight.isBlocked {
                    await gitWorktreeService.cleanupOrphanWorktree(for: issue, in: workspace)
                }
                let freshPreflight = await gitWorktreeService.preflightLaunch(for: issue, in: workspace)
                await performWorktreeAgentLaunch(
                    for: issue,
                    profile: profile,
                    workspace: workspace,
                    preflight: freshPreflight,
                    copyToClipboard: false
                )
            }
        }
    }

    func clearMultiSelection() {
        issueStore?.clearSelection()
        if detailPaneMode == .bulkAction {
            detailPaneMode = .issue
        }
    }

    func activeConsoleRecord() -> AgentRunRecord? {
        guard let id = activeConsoleRunID else { return nil }
        return agentRunHistoryStore.record(id: id)
    }

    func killActiveAgent(runID: UUID) {
        PTYProcessRegistry.shared.killProcess(for: runID)
        flushBufferImmediately(runID: runID)
        agentRunTranscriptStore.skipPersist = false
        agentRunTranscriptStore.forcePersist()
        updateAgentRunStatus(id: runID, status: .failed)
    }

    func clearLiveLogs(runID: UUID) {
        agentRunTranscriptStore.deleteAll(forRunID: runID)
    }

    func sendTerminalInput(runID: UUID, text: String) {
        PTYProcessRegistry.shared.writeInput(for: runID, text: text)
    }

    func updateAgentRunStatus(id: UUID, status: AgentRunStatus) {
        agentRunHistoryStore.updateStatus(id: id, status: status)
    }

    func updateAgentRunNotes(id: UUID, notes: String) {
        agentRunHistoryStore.updateNotes(id: id, notes: notes)
    }

    func transcriptMessages(for runID: UUID) -> [AgentRunMessage] {
        agentRunTranscriptStore.messages(forRunID: runID)
    }

    @discardableResult
    func appendTranscriptMessage(
        runID: UUID,
        role: AgentRunMessageRole,
        content: String
    ) -> AgentRunMessage? {
        agentRunTranscriptStore.append(runID: runID, role: role, content: content)
    }

    private func startRepeatingFlushTimer(for runID: UUID) {
        ptyFlushTimers[runID]?.invalidate()
        
        let timer = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.flushBuffer(for: runID)
        }
        RunLoop.main.add(timer, forMode: .default)
        ptyFlushTimers[runID] = timer
    }

    private func flushBuffer(for runID: UUID) {
        guard let buffer = PTYProcessRegistry.shared.buffer(for: runID) else {
            ptyFlushTimers[runID]?.invalidate()
            ptyFlushTimers.removeValue(forKey: runID)
            return
        }

        let pendingText = buffer.take()
        guard !pendingText.isEmpty else { return }

        self.appendTranscriptMessage(runID: runID, role: .agent, content: pendingText)

        // Ingest timeline lines for the compact timeline view
        ingestTimelineLines(for: runID)
    }

    private func ingestTimelineLines(for runID: UUID) {
        guard let streamBuffer = PTYProcessRegistry.shared.streamBuffer(for: runID) else { return }
        let lines = streamBuffer.takeLines()
        guard !lines.isEmpty else { return }

        let ingestor = timelineIngestors[runID] ?? {
            let newIngestor = AgentTimelineIngestor(runID: runID)
            timelineIngestors[runID] = newIngestor
            return newIngestor
        }()

        for line in lines {
            let deltas = ingestor.ingest(line: line)
            for delta in deltas {
                AgentTimelineStore.shared.apply(delta: delta, forRunID: runID)
            }
        }
    }

    private func flushBufferImmediately(runID: UUID) {
        ptyFlushTimers[runID]?.invalidate()
        ptyFlushTimers.removeValue(forKey: runID)

        if let buffer = PTYProcessRegistry.shared.buffer(for: runID) {
            let pendingText = buffer.take()
            if !pendingText.isEmpty {
                self.appendTranscriptMessage(runID: runID, role: .agent, content: pendingText)
            }
            PTYProcessRegistry.shared.removeBuffer(for: runID)
        }

        // Flush remaining lines from stream buffer and ingest
        if let streamBuffer = PTYProcessRegistry.shared.streamBuffer(for: runID) {
            streamBuffer.flush()
            let lines = streamBuffer.takeLines()
            if !lines.isEmpty {
                let ingestor = timelineIngestors[runID] ?? {
                    let newIngestor = AgentTimelineIngestor(runID: runID)
                    timelineIngestors[runID] = newIngestor
                    return newIngestor
                }()
                for line in lines {
                    let deltas = ingestor.ingest(line: line)
                    for delta in deltas {
                        AgentTimelineStore.shared.apply(delta: delta, forRunID: runID)
                    }
                }
            }
        }

        // Remove ingestor to prevent memory leaks
        timelineIngestors.removeValue(forKey: runID)
    }

    func updateTranscriptMessageContent(id: UUID, content: String) {
        agentRunTranscriptStore.updateContent(id: id, content: content)
    }

    func updateTranscriptMessageRole(id: UUID, role: AgentRunMessageRole) {
        agentRunTranscriptStore.updateRole(id: id, role: role)
    }

    func deleteTranscriptMessage(id: UUID) {
        agentRunTranscriptStore.delete(id: id)
    }

    func openTerminalForAgentRun(_ record: AgentRunRecord) {
        let projectPath = record.launchProjectPath
        guard !projectPath.isEmpty else {
            terminalErrorMessage = "No project path recorded for this run."
            return
        }
        let url = URL(fileURLWithPath: projectPath, isDirectory: true)
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
        pendingWorktreeLaunch = nil
        launchErrorMessage = nil
        terminalErrorMessage = nil
        worktreeMessage = nil

        let preflight = await gitWorktreeService.preflightLaunch(for: issue, in: workspace)
        if preflight.isBlocked || preflight.requiresConfirmation || preflight.canReuseExistingWorktree {
            pendingWorktreeLaunch = PendingWorktreeLaunch(
                issue: issue,
                profile: profile,
                workspace: workspace,
                preflight: preflight
            )
            return
        }

        await performWorktreeAgentLaunch(
            for: issue,
            profile: profile,
            workspace: workspace
        )
    }

    private func performWorktreeAgentLaunch(
        for issue: BeadIssue,
        profile: AgentProfile,
        workspace: ProjectWorkspace,
        preflight: GitWorktreeLaunchPreflight? = nil,
        copyToClipboard: Bool = true
    ) async {
        do {
            let sourceRunID = activeConsoleRunID
            let worktree: GitWorktreeLocation
            if let reusablePath = preflight?.reusableWorktreePath {
                worktree = preflight!.location
                worktreeMessage = "Reusing existing worktree at \(reusablePath)"
            } else {
                let created = try await gitWorktreeService.createWorktree(for: issue, in: workspace)
                worktree = created
                worktreeMessage = "Worktree created at \(created.worktreeURL.path)"
            }
            
            // Automatically trust the worktree folder to bypass agy interactive trust prompt
            trustWorktreeWorkspace(at: worktree.worktreeURL.path)

            let session = await agentLaunchFlowCoordinator.prepareLaunchSession(
                for: issue,
                profile: profile,
                projectPath: worktree.worktreeURL.path,
                worktree: AgentRunWorktreeMetadata(
                    path: worktree.worktreeURL.path,
                    branchName: worktree.branchName,
                    sourceRunID: sourceRunID
                ),
                issueStore: issueStore,
                clearHumanReviewLabel: issue.labels?.contains(KanbanStateMapper.humanReviewLabel) == true
            )

            guard let session else { return }

            activeConsoleRunID = session.id
            detailPaneMode = .console
            if copyToClipboard {
                Clipboard.copy(session.payload.prompt)
            }
            do {
                try agentLaunchFlowCoordinator.openTerminal(
                    for: session,
                    projectURL: worktree.worktreeURL,
                    terminalCommand: session.payload.command
                )
                terminalErrorMessage = nil
                updateAgentRunStatus(id: session.id, status: .accepted)
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
        // Automatically trust the workspace folder to bypass agy interactive trust prompt
        trustWorktreeWorkspace(at: workspace.inspectionURL.path)

        guard let session = await agentLaunchFlowCoordinator.prepareLaunchSession(
            for: issue,
            profile: profile,
            projectPath: workspace.inspectionURL.path,
            issueStore: issueStore,
            clearHumanReviewLabel: issue.labels?.contains(KanbanStateMapper.humanReviewLabel) == true
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
            updateAgentRunStatus(id: session.id, status: .accepted)
        } catch {
            terminalErrorMessage = error.localizedDescription
        }
    }

    // MARK: - AI Commit Message Drafting & Execution

    /// Draft a commit message using the local AI, given the issue's active worktree.
    /// Returns the drafted commit message string.
    /// - Parameters:
    ///   - issue: The issue whose worktree to analyze.
    /// - Throws: Errors from git operations or AI service.
    public func draftCommitMessage(for issue: BeadIssue) async throws -> String {
        guard let workspace = activeWorkspace else {
            throw AICommitError.noActiveWorkspace
        }
        let location = gitWorktreeService.worktreeLocation(for: workspace, issueID: issue.id)
        let diff = try await gitWorktreeService.getDiff(in: location.worktreeURL)
        let diffSummary = try await gitWorktreeService.getChangedFilesSummary(in: location.worktreeURL)
        let lastCommit = try await gitWorktreeService.getLastCommitMessage(in: location.worktreeURL)

        let action = LocalAIAction.draftCommitMessage(
            worktreeURL: location.worktreeURL.path,
            diffSummary: diffSummary,
            diff: diff,
            lastCommit: lastCommit
        )
        return try await requestLocalAIResponse(for: action)
    }

    /// Execute git commit with the given message, push to origin, then remove the worktree.
    /// - Parameters:
    ///   - issue: The issue whose worktree to operate on.
    ///   - message: The commit message to use.
    /// - Throws: Errors from git commit, push, or worktree removal.
    public func commitAndPushWorktree(for issue: BeadIssue, message: String) async throws {
        guard let workspace = activeWorkspace else {
            throw AICommitError.noActiveWorkspace
        }
        let location = gitWorktreeService.worktreeLocation(for: workspace, issueID: issue.id)
        try await gitWorktreeService.commitAndPush(message: message, in: location.worktreeURL)
        try await gitWorktreeService.removeWorktree(location: location, workingDirectory: workspace.inspectionURL)
    }

    /// Get the current diff for an issue's worktree (used to check if there are changes before drafting).
    /// - Parameters:
    ///   - issue: The issue whose worktree to check.
    /// - Returns: A tuple of (diff, changedFilesSummary, hasChanges).
    public func worktreeDiffInfo(for issue: BeadIssue) async throws -> (diff: String, summary: String, hasChanges: Bool) {
        guard let workspace = activeWorkspace else {
            throw AICommitError.noActiveWorkspace
        }
        let location = gitWorktreeService.worktreeLocation(for: workspace, issueID: issue.id)
        let diff = try await gitWorktreeService.getDiff(in: location.worktreeURL)
        let summary = try await gitWorktreeService.getChangedFilesSummary(in: location.worktreeURL)
        let hasChanges = !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (diff, summary, hasChanges)
    }

    // MARK: - Focus Mode

    func focusElapsedMs(for issueID: String) -> Int64 {
        guard let session = focusSessionStore?.session(for: issueID) else { return 0 }
        return session.totalActiveMs
    }

    func focusToggle(for issueID: String) {
        if activeFocusIssueID == issueID {
            // End focus
            focusSessionStore?.endFocus(issueID: issueID)
            clearFocusState()
        } else {
            // End any existing
            if let currentID = activeFocusIssueID {
                focusSessionStore?.endFocus(issueID: currentID)
            }
            // Start new
            activeFocusIssueID = issueID
            isFocusPaused = false
            focusSessionStore?.startFocus(issueID: issueID)
            startFocusTimer()
        }
    }

    func pauseFocus() {
        guard let id = activeFocusIssueID else { return }
        focusSessionStore?.pauseFocus(issueID: id)
        isFocusPaused = true
        stopFocusTimer()
    }

    func resumeFocus() {
        guard let id = activeFocusIssueID else { return }
        focusSessionStore?.resumeFocus(issueID: id)
        isFocusPaused = false
        startFocusTimer()
    }

    func endFocus() {
        if let id = activeFocusIssueID {
            focusSessionStore?.endFocus(issueID: id)
        }
        clearFocusState()
    }

    private func clearFocusState() {
        activeFocusIssueID = nil
        isFocusPaused = false
        focusElapsedMs = 0
        stopFocusTimer()
    }

    private var focusTimer: Timer?

    private func startFocusTimer() {
        stopFocusTimer()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickFocusTimer()
            }
        }
    }

    private func stopFocusTimer() {
        focusTimer?.invalidate()
        focusTimer = nil
    }

    private func tickFocusTimer() {
        guard let id = activeFocusIssueID, !isFocusPaused else { return }
        if let session = focusSessionStore?.session(for: id) {
            focusElapsedMs = session.currentElapsedMs()
        }
    }

    private func trustWorktreeWorkspace(at path: String) {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let settingsURL = home.appendingPathComponent(".gemini/antigravity-cli/settings.json")
        
        let targetPath = URL(fileURLWithPath: path).standardized.path
        
        guard fileManager.fileExists(atPath: settingsURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: settingsURL)
            guard var json = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers]) as? [String: Any] else {
                return
            }
            
            var trusted = json["trustedWorkspaces"] as? [String] ?? []
            let standardizedTrusted = trusted.map { URL(fileURLWithPath: $0).standardized.path }
            
            if !standardizedTrusted.contains(targetPath) {
                trusted.append(targetPath)
                json["trustedWorkspaces"] = trusted
                
                let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
                try updatedData.write(to: settingsURL, options: [.atomic])
            }
        } catch {
            print("Failed to trust workspace: \(error.localizedDescription)")
        }
    }
}

private enum AICommitError: LocalizedError, Sendable {
    case noActiveWorkspace

    var errorDescription: String? {
        switch self {
        case .noActiveWorkspace:
            return "No active workspace is selected."
        }
    }
}

private struct TerminalLauncherAdapter: TerminalLaunching {
    func openTerminal(at projectURL: URL, command: String?, runID: UUID?) throws {
        if let command, !command.isEmpty {
            try TerminalLauncher.openTerminal(at: projectURL, command: command)
        } else {
            try TerminalLauncher.openTerminal(at: projectURL)
        }
    }
}
