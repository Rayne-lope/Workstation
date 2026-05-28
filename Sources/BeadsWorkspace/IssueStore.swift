#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation
import Observation

@MainActor
@Observable
public final class IssueStore {
    public private(set) var issues: [BeadIssue] = []
    public var filterState: FilterState
    public var recurringIDs: Set<String> = []
    public private(set) var readyIssueIDs: Set<String> = []
    public private(set) var blockedByDependencyIDs: Set<String> = []
    public private(set) var blockersMap: [String: [String]] = [:]
    public private(set) var dependencyGraph: IssueDependencyGraph?
    public private(set) var selectedIssue: BeadIssue?
    public private(set) var selectedIssueDetail: BeadIssue?
    public private(set) var selectedIssueIDs: Set<String> = []
    public private(set) var rangeAnchorID: String?
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?
    public private(set) var lastReloadedAt: Date?
    public private(set) var lastDecodeFailureRawJSON: String?

    public let service: BeadsService
    public let workingDirectory: URL
    private let nowProvider: @MainActor () -> Date
    private var reloadTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?

    public var doneVisibilityWindow: TimeInterval

    private static let closedAtParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public init(
        service: BeadsService,
        workingDirectory: URL,
        doneVisibilityWindow: TimeInterval = AppPreferences.defaultDoneVisibilityWindowSeconds,
        filterState: FilterState = .init(),
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.service = service
        self.workingDirectory = workingDirectory
        self.doneVisibilityWindow = doneVisibilityWindow
        self.filterState = filterState
        self.nowProvider = now
    }

    // MARK: - Selection

