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
    case bulkAction
    case copilot
}

@MainActor
@Observable
final class AppViewModel {
    var issueStore: IssueStore?
    var recurringStore: RecurringStore?
    let agentProfileStore: AgentProfileStore
    let recentProjectsStore: RecentProjectsStore
    let preferencesStore: PreferencesStore
    let shellRunner: ShellCommandRunner
    let gitWorktreeService: GitWorktreeService
    let agentRunHistoryStore: AgentRunHistoryStore
    let agentRunTranscriptStore: AgentRunTranscriptStore
    let localAIConnectionTester: any LocalAIConnectionTesting
    let localAIService: LocalAIService
    private let terminalLauncher: any TerminalLaunching
    private let agentLaunchFlowCoordinator: AgentLaunchFlowCoordinator

    var viewMode: BoardViewMode = .list
    var selectedAgentProfileID: UUID = AgentProfile.codingExecutorID

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
    var localAISuggestionPreview: LocalAISuggestionPreviewState?
    var localAIStatusMessage: String?
    var localAIStatusMessageIsError = false

    var pendingAgentLaunch: PendingAgentLaunch?
    var pendingWorktreeLaunch: PendingWorktreeLaunch?
    var launchErrorMessage: String?
    var terminalErrorMessage: String?
    var worktreeMessage: String?
    var activeConsoleRunID: UUID?
    var detailPaneMode: DetailPaneMode = .issue
    var localAIConnectionMessage: String?
    var localAIConnectionMessageIsError = false
    var isTestingLocalAIConnection = false
    private(set) var activeWorkspace: ProjectWorkspace?
    private var activeWorkspaceStorageKey: String?

    @ObservationIgnored private var workspaceCancellable: AnyCancellable?
    @ObservationIgnored private var fileWatcher: IssueFileWatcher?

    init(
        shellRunner: ShellCommandRunner = ShellCommandRunner(),
        recentProjectsStore: RecentProjectsStore = RecentProjectsStore(),
        preferencesStore: PreferencesStore = PreferencesStore(),
        agentRunHistoryStore: AgentRunHistoryStore = AgentRunHistoryStore(),
        agentRunTranscriptStore: AgentRunTranscriptStore = AgentRunTranscriptStore(),
        gitWorktreeService: GitWorktreeService = GitWorktreeService(),
        terminalLauncher: any TerminalLaunching = TerminalLauncherAdapter(),
        localAIConnectionTester: any LocalAIConnectionTesting = OllamaConnectionTester(),
        localAIService: LocalAIService = LocalAIService()
    ) {
        self.shellRunner = shellRunner
        self.gitWorktreeService = gitWorktreeService
        self.agentProfileStore = AgentProfileStore()
        self.recentProjectsStore = recentProjectsStore
        self.preferencesStore = preferencesStore
        self.agentRunHistoryStore = agentRunHistoryStore
        self.agentRunTranscriptStore = agentRunTranscriptStore
        self.localAIConnectionTester = localAIConnectionTester
        self.localAIService = localAIService
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
                recurringStore = nil
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
        let recurring = RecurringStore(workingDirectory: workspace.inspectionURL)
        recurring.load()
        recurringStore = recurring
        store.recurringIDs = recurring.recurringIDs
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
                workspace: pending.workspace
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

    var localAISettings: LocalAISettings {
        preferencesStore.preferences.localAI
    }

    func setLocalAIEnabled(_ isEnabled: Bool) {
        preferencesStore.update { $0.localAI.isEnabled = isEnabled }
        clearLocalAIConnectionStatus()
    }

    func setLocalAIProvider(_ provider: LocalAIProvider) {
        preferencesStore.update {
            $0.localAI.provider = provider
            if provider == .gemini {
                if $0.localAI.baseURL == LocalAISettings.defaultBaseURL {
                    $0.localAI.baseURL = LocalAISettings.defaultGeminiBaseURL
                }
                if $0.localAI.fastModel == LocalAISettings.defaultFastModel {
                    $0.localAI.fastModel = LocalAISettings.defaultGeminiModel
                }
                if $0.localAI.strongModel == LocalAISettings.defaultStrongModel {
                    $0.localAI.strongModel = LocalAISettings.defaultGeminiModel
                }
            } else if provider == .ollama {
                if $0.localAI.baseURL == LocalAISettings.defaultGeminiBaseURL {
                    $0.localAI.baseURL = LocalAISettings.defaultBaseURL
                }
                if $0.localAI.fastModel == LocalAISettings.defaultGeminiModel {
                    $0.localAI.fastModel = LocalAISettings.defaultFastModel
                }
                if $0.localAI.strongModel == LocalAISettings.defaultGeminiModel {
                    $0.localAI.strongModel = LocalAISettings.defaultStrongModel
                }
            }
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
        if preflight.isBlocked || preflight.requiresConfirmation {
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
        workspace: ProjectWorkspace
    ) async {
        do {
            let sourceRunID = activeConsoleRunID
            let worktree = try await gitWorktreeService.createWorktree(for: issue, in: workspace)
            let session = await agentLaunchFlowCoordinator.prepareLaunchSession(
                for: issue,
                profile: profile,
                projectPath: worktree.worktreeURL.path,
                worktree: AgentRunWorktreeMetadata(
                    path: worktree.worktreeURL.path,
                    branchName: worktree.branchName,
                    sourceRunID: sourceRunID
                ),
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
