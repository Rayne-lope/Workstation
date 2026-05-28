import Foundation

/// Result of running the test suite in a workspace or worktree directory.
public struct TestRunResult: Sendable {
    public enum State: Sendable {
        /// All tests passed.
        case passed
        /// One or more tests failed.
        case failed
        /// Test runner did not complete within the timeout.
        case timedOut
        /// Test command could not be found or the directory is not a Swift package.
        case notConfigured
    }

    public let state: State
    public let total: Int
    public let passed: Int
    public let failed: Int
    /// Up to 3 failure summaries for display in the landing sheet.
    public let failureMessages: [String]
    public let durationSeconds: Double

    public init(
        state: State,
        total: Int = 0,
        passed: Int = 0,
        failed: Int = 0,
        failureMessages: [String] = [],
        durationSeconds: Double = 0
    ) {
        self.state = state
        self.total = total
        self.passed = passed
        self.failed = failed
        self.failureMessages = failureMessages
        self.durationSeconds = durationSeconds
    }

    /// Human-readable summary string, e.g. "246/246 passed" or "3/10 failed".
    public var summary: String {
        switch state {
        case .passed:
            return "\(total)/\(total) passed"
        case .failed:
            return "\(passed)/\(total) passed, \(failed) failed"
        case .timedOut:
            return "Timed out"
        case .notConfigured:
            return "No test command"
        }
    }
}
