import Foundation

/// A single focused interval — starts when user clicks "Focus" and ends when
/// they click "Pause" or "End". Pauses don't create new intervals; they
/// only track elapsed wall-clock time that should be excluded from totalMs.
struct FocusInterval: Codable, Identifiable, Hashable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    /// Milliseconds spent in this interval. Computed as endedAt - startedAt at end time.
    var durationMs: Int64 {
        guard let ended = endedAt else { return 0 }
        return Int64(ended.timeIntervalSince(startedAt) * 1000)
    }

    init(startedAt: Date = Date(), endedAt: Date? = nil) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

/// Full focus session for one issue. Persisted to .beads/focus/<issueID>.json.
struct FocusSessionData: Codable, Hashable {
    let issueID: String
    /// Completed intervals with known end times.
    var completedIntervals: [FocusInterval]
    /// The currently running interval (start time set, end time nil).
    var activeInterval: FocusInterval?
    /// Total wall-clock pause time accumulated across all pauses.
    var totalPauseMs: Int64

    var totalActiveMs: Int64 {
        completedIntervals.reduce(0) { $0 + $1.durationMs }
    }

    var isActive: Bool { activeInterval != nil }

    /// Returns the current wall-clock elapsed ms, accounting for all completed intervals
    /// and the currently active interval (if any), minus all accumulated pause time.
    func currentElapsedMs() -> Int64 {
        var elapsed = totalActiveMs
        if let active = activeInterval {
            elapsed += Int64(Date().timeIntervalSince(active.startedAt) * 1000)
        }
        return max(0, elapsed - totalPauseMs)
    }

    init(issueID: String) {
        self.issueID = issueID
        self.completedIntervals = []
        self.activeInterval = nil
        self.totalPauseMs = 0
    }
}