import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("IssueStore")
struct IssueStoreTests {
    private let workingDirectory = URL(fileURLWithPath: "/tmp/issue-store-tests", isDirectory: true)

    private static let listFixture = """
    [
      {"id":"bd-1","title":"Backlog one","status":"open","priority":2,"updated_at":"2026-05-18T10:00:00Z"},
      {"id":"bd-2","title":"Ready one","status":"open","priority":1,"updated_at":"2026-05-18T10:05:00Z"},
      {"id":"bd-3","title":"In progress","status":"in_progress","priority":0,"updated_at":"2026-05-18T10:10:00Z"},
      {"id":"bd-4","title":"Blocked","status":"blocked","priority":2,"updated_at":"2026-05-18T10:15:00Z"},
      {"id":"bd-5","title":"Closed","status":"closed","priority":3,"updated_at":"2026-05-18T10:20:00Z"}
    ]
    """

    private static let readyFixture = """
    [
      {"id":"bd-2","title":"Ready one"}
    ]
    """

    private func makeStore(
        stubbing runner: StubCommandRunner,
        doneVisibilityWindow: TimeInterval = AppPreferences.defaultDoneVisibilityWindowSeconds,
        now: @escaping @MainActor () -> Date = { Date() }
    ) -> IssueStore {
        IssueStore(
            service: BeadsService(commandRunner: runner),
            workingDirectory: workingDirectory,
            doneVisibilityWindow: doneVisibilityWindow,
            now: now
        )
    }

    private func enqueueReload(_ runner: StubCommandRunner, list: String = listFixture, ready: String = readyFixture) {
        runner.enqueue(arguments: ["list", "--json"], stdout: list)
        runner.enqueue(arguments: ["ready", "--json"], stdout: ready)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func iso(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    // MARK: - Reload

    @Test("reload populates issues, readyIssueIDs, and lastReloadedAt")
    func reloadPopulatesState() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.issues.count == 5)
        #expect(store.readyIssueIDs == ["bd-2"])
        #expect(store.errorMessage == nil)
        #expect(store.lastReloadedAt != nil)
        #expect(store.isLoading == false)
    }