    public func selectIssue(id: String) {
        selectedIssue = issues.first { $0.id == id }
        selectedIssueDetail = nil
        detailTask?.cancel()
        guard let selectedID = selectedIssue?.id else {
            selectedIssueIDs = []
            rangeAnchorID = nil
            return
        }
        selectedIssueIDs = [selectedID]
        rangeAnchorID = selectedID
        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.refreshSelectedDetail(expectedID: selectedID)
        }
        detailTask = task
    }

    public func clearSelection() {
        selectedIssue = nil
        selectedIssueDetail = nil
        selectedIssueIDs = []
        rangeAnchorID = nil
        detailTask?.cancel()
        detailTask = nil
    }

    public func toggleSelection(id: String) {
        if selectedIssueIDs.contains(id) {
            selectedIssueIDs.remove(id)
            if selectedIssue?.id == id {
                if let nextID = selectedIssueIDs.first,
                   let next = issues.first(where: { $0.id == nextID }) {
                    selectedIssue = next
                    selectedIssueDetail = nil
                    detailTask?.cancel()
                    let task: Task<Void, Never> = Task { [weak self] in
                        guard let self else { return }
                        await self.refreshSelectedDetail(expectedID: nextID)
                    }
                    detailTask = task
                } else {
                    selectedIssue = nil
                    selectedIssueDetail = nil
                    detailTask?.cancel()
                    detailTask = nil
                }
            }
            if rangeAnchorID == id {
                rangeAnchorID = selectedIssueIDs.first
            }
        } else {
            selectedIssueIDs.insert(id)
            rangeAnchorID = id
            if let issue = issues.first(where: { $0.id == id }) {
                selectedIssue = issue
                selectedIssueDetail = nil
                detailTask?.cancel()
                let task: Task<Void, Never> = Task { [weak self] in
                    guard let self else { return }
                    await self.refreshSelectedDetail(expectedID: id)
                }
                detailTask = task
            }
        }
    }

    /// Extend selection to include all items between `rangeAnchorID` and `id`
    /// within the given ordered list (typically a single column's visible cards).
    /// If no anchor or anchor not in list, behaves like `toggleSelection`.
    public func selectRange(to id: String, within orderedIDs: [String]) {
        guard let anchor = rangeAnchorID ?? selectedIssue?.id,
              let anchorIdx = orderedIDs.firstIndex(of: anchor),
              let targetIdx = orderedIDs.firstIndex(of: id)
        else {
            toggleSelection(id: id)
            return
        }
        let range = anchorIdx <= targetIdx
            ? orderedIDs[anchorIdx...targetIdx]
            : orderedIDs[targetIdx...anchorIdx]
        for rangeID in range {
            selectedIssueIDs.insert(rangeID)
        }
        if let issue = issues.first(where: { $0.id == id }) {
            selectedIssue = issue
            selectedIssueDetail = nil
            detailTask?.cancel()
            let task: Task<Void, Never> = Task { [weak self] in
                guard let self else { return }
                await self.refreshSelectedDetail(expectedID: id)
            }
            detailTask = task
        }
    }

    public var hasMultiSelection: Bool {
        selectedIssueIDs.count >= 2
    }

    public func selectedIssues() -> [BeadIssue] {
        let ids = selectedIssueIDs
        return issues.filter { ids.contains($0.id) }
    }

    private func refreshSelectedDetail(expectedID: String) async {
        do {
            let detail = try await service.showIssue(id: expectedID, in: workingDirectory)
            if Task.isCancelled { return }
            if selectedIssue?.id == expectedID {
                selectedIssueDetail = detail
            }
        } catch {
            // Fail-soft: keep selectedIssueDetail nil; detail section just hides.
        }
    }

    // MARK: - Reload

    public func reload() async {
        reloadTask?.cancel()
        let task = Task { await performReload() }
        reloadTask = task
        await task.value
        if reloadTask == task {
            reloadTask = nil
        }
    }

    private func performReload() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let listResult = service.listIssues(in: workingDirectory)
            async let readyResult = service.readyIssues(in: workingDirectory)
            async let recentClosedResult = fetchRecentlyClosed()
            async let blockedResult = fetchBlocked()
            let fetched = try await listResult
            let ready = try await readyResult
            let recentClosed = await recentClosedResult
            let blocked = await blockedResult

            if Task.isCancelled { return }

            let merged = merge(open: fetched, recentClosed: recentClosed)
            blockersMap = Dictionary(uniqueKeysWithValues: blocked.map { ($0.id, $0.blockedBy ?? []) })
            issues = merged.map { issue in
                let blockers = blockersMap[issue.id] ?? []
                return BeadIssue(
                    id: issue.id,
                    title: issue.title,
                    status: issue.status,
                    priority: issue.priority,
                    issueType: issue.issueType,
                    description: issue.description,
                    acceptanceCriteria: issue.acceptanceCriteria,
                    notes: issue.notes,
                    createdAt: issue.createdAt,
                    updatedAt: issue.updatedAt,
                    closedAt: issue.closedAt,
                    labels: issue.labels,
                    assignee: issue.assignee,
                    blockedBy: blockers.isEmpty ? nil : blockers,
                    dependencies: issue.dependencies,
                    dependents: issue.dependents,
                    parentID: issue.parentID,
                    dependencyType: issue.dependencyType
                )
            }
            readyIssueIDs = Set(ready.map(\.id))
            blockedByDependencyIDs = Set(blocked.map(\.id))
            dependencyGraph = resolveDependencyGraph()
            errorMessage = nil
            lastReloadedAt = nowProvider()
            if let selected = selectedIssue {
                selectedIssue = issues.first { $0.id == selected.id }
            }
            let presentIDs = Set(issues.map(\.id))
            selectedIssueIDs.formIntersection(presentIDs)
            if let anchor = rangeAnchorID, !presentIDs.contains(anchor) {
                rangeAnchorID = selectedIssueIDs.first
            }
        } catch is CancellationError {
            return
        } catch let error as BeadsError {
            recordDecodeFailure(from: error)
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
        } catch {
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
        }
    }

    private func fetchBlocked() async -> [BeadIssue] {
        do {
            return try await service.blockedIssues(in: workingDirectory)
        } catch {
            return []
        }
    }

    private func fetchRecentlyClosed() async -> [BeadIssue] {
        guard doneVisibilityWindow > 0 else { return [] }
        do {
            let all = try await service.closedIssues(in: workingDirectory)
            let cutoff = nowProvider().addingTimeInterval(-doneVisibilityWindow)
            return all.filter { issue in
                guard
                    let raw = issue.closedAt,
                    let date = Self.closedAtParser.date(from: raw)
                else { return false }
                return date >= cutoff
            }
        } catch {
            return []
        }
    }

    private func merge(open: [BeadIssue], recentClosed: [BeadIssue]) -> [BeadIssue] {
        let openIDs = Set(open.map(\.id))
        return open + recentClosed.filter { !openIDs.contains($0.id) }
    }

    // MARK: - Mutations

    public func createIssue(_ input: CreateIssueInput) async {
        await runMutation { [self] in
            _ = try await service.createIssue(input, in: workingDirectory)
        }
    }

    @discardableResult
    public func claim(id: String, assignee: String? = nil) async -> Bool {
        await runMutation { [self] in
            _ = try await service.claimIssue(id: id, assignee: assignee, in: workingDirectory)
        }
        return errorMessage == nil
    }

    public func update(id: String, _ input: UpdateIssueInput) async {
        await runMutation { [self] in
            _ = try await service.updateIssue(id: id, input: input, in: workingDirectory)
        }
    }

    public func close(id: String, reason: String) async {
        await runMutation { [self] in
            _ = try await service.closeIssue(id: id, reason: reason, in: workingDirectory)
        }
    }

    public func reopen(id: String) async {
        await runMutation { [self] in
            _ = try await service.reopenIssue(id: id, in: workingDirectory)
        }
    }

    public func addDependency(blockerID: String, to issueID: String) async {
        await runMutation { [self] in
            try await service.addDependency(
                id: issueID,
                dependsOn: blockerID,
                in: workingDirectory
            )
        }
        if errorMessage == nil, selectedIssue?.id == issueID {
            await refreshSelectedDetail(expectedID: issueID)
        }
    }

    public func removeDependency(blockerID: String, from issueID: String) async {
        await runMutation { [self] in
            try await service.removeDependency(
                id: issueID,
                dependsOn: blockerID,
                in: workingDirectory
            )
        }
        if errorMessage == nil, selectedIssue?.id == issueID {
            await refreshSelectedDetail(expectedID: issueID)
        }
    }

    public func requestHumanReview(id: String) async {
        await runMutation { [self] in
            _ = try await service.addLabel(
                id: id,
                label: KanbanStateMapper.humanReviewLabel,
                in: workingDirectory
            )
        }
    }

    /// Adds the `human` review label and sets notes in a single bd update call.
    /// Used by the Automated Landing Sheet.
    public func flagForReview(id: String, notes: String) async {
        await runMutation { [self] in
            _ = try await service.flagForReview(
                id: id,
                notes: notes,
                in: workingDirectory
            )
        }
    }

    @discardableResult
    public func clearHumanReview(id: String) async -> Bool {
        await runMutation { [self] in
            _ = try await service.removeLabel(
                id: id,
                label: KanbanStateMapper.humanReviewLabel,
                in: workingDirectory
            )
        }
        return errorMessage == nil
    }

    public func claimSelected() async {
        guard let selected = selectedIssue else { return }
        await claim(id: selected.id)
    }

    public func closeSelected(reason: String) async {
        guard let selected = selectedIssue else { return }
        await close(id: selected.id, reason: reason)
    }

    private func runMutation(_ body: () async throws -> Void) async {
        do {
            try await body()
            errorMessage = nil
            await reload()
        } catch let error as BeadsError {
            recordDecodeFailure(from: error)
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordDecodeFailure(from error: BeadsError) {
        if case let .jsonDecodeFailed(raw) = error {
            lastDecodeFailureRawJSON = raw
        }
    }

    // MARK: - Kanban-mapped computed columns

    public func issues(in column: KanbanColumn) -> [BeadIssue] {
        sorted(filteredIssues.filter {
            KanbanStateMapper.column(
                for: $0,
                readyIDs: readyIssueIDs,
                blockedIDs: blockedByDependencyIDs
            ) == column
        })
    }

    public var backlogIssues: [BeadIssue] { issues(in: .backlog) }
    public var readyIssues: [BeadIssue] { issues(in: .ready) }
    public var inProgressIssues: [BeadIssue] { issues(in: .inProgress) }
    public var reviewIssues: [BeadIssue] { issues(in: .review) }
    public var blockedIssues: [BeadIssue] { issues(in: .blocked) }
    public var doneIssues: [BeadIssue] { issues(in: .done) }

    // ── Epic helpers ──────────────────────────────────────────────────────────

    /// All issues whose `parentID == epicID`.
    public func children(of epicID: String) -> [BeadIssue] {
        issues.filter { $0.parentID == epicID }
    }

    /// `(done, total)` count of children for an epic issue.
    public func epicProgress(id: String) -> (done: Int, total: Int) {
        let kids = children(of: id)
        return (kids.filter { $0.status == "closed" }.count, kids.count)
    }

    public var filteredIssues: [BeadIssue] {
        sorted(issues.filter { matchesFilters($0) })
    }

    public var hasActiveFilters: Bool {
        !filterState.isEmpty
    }

    public var activeFilterCount: Int {
        filterState.priorities.count
            + filterState.issueTypes.count
            + filterState.assignees.count
            + filterState.labels.count
            + (filterState.recurringOnly ? 1 : 0)
    }

    public var availablePriorities: [Int] {
        Array(0...4)
    }

    public var availableIssueTypes: [String] {
        ["task", "bug", "feature", "epic", "chore"]
    }

    public var availableAssigneeKinds: [IssueFilterAssignee] {
        IssueFilterAssignee.allCases
    }

    public var availableLabels: [String] {
        let labels = Set(
            issues
                .flatMap { $0.labels ?? [] }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        return labels.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    public func togglePriority(_ priority: Int) {
        filterState.togglePriority(priority)
    }

    public func toggleIssueType(_ issueType: String) {
        filterState.toggleIssueType(issueType)
    }

    public func toggleAssignee(_ assignee: IssueFilterAssignee) {
        filterState.toggleAssignee(assignee)
    }

    public func toggleLabel(_ label: String) {
        filterState.toggleLabel(label)
    }

    public func toggleStatus(_ status: String) {
        filterState.toggleStatus(status)
    }

    public func toggleRecurringOnly() {
        filterState.toggleRecurringOnly()
    }

    public func clearFilters() {
        filterState.clear()
    }

    public var unknownStatusIssueIDs: Set<String> {
        Set(issues.filter { !KanbanStateMapper.isKnownStatus($0.status) }.map(\.id))
    }

    public func hasUnknownStatus(_ issue: BeadIssue) -> Bool {
        !KanbanStateMapper.isKnownStatus(issue.status)
    }

    private func sorted(_ source: [BeadIssue]) -> [BeadIssue] {
        source.sorted { lhs, rhs in
            let lp = lhs.priority ?? Int.max
            let rp = rhs.priority ?? Int.max
            if lp != rp { return lp < rp }
            let lu = lhs.updatedAt ?? ""
            let ru = rhs.updatedAt ?? ""
            if lu != ru { return lu > ru }
            return lhs.id < rhs.id
        }
    }

    private func matchesFilters(_ issue: BeadIssue) -> Bool {
        if !filterState.priorities.isEmpty {
            guard let priority = issue.priority, filterState.priorities.contains(priority) else {
                return false
            }
        }

        if !filterState.issueTypes.isEmpty {
            guard let issueType = normalized(issue.issueType),
                  filterState.issueTypes.contains(issueType)
            else {
                return false
            }
        }

        if !filterState.assignees.isEmpty {
            guard matchesAssignee(issue.assignee) else {
                return false
            }
        }

        if !filterState.labels.isEmpty {
            let issueLabels = Set((issue.labels ?? []).compactMap { normalized($0) })
            guard !issueLabels.isDisjoint(with: filterState.labels) else {
                return false
            }
        }

        if !filterState.statuses.isEmpty {
            guard let status = issue.status, filterState.statuses.contains(status) else {
                return false
            }
        }

        if filterState.recurringOnly, !recurringIDs.contains(issue.id) {
            return false
        }

        return true
    }

    private func matchesAssignee(_ assignee: String?) -> Bool {
        guard let normalizedAssignee = normalized(assignee) else { return false }

        for assigneeFilter in filterState.assignees {
            switch assigneeFilter {
            case .claude:
                if normalizedAssignee == "claude" || normalizedAssignee.contains("claude") {
                    return true
                }
            case .codex:
                if normalizedAssignee == "codex" || normalizedAssignee.contains("codex") {
                    return true
                }
            case .other:
                if normalizedAssignee != "claude",
                   normalizedAssignee != "codex",
                   normalizedAssignee != "me" {
                    return true
                }
            case .me:
                if normalizedAssignee == "me" {
                    return true
                }
            }
        }

        return false
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolveDependencyGraph() -> IssueDependencyGraph {
        var adj: [String: [String]] = [:]
        var incoming: [String: [String]] = [:]
        
        for issue in issues {
            adj[issue.id] = []
            incoming[issue.id] = []
        }
        
        for issue in issues {
            let blockers = issue.blockedBy ?? []
            incoming[issue.id] = blockers
            for blocker in blockers {
                adj[blocker, default: []].append(issue.id)
            }
        }
        
        for (k, v) in adj {
            adj[k] = v.sorted()
        }
        for (k, v) in incoming {
            incoming[k] = v.sorted()
        }
        
        let cycles = IssueDependencyGraph.detectCycles(issues: issues)
        let critical = IssueDependencyGraph.findCriticalPath(issues: issues)
        
        return IssueDependencyGraph(
            adjacencyList: adj,
            blockersMap: incoming,
            detectedCycles: cycles,
            criticalPath: critical
        )
    }
}
