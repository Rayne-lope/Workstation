import Foundation
import Observation
#if canImport(BeadsContract)
import BeadsContract
#endif

public struct ScheduledLaunch: Identifiable, Sendable {
    public let id: UUID
    public let issueID: String
    public let issueTitle: String
    public let profileName: String
    public let profileID: UUID
    public let queuedAt: Date

    public init(id: UUID = UUID(), issueID: String, issueTitle: String, profileName: String, profileID: UUID, queuedAt: Date = Date()) {
        self.id = id
        self.issueID = issueID
        self.issueTitle = issueTitle
        self.profileName = profileName
        self.profileID = profileID
        self.queuedAt = queuedAt
    }
}

public enum SchedulerState: Equatable, Sendable {
    case idle
    case polling
    case launching(issueID: String)
    case paused(reason: String)
}

/// Background poller that auto-claims and auto-launches issues assigned to executor agents.
/// Owned by AppViewModel; binds back to it for launching and history lookups.
@MainActor
@Observable
public final class AgentScheduler {
    public var state: SchedulerState = .idle
    public var lastPollAt: Date?
    public var errorMessage: String?
    public var pendingApprovals: [ScheduledLaunch] = []

    private var consecutiveFailures: Int = 0
    private var pollTask: Task<Void, Never>?

    // Set by AppViewModel via bind()
    var onClaimAndLaunch: (@MainActor (String, UUID) async -> Void)?
    var activeRunCount: (() -> Int)?
    var dailyRunCount: ((UUID) -> Int)?
    var isIssueAlreadyRunning: ((String) -> Bool)?
    var readyIssues: (() async throws -> [BeadIssue])?
    var executorProfile: ((String) -> AgentProfile?)?
    var preferences: (() -> SchedulerPreferences)?

    public init() {}

    public func start() {
        pollTask?.cancel()
        // Recover from a paused state (3 consecutive poll failures) so toggling
        // the scheduler off/on in Settings restarts polling cleanly.
        consecutiveFailures = 0
        errorMessage = nil
        state = .idle
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                let interval = self?.preferences?().pollIntervalSeconds ?? 60
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
        state = .idle
    }

    public func approveLaunch(_ launch: ScheduledLaunch) {
        pendingApprovals.removeAll { $0.id == launch.id }
        Task { [weak self] in
            await self?.onClaimAndLaunch?(launch.issueID, launch.profileID)
        }
    }

    public func rejectLaunch(_ launch: ScheduledLaunch) {
        pendingApprovals.removeAll { $0.id == launch.id }
    }

    // MARK: - Poll

    private func poll() async {
        guard let prefs = preferences?(), prefs.isEnabled else { return }
        state = .polling
        lastPollAt = Date()

        do {
            let issues = try await readyIssues?() ?? []
            let activeRuns = activeRunCount?() ?? 0

            for issue in issues {
                guard !Task.isCancelled else { break }
                guard activeRunCount?() ?? 0 < prefs.maxConcurrentRuns else { break }
                try await considerLaunch(issue: issue, prefs: prefs, currentActive: activeRuns)
            }

            consecutiveFailures = 0
            state = .idle
        } catch {
            consecutiveFailures += 1
            errorMessage = error.localizedDescription
            if consecutiveFailures >= 3 {
                state = .paused(reason: "3 consecutive poll failures: \(error.localizedDescription)")
                pollTask?.cancel()
            } else {
                state = .idle
            }
        }
    }

    private func considerLaunch(issue: BeadIssue, prefs: SchedulerPreferences, currentActive: Int) async throws {
        // 1. Already running?
        guard isIssueAlreadyRunning?(issue.id) != true else { return }
        // 2. Status must be open or ready
        guard issue.status == "open" || issue.status == "ready" else { return }
        // 3. Has blocker?
        if let blockers = issue.blockedBy, !blockers.isEmpty { return }
        // 4. Concurrency gate
        guard (activeRunCount?() ?? 0) < prefs.maxConcurrentRuns else { return }
        // 5. Resolve profile
        guard let assignee = issue.assignee,
              let profile = executorProfile?(assignee),
              profile.canExecuteCode,
              profile.shouldClaimIssue else { return }
        // 6. Per-profile enabled?
        let profileKey = profile.id.uuidString
        let profilePrefs = prefs.perProfileSettings[profileKey]
        guard profilePrefs?.enabled ?? true else { return }
        // 7. Daily run limit
        let todayCount = dailyRunCount?(profile.id) ?? 0
        let limit = profilePrefs?.dailyRunLimit ?? 10
        guard todayCount < limit else { return }
        // 8. Approval gate
        let needsApproval = prefs.requireApprovalBeforeLaunch || (profilePrefs?.requireApproval ?? false)
        if needsApproval {
            let pending = ScheduledLaunch(
                issueID: issue.id,
                issueTitle: issue.title,
                profileName: profile.name,
                profileID: profile.id
            )
            if !pendingApprovals.contains(where: { $0.issueID == issue.id }) && pendingApprovals.count < 10 {
                pendingApprovals.append(pending)
            }
            return
        }

        // Launch
        state = .launching(issueID: issue.id)
        await onClaimAndLaunch?(issue.id, profile.id)
    }
}