    @Test("Two back-to-back reloads both settle and leave consistent state")
    func backToBackReloadsBothSettle() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)

        async let first: Void = store.reload()
        async let second: Void = store.reload()
        _ = await (first, second)

        #expect(store.issues.count == 5)
        #expect(store.errorMessage == nil)
        #expect(store.isLoading == false)
        #expect(store.lastReloadedAt != nil)
    }

    @Test("reload failure surfaces errorMessage and keeps existing issues")
    func reloadFailureSurfacesError() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()
        let snapshot = store.issues

        runner.enqueue(arguments: ["list", "--json"], stderr: "boom", exitCode: 1)
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        await store.reload()

        #expect(store.errorMessage != nil)
        #expect(store.issues == snapshot)
    }

    @Test("reload decode failure preserves the raw JSON payload")
    func reloadDecodeFailurePreservesRawJSON() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], stdout: "not json")
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.errorMessage != nil)
        #expect(store.lastDecodeFailureRawJSON == "not json")
    }

    // MARK: - Selection

    @Test("selectIssue and clearSelection work against current issues")
    func selectAndClearSelection() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        store.selectIssue(id: "bd-3")
        #expect(store.selectedIssue?.id == "bd-3")

        store.selectIssue(id: "does-not-exist")
        #expect(store.selectedIssue == nil)

        store.selectIssue(id: "bd-1")
        store.clearSelection()
        #expect(store.selectedIssue == nil)
    }

    // MARK: - Columns

    @Test("Column computed properties map issues to exactly one column")
    func columnsMapEachIssueExactlyOnce() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        #expect(store.backlogIssues.map(\.id) == ["bd-1"])
        #expect(store.readyIssues.map(\.id) == ["bd-2"])
        #expect(store.inProgressIssues.map(\.id) == ["bd-3"])
        #expect(store.blockedIssues.map(\.id) == ["bd-4"])
        #expect(store.doneIssues.map(\.id) == ["bd-5"])

        let total = store.backlogIssues.count
            + store.readyIssues.count
            + store.inProgressIssues.count
            + store.blockedIssues.count
            + store.doneIssues.count
        #expect(total == store.issues.count)
    }

    @Test("Unknown status lands in backlog and is flagged via unknownStatusIssueIDs")
    func unknownStatusLandsInBacklog() async throws {
        let list = """
        [
          {"id":"bd-77","title":"Phantom","status":"phantom-state","priority":2}
        ]
        """
        let runner = StubCommandRunner()
        enqueueReload(runner, list: list, ready: "[]")
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.backlogIssues.map(\.id) == ["bd-77"])
        #expect(store.unknownStatusIssueIDs == ["bd-77"])
        #expect(store.hasUnknownStatus(store.backlogIssues[0]))
    }

    @Test("Recently-closed issues fetched from bd list --status=closed appear in Done")
    func recentlyClosedFetchPopulatesDone() async throws {
        let runner = StubCommandRunner()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let closedStdout = """
        [
          {"id":"bd-99","title":"Just closed","status":"closed","closed_at":"\(IssueStoreTests.iso(now.addingTimeInterval(-3600)))"}
        ]
        """
        runner.enqueue(arguments: ["list", "--json"], stdout: "[]")
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")
        runner.enqueue(arguments: ["list", "--status=closed", "--json"], stdout: closedStdout)
        let store = makeStore(stubbing: runner, now: { now })

        await store.reload()

        #expect(store.doneIssues.map(\.id) == ["bd-99"])
        #expect(store.errorMessage == nil)
    }

    @Test("Closed issues older than the visibility window are filtered out")
    func recentlyClosedBeyondWindowFiltered() async throws {
        let runner = StubCommandRunner()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let closedStdout = """
        [
          {"id":"fresh","title":"Fresh","status":"closed","closed_at":"\(IssueStoreTests.iso(now.addingTimeInterval(-3600)))"},
          {"id":"stale","title":"Stale","status":"closed","closed_at":"\(IssueStoreTests.iso(now.addingTimeInterval(-(48 * 3600))))"}
        ]
        """
        runner.enqueue(arguments: ["list", "--json"], stdout: "[]")
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")
        runner.enqueue(arguments: ["list", "--status=closed", "--json"], stdout: closedStdout)
        let store = makeStore(stubbing: runner, now: { now })

        await store.reload()

        #expect(store.doneIssues.map(\.id) == ["fresh"])
    }

    @Test("doneVisibilityWindow of zero skips the closed fetch entirely")
    func zeroWindowSkipsClosedFetch() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], stdout: "[]")
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")
        let store = makeStore(stubbing: runner, doneVisibilityWindow: 0)

        await store.reload()

        #expect(store.doneIssues.isEmpty)
        #expect(runner.calls.contains { $0.arguments == ["list", "--status=closed", "--json"] } == false)
    }

    @Test("Closed fetch failure does not break reload — Done column just stays empty")
    func closedFetchFailureIsSilent() async throws {
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["list", "--json"], stdout: "[]")
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")
        runner.enqueue(arguments: ["list", "--status=closed", "--json"], stderr: "unknown flag", exitCode: 1)
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.errorMessage == nil)
        #expect(store.doneIssues.isEmpty)
    }

    @Test("Closed issue stays in Done even when present in ready set")
    func closedIssueStaysInDone() async throws {
        let list = """
        [
          {"id":"bd-9","title":"Stale ready","status":"closed","priority":2}
        ]
        """
        let ready = #"[{"id":"bd-9","title":"Stale ready"}]"#
        let runner = StubCommandRunner()
        enqueueReload(runner, list: list, ready: ready)
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.doneIssues.map(\.id) == ["bd-9"])
        #expect(store.readyIssues.isEmpty)
    }

    @Test("Sort prioritises lower priority value, then newer updatedAt")
    func sortingByPriorityThenUpdatedAt() async throws {
        let list = """
        [
          {"id":"a","title":"A","status":"open","priority":2,"updated_at":"2026-01-01T00:00:00Z"},
          {"id":"b","title":"B","status":"open","priority":1,"updated_at":"2026-01-01T00:00:00Z"},
          {"id":"c","title":"C","status":"open","priority":2,"updated_at":"2026-02-01T00:00:00Z"}
        ]
        """
        let runner = StubCommandRunner()
        enqueueReload(runner, list: list, ready: "[]")
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.backlogIssues.map(\.id) == ["b", "c", "a"])
    }

    @Test("filteredIssues combines dimensions with OR within a dimension and AND across dimensions")
    func filteredIssuesCombinesDimensions() async throws {
        let list = """
        [
          {"id":"bd-1","title":"A","status":"open","priority":0,"issue_type":"bug","assignee":"claude","labels":["human"]},
          {"id":"bd-2","title":"B","status":"open","priority":1,"issue_type":"task","assignee":"codex","labels":["docs"]},
          {"id":"bd-3","title":"C","status":"open","priority":2,"issue_type":"feature","assignee":"me","labels":["human","urgent"]},
          {"id":"bd-4","title":"D","status":"open","priority":3,"issue_type":"chore","assignee":"other"}
        ]
        """
        let runner = StubCommandRunner()
        enqueueReload(runner, list: list, ready: "[]")
        let store = makeStore(stubbing: runner)

        await store.reload()

        store.filterState = FilterState(priorities: [0, 1])
        #expect(store.filteredIssues.map(\.id) == ["bd-1", "bd-2"])

        store.filterState = FilterState(priorities: [0], issueTypes: ["bug"])
        #expect(store.filteredIssues.map(\.id) == ["bd-1"])

        store.filterState = FilterState(priorities: [0], issueTypes: ["bug"], assignees: [.claude])
        #expect(store.filteredIssues.map(\.id) == ["bd-1"])

        store.filterState = FilterState(labels: ["human"])
        #expect(store.filteredIssues.map(\.id) == ["bd-1", "bd-3"])
    }

    // MARK: - Dependency-based blocking

    @Test("reload populates blockedByDependencyIDs and blockersMap from bd blocked --json")
    func reloadPopulatesBlockedFromDependencies() async throws {
        let list = """
        [
          {"id":"bd-1","title":"Outer","status":"open","priority":2,"updated_at":"2026-05-18T10:00:00Z"},
          {"id":"bd-2","title":"Blocker","status":"open","priority":2,"updated_at":"2026-05-18T10:05:00Z"}
        ]
        """
        let blocked = """
        [
          {"id":"bd-1","title":"Outer","status":"open","blocked_by":["bd-2"]}
        ]
        """
        let runner = StubCommandRunner()
        enqueueReload(runner, list: list, ready: "[]")
        runner.enqueue(arguments: ["blocked", "--json"], stdout: blocked)
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.blockedByDependencyIDs == ["bd-1"])
        #expect(store.blockersMap["bd-1"] == ["bd-2"])
        #expect(store.issues.first(where: { $0.id == "bd-1" })?.blockedBy == ["bd-2"])
        #expect(store.dependencyGraph?.blockersMap["bd-1"] == ["bd-2"])
        #expect(store.dependencyGraph?.adjacencyList["bd-2"] == ["bd-1"])
    }

    @Test("Open issue listed in blocked routes to Blocked column, not Backlog/Ready")
    func dependencyBlockedRoutesToBlockedColumn() async throws {
        let list = """
        [
          {"id":"bd-1","title":"Depends on something","status":"open","priority":2,"updated_at":"2026-05-18T10:00:00Z"}
        ]
        """
        let blocked = """
        [
          {"id":"bd-1","title":"Depends on something","status":"open","blocked_by":["bd-99"]}
        ]
        """
        let runner = StubCommandRunner()
        // bd-1 also appears in ready set — blocked must still win.
        enqueueReload(runner, list: list, ready: #"[{"id":"bd-1","title":"Depends on something"}]"#)
        runner.enqueue(arguments: ["blocked", "--json"], stdout: blocked)
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.blockedIssues.map(\.id) == ["bd-1"])
        #expect(store.readyIssues.isEmpty)
        #expect(store.backlogIssues.isEmpty)
    }

    @Test("bd blocked failure is fail-soft — reload still succeeds with empty set")
    func blockedFetchFailureIsFailSoft() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        // No stub for ["blocked", "--json"] → StubCommandRunner throws → fetchBlocked() returns [].
        let store = makeStore(stubbing: runner)

        await store.reload()

        #expect(store.errorMessage == nil)
        #expect(store.blockedByDependencyIDs.isEmpty)
        #expect(store.blockersMap.isEmpty)
        #expect(store.issues.count == 5)
    }

    @Test("selectIssue triggers bd show and populates selectedIssueDetail")
    func selectIssuePopulatesSelectedDetail() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        let detailJSON = """
        [
          {
            "id":"bd-3",
            "title":"In progress",
            "status":"in_progress",
            "dependencies":[{"id":"bd-1","title":"Backlog one","status":"open"}],
            "dependents":[{"id":"bd-4","title":"Down","status":"open"}]
          }
        ]
        """
        runner.enqueue(arguments: ["show", "bd-3", "--json"], stdout: detailJSON)

        store.selectIssue(id: "bd-3")
        // Yield until the detail Task finishes.
        for _ in 0..<50 {
            if store.selectedIssueDetail != nil { break }
            await Task.yield()
        }

        #expect(store.selectedIssue?.id == "bd-3")
        #expect(store.selectedIssueDetail?.id == "bd-3")
        #expect(store.selectedIssueDetail?.dependencies?.first?.id == "bd-1")
        #expect(store.selectedIssueDetail?.dependents?.first?.id == "bd-4")
    }

    @Test("clearSelection resets selectedIssueDetail")
    func clearSelectionResetsDetail() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        let detailJSON = #"[{"id":"bd-3","title":"In progress","status":"in_progress"}]"#
        runner.enqueue(arguments: ["show", "bd-3", "--json"], stdout: detailJSON)

        store.selectIssue(id: "bd-3")
        for _ in 0..<50 {
            if store.selectedIssueDetail != nil { break }
            await Task.yield()
        }
        #expect(store.selectedIssueDetail != nil)

        store.clearSelection()
        #expect(store.selectedIssue == nil)
        #expect(store.selectedIssueDetail == nil)
    }

    // MARK: - Mutations trigger reload

    @Test("createIssue triggers reload on success")
    func createIssueTriggersReload() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        let createdJSON = #"{"id":"bd-99","title":"Fresh","status":"open"}"#
        runner.enqueue(arguments: ["create", "Fresh", "--json"], stdout: createdJSON)

        let listAfter = """
        [
          {"id":"bd-99","title":"Fresh","status":"open","priority":2}
        ]
        """
        runner.enqueue(arguments: ["list", "--json"], stdout: listAfter)
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        await store.createIssue(CreateIssueInput(title: "Fresh"))

        #expect(store.errorMessage == nil)
        #expect(store.issues.map(\.id) == ["bd-99"])
    }

    @Test("claim triggers reload and updates status")
    func claimTriggersReload() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        runner.enqueue(
            arguments: ["update", "bd-1", "--claim", "--json"],
            stdout: #"[{"id":"bd-1","status":"in_progress","title":"Backlog one"}]"#
        )
        let listAfter = """
        [
          {"id":"bd-1","title":"Backlog one","status":"in_progress","priority":2}
        ]
        """
        runner.enqueue(arguments: ["list", "--json"], stdout: listAfter)
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        await store.claim(id: "bd-1")

        #expect(store.errorMessage == nil)
        #expect(store.inProgressIssues.map(\.id) == ["bd-1"])
    }

    @Test("claim with assignee triggers reload and preserves the assignee")
    func claimWithAssigneeTriggersReload() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        runner.enqueue(
            arguments: ["update", "bd-1", "--claim", "--assignee", "claude", "--json"],
            stdout: #"[{"id":"bd-1","status":"in_progress","title":"Backlog one","assignee":"claude"}]"#
        )
        let listAfter = """
        [
          {"id":"bd-1","title":"Backlog one","status":"in_progress","priority":2,"assignee":"claude"}
        ]
        """
        runner.enqueue(arguments: ["list", "--json"], stdout: listAfter)
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        let claimed = await store.claim(id: "bd-1", assignee: "claude")

        #expect(claimed == true)
        #expect(store.errorMessage == nil)
        #expect(store.inProgressIssues.map(\.id) == ["bd-1"])
        #expect(store.issues.first(where: { $0.id == "bd-1" })?.assignee == "claude")
    }

    @Test("close failure surfaces error and keeps selection")
    func closeFailurePreservesSelection() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()
        store.selectIssue(id: "bd-2")

        runner.enqueue(
            arguments: ["close", "bd-2", "--reason", "nope", "--json"],
            stderr: "permission denied",
            exitCode: 1
        )

        await store.close(id: "bd-2", reason: "nope")

        #expect(store.errorMessage != nil)
        #expect(store.selectedIssue?.id == "bd-2")
    }

    @Test("requestHumanReview adds the 'human' label and moves issue to Review column")
    func requestHumanReviewMovesToReview() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()
        #expect(store.inProgressIssues.map(\.id) == ["bd-3"])
        #expect(store.reviewIssues.isEmpty)

        runner.enqueue(
            arguments: ["update", "bd-3", "--add-label", "human", "--json"],
            stdout: #"[{"id":"bd-3","title":"In progress","status":"in_progress","labels":["human"]}]"#
        )
        let listAfter = """
        [
          {"id":"bd-3","title":"In progress","status":"in_progress","priority":0,"labels":["human"]}
        ]
        """
        runner.enqueue(arguments: ["list", "--json"], stdout: listAfter)
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        await store.requestHumanReview(id: "bd-3")

        #expect(store.errorMessage == nil)
        #expect(store.reviewIssues.map(\.id) == ["bd-3"])
        #expect(store.inProgressIssues.isEmpty)
    }

    @Test("addDependency triggers reload and refreshes selectedIssueDetail")
    func addDependencyTriggersReloadAndRefreshDetail() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        // Select bd-3 — initial detail fetch.
        let initialDetailJSON = #"[{"id":"bd-3","title":"In progress","status":"in_progress"}]"#
        runner.enqueue(arguments: ["show", "bd-3", "--json"], stdout: initialDetailJSON)
        store.selectIssue(id: "bd-3")
        for _ in 0..<50 {
            if store.selectedIssueDetail != nil { break }
            await Task.yield()
        }
        #expect(store.selectedIssueDetail?.dependencies == nil)

        // Stub the mutation, the post-mutation reload, AND the post-mutation detail refetch.
        runner.enqueue(arguments: ["dep", "add", "bd-3", "bd-1"], stdout: "")
        runner.enqueue(arguments: ["list", "--json"], stdout: IssueStoreTests.listFixture)
        runner.enqueue(arguments: ["ready", "--json"], stdout: IssueStoreTests.readyFixture)
        let refreshedDetailJSON = """
        [
          {
            "id":"bd-3",
            "title":"In progress",
            "status":"in_progress",
            "dependencies":[{"id":"bd-1","title":"Backlog one","status":"open"}]
          }
        ]
        """
        runner.enqueue(arguments: ["show", "bd-3", "--json"], stdout: refreshedDetailJSON)

        await store.addDependency(blockerID: "bd-1", to: "bd-3")

        #expect(store.errorMessage == nil)
        #expect(store.selectedIssueDetail?.dependencies?.first?.id == "bd-1")
    }

    @Test("addDependency failure surfaces errorMessage and skips detail refresh")
    func addDependencyFailureSurfacesError() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        runner.enqueue(
            arguments: ["dep", "add", "bd-3", "bd-1"],
            stderr: "cycle detected",
            exitCode: 1
        )

        await store.addDependency(blockerID: "bd-1", to: "bd-3")

        #expect(store.errorMessage != nil)
    }

    @Test("removeDependency triggers reload and refreshes detail")
    func removeDependencyTriggersReloadAndRefreshDetail() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        let initialDetailJSON = """
        [
          {
            "id":"bd-3",
            "title":"In progress",
            "status":"in_progress",
            "dependencies":[{"id":"bd-1","title":"Backlog one","status":"open"}]
          }
        ]
        """
        runner.enqueue(arguments: ["show", "bd-3", "--json"], stdout: initialDetailJSON)
        store.selectIssue(id: "bd-3")
        for _ in 0..<50 {
            if store.selectedIssueDetail?.dependencies != nil { break }
            await Task.yield()
        }
        #expect(store.selectedIssueDetail?.dependencies?.first?.id == "bd-1")

        runner.enqueue(arguments: ["dep", "remove", "bd-3", "bd-1"], stdout: "")
        runner.enqueue(arguments: ["list", "--json"], stdout: IssueStoreTests.listFixture)
        runner.enqueue(arguments: ["ready", "--json"], stdout: IssueStoreTests.readyFixture)
        let refreshedDetailJSON = #"[{"id":"bd-3","title":"In progress","status":"in_progress"}]"#
        runner.enqueue(arguments: ["show", "bd-3", "--json"], stdout: refreshedDetailJSON)

        await store.removeDependency(blockerID: "bd-1", from: "bd-3")

        #expect(store.errorMessage == nil)
        #expect(store.selectedIssueDetail?.dependencies == nil)
    }

    @Test("reopen and update issue mutations succeed and reload")
    func reopenAndUpdateMutations() async throws {
        let runner = StubCommandRunner()
        enqueueReload(runner)
        let store = makeStore(stubbing: runner)
        await store.reload()

        runner.enqueue(
            arguments: ["reopen", "bd-5", "--json"],
            stdout: #"[{"id":"bd-5","title":"Closed","status":"open"}]"#
        )
        let listAfterReopen = """
        [
          {"id":"bd-5","title":"Closed","status":"open","priority":3}
        ]
        """
        runner.enqueue(arguments: ["list", "--json"], stdout: listAfterReopen)
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        await store.reopen(id: "bd-5")
        #expect(store.errorMessage == nil)
        #expect(store.doneIssues.isEmpty)

        runner.enqueue(
            arguments: ["update", "bd-5", "--title", "Renamed", "--json"],
            stdout: #"[{"id":"bd-5","title":"Renamed","status":"open"}]"#
        )
        let listAfterUpdate = """
        [
          {"id":"bd-5","title":"Renamed","status":"open","priority":3}
        ]
        """
        runner.enqueue(arguments: ["list", "--json"], stdout: listAfterUpdate)
        runner.enqueue(arguments: ["ready", "--json"], stdout: "[]")

        await store.update(id: "bd-5", UpdateIssueInput(title: "Renamed"))
        #expect(store.issues.first?.title == "Renamed")
    }
}
