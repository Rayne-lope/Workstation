import Foundation
#if canImport(BeadsContract)
import BeadsContract
#endif

/// Runs the project test suite in a given directory and parses the results.
/// Designed to be invoked from AppViewModel when a landing is triggered.
public actor WorktreeTestRunner {
    /// Maximum time (in seconds) to wait for the test suite before giving up.
    public let timeoutSeconds: Double

    public init(timeoutSeconds: Double = 180) {
        self.timeoutSeconds = timeoutSeconds
    }

    /// Run `swift test` in `directory` and return a parsed `TestRunResult`.
    public func run(in directory: URL) async -> TestRunResult {
        let start = Date()

        // Verify this is a Swift package before launching a process
        let packageSwift = directory.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageSwift.path) else {
            return TestRunResult(state: .notConfigured)
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["swift", "test"]
            process.currentDirectoryURL = directory

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let timeoutWorkItem = DispatchWorkItem {
                process.terminate()
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: TestRunResult(state: .notConfigured))
                return
            }

            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeoutSeconds,
                execute: timeoutWorkItem
            )

            // Read output on a background thread to avoid pipe-buffer deadlock,
            // then wait for the process to exit.
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            timeoutWorkItem.cancel()

            let elapsed = Date().timeIntervalSince(start)
            let timedOut = process.terminationReason == .uncaughtSignal

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let result = Self.parse(output: output, timedOut: timedOut, duration: elapsed)
            continuation.resume(returning: result)
        }
    }

    // MARK: - Output parsing

    /// Parse `swift test` output into a `TestRunResult`.
    /// Handles both Swift Testing (`.xctf` structured output isn't available here,
    /// so we rely on the human-readable text lines) and XCTest formats.
    static func parse(output: String, timedOut: Bool, duration: Double) -> TestRunResult {
        if timedOut {
            return TestRunResult(state: .timedOut, durationSeconds: duration)
        }

        let lines = output.components(separatedBy: .newlines)

        // Swift Testing format: "Test run with N tests in M suites passed after X seconds."
        // or "Test run with N tests in M suites passed after X seconds (N failed)."
        if let swiftTestingLine = lines.first(where: {
            $0.contains("Test run with") && ($0.contains("passed") || $0.contains("failed"))
        }) {
            return parseSwiftTestingLine(swiftTestingLine, duration: duration)
        }

        // XCTest format: "Executed N tests, with M failures"
        if let xcTestLine = lines.first(where: { $0.contains("Executed") && $0.contains("tests") }) {
            return parseXCTestLine(xcTestLine, lines: lines, duration: duration)
        }

        // Fallback: look for "error:" lines to detect failure without counts
        let hasErrors = lines.contains { $0.contains("error:") && !$0.hasPrefix("//") }
        if hasErrors {
            let failures = lines.filter { $0.contains("error:") && !$0.hasPrefix("//") }
            return TestRunResult(
                state: .failed,
                failureMessages: Array(failures.prefix(3)),
                durationSeconds: duration
            )
        }

        // If "BUILD SUCCEEDED" or "passed" is in output assume passing
        if output.contains("BUILD SUCCEEDED") || output.contains(" passed") {
            return TestRunResult(state: .passed, durationSeconds: duration)
        }

        return TestRunResult(state: .notConfigured, durationSeconds: duration)
    }

    private static func parseSwiftTestingLine(_ line: String, duration: Double) -> TestRunResult {
        // "Test run with 404 tests in 46 suites passed after 2.433 seconds."
        // "Test run with 10 tests in 3 suites passed after 1.2 seconds (2 failed)."
        var totalTests = 0
        var failedTests = 0

        // Extract total
        if let match = line.range(of: #"with (\d+) test"#, options: .regularExpression) {
            let part = String(line[match])
            if let n = part.components(separatedBy: .whitespaces)
                .compactMap(Int.init).first {
                totalTests = n
            }
        }

        // Extract failed count if present
        if let match = line.range(of: #"\((\d+) failed\)"#, options: .regularExpression) {
            let part = String(line[match])
            if let n = part.components(separatedBy: .whitespaces)
                .compactMap(Int.init).first {
                failedTests = n
            }
        }

        let passedTests = totalTests - failedTests
        let state: TestRunResult.State = failedTests > 0 ? .failed : .passed
        return TestRunResult(
            state: state,
            total: totalTests,
            passed: passedTests,
            failed: failedTests,
            durationSeconds: duration
        )
    }

    private static func parseXCTestLine(_ line: String, lines: [String], duration: Double) -> TestRunResult {
        // "Executed 10 tests, with 2 failures (2 unexpected) in 0.5 (0.6) seconds"
        var totalTests = 0
        var failedTests = 0

        let parts = line.components(separatedBy: .whitespaces).compactMap(Int.init)
        if parts.count >= 2 {
            totalTests = parts[0]
            failedTests = parts[1]
        }

        let failureLines = lines.filter { $0.contains("FAILED") || $0.contains("failed:") }
        let passedTests = totalTests - failedTests
        let state: TestRunResult.State = failedTests > 0 ? .failed : .passed
        return TestRunResult(
            state: state,
            total: totalTests,
            passed: passedTests,
            failed: failedTests,
            failureMessages: Array(failureLines.prefix(3)),
            durationSeconds: duration
        )
    }
}
