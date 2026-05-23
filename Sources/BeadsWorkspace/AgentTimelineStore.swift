import Foundation

public final class AgentTimelineStore: @unchecked Sendable {
    public static let shared = AgentTimelineStore()

    private let lock = NSLock()

    // Store in-memory states per runID
    private var eventsMap: [UUID: [AgentTimelineEvent]] = [:]
    private var problemsMap: [UUID: [AgentRunProblem]] = [:]
    private var commandsMap: [UUID: [TimelineCommandRun]] = [:]
    private var activeApprovalMap: [UUID: AgentApprovalRequest] = [:]

    public init() {}

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        eventsMap.removeAll()
        problemsMap.removeAll()
        commandsMap.removeAll()
        activeApprovalMap.removeAll()
    }

    public func clear(forRunID runID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        eventsMap.removeValue(forKey: runID)
        problemsMap.removeValue(forKey: runID)
        commandsMap.removeValue(forKey: runID)
        activeApprovalMap.removeValue(forKey: runID)
    }

    // MARK: - Event Accessors

    public func events(forRunID runID: UUID) -> [AgentTimelineEvent] {
        lock.lock()
        defer { lock.unlock() }
        return eventsMap[runID] ?? []
    }

    public func compactEvents(forRunID runID: UUID) -> [AgentTimelineEvent] {
        let all = events(forRunID: runID)
        // Returns the latest 5 meaningful events
        return Array(all.suffix(5))
    }

    public func activeApproval(forRunID runID: UUID) -> AgentApprovalRequest? {
        lock.lock()
        defer { lock.unlock() }
        return activeApprovalMap[runID]
    }

    public func problems(forRunID runID: UUID) -> [AgentRunProblem] {
        lock.lock()
        defer { lock.unlock() }
        return problemsMap[runID] ?? []
    }

    public func commands(forRunID runID: UUID) -> [TimelineCommandRun] {
        lock.lock()
        defer { lock.unlock() }
        return commandsMap[runID] ?? []
    }

    // MARK: - Delta Application & Mutators

    public func apply(delta: TimelineDelta, forRunID runID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        switch delta {
        case .insert(let event):
            var current = eventsMap[runID] ?? []
            // Prevent duplicates using stableKey
            if !current.contains(where: { $0.stableKey == event.stableKey }) {
                current.append(event)
                eventsMap[runID] = current
            }

        case .update(let stableKey, let newEvent):
            var current = eventsMap[runID] ?? []
            if let idx = current.firstIndex(where: { $0.stableKey == stableKey }) {
                current[idx] = newEvent
                eventsMap[runID] = current
            } else {
                current.append(newEvent)
                eventsMap[runID] = current
            }

        case .appendProblem(let problem):
            var current = problemsMap[runID] ?? []
            if !current.contains(where: { $0.stableKey == problem.stableKey }) {
                current.append(problem)
                problemsMap[runID] = current
            }

        case .updateApproval(let request):
            if let req = request {
                activeApprovalMap[runID] = req
            } else {
                activeApprovalMap.removeValue(forKey: runID)
            }

        case .group(_):
            // Grouping logic can be handled or custom folded in projections
            break
        }
    }

    // Allow updating/adding command runs directly
    public func registerCommandStart(runID: UUID, command: TimelineCommandRun) {
        lock.lock()
        defer { lock.unlock() }
        var current = commandsMap[runID] ?? []
        if let idx = current.firstIndex(where: { $0.stableKey == command.stableKey }) {
            current[idx] = command
        } else {
            current.append(command)
        }
        commandsMap[runID] = current
    }

    public func registerCommandEnd(runID: UUID, stableKey: String, exitCode: Int32, endedAt: Date = Date(), status: TimelineEventStatus) {
        lock.lock()
        defer { lock.unlock() }
        var current = commandsMap[runID] ?? []
        if let idx = current.firstIndex(where: { $0.stableKey == stableKey }) {
            var cmd = current[idx]
            cmd.exitCode = exitCode
            cmd.endedAt = endedAt
            cmd.status = status
            current[idx] = cmd
            commandsMap[runID] = current
        }
    }
}
