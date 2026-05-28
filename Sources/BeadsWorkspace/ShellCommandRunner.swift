#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation

public enum ShellCommandRunnerError: LocalizedError, Sendable {
    case launchFailed(command: String, underlying: String)
    case timedOut(command: String, timeout: TimeInterval)
    case cancelled(command: String)

    public var errorDescription: String? {
        switch self {
        case let .launchFailed(command, underlying):
            return "Failed to launch \(command): \(underlying)"
        case let .timedOut(command, timeout):
            return "\(command) timed out after \(timeout) seconds."
        case let .cancelled(command):
            return "\(command) was cancelled."
        }
    }
}

public final class ShellCommandRunner: CommandRunning, @unchecked Sendable {
    public let timeout: TimeInterval
    public let historyLimit: Int

    private let lock = NSLock()
    private var historyStorage: [CommandSnapshot] = []

    public init(timeout: TimeInterval = 30, historyLimit: Int = 25) {
        self.timeout = timeout
        self.historyLimit = max(1, historyLimit)
    }

    public var history: [CommandSnapshot] {
        lock.withLock { historyStorage }
    }

    public func run(command: String, arguments: [String], workingDirectory: URL) async throws -> CommandResult {
        let startDate = Date()
        let process = Process()
        let processBox = ProcessBox(process)
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutBuffer = ThreadSafeDataBuffer()
        let stderrBuffer = ThreadSafeDataBuffer()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // macOS GUI apps (launched from Finder/Spotlight/Applications) receive a
        // minimal PATH that excludes Homebrew. Prepend the common Homebrew and local
        // bin paths so tools like `bd` (installed via brew) are always resolvable,
        // regardless of how the app was launched.
        var env = ProcessInfo.processInfo.environment
        let brewPaths = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin"]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (brewPaths + [currentPath]).joined(separator: ":")
        process.environment = env

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            stdoutBuffer.append(data)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            stderrBuffer.append(data)
        }

        let startTimeoutTask = timeout > 0
        let timeoutInterval = timeout

        defer {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
        }

        do {
            try process.run()
        } catch {
            let durationMs = Self.durationMs(since: startDate)
            let snapshot = CommandSnapshot(
                command: command,
                arguments: arguments,
                workingDirectory: workingDirectory,
                stdout: "",
                stderr: "",
                exitCode: -1,
                durationMs: durationMs,
                errorMessage: error.localizedDescription
            )
            record(snapshot)
            throw ShellCommandRunnerError.launchFailed(command: command, underlying: error.localizedDescription)
        }

        let terminationCoordinator = ProcessTerminationCoordinator()
        process.terminationHandler = { terminatedProcess in
            terminationCoordinator.processDidTerminate(terminatedProcess)
        }

        do {
            let outcome = try await withTaskCancellationHandler(operation: {
                try await withThrowingTaskGroup(of: RunOutcome.self) { group in
                    group.addTask {
                        .finished(await terminationCoordinator.wait())
                    }

                    if startTimeoutTask {
                        group.addTask {
                            try await Task.sleep(nanoseconds: Self.timeoutNanoseconds(timeoutInterval))
                            return .timedOut
                        }
                    }

                    guard let first = try await group.next() else {
                        throw CancellationError()
                    }

                    group.cancelAll()
                    return first
                }
            }, onCancel: {
                processBox.process.terminate()
            })

            switch outcome {
            case let .finished(exitCode):
                let result = finalizeResult(
                    command: command,
                    arguments: arguments,
                    workingDirectory: workingDirectory,
                    exitCode: exitCode,
                    stdoutPipe: stdoutPipe,
                    stderrPipe: stderrPipe,
                    stdoutBuffer: stdoutBuffer,
                    stderrBuffer: stderrBuffer,
                    startDate: startDate,
                    errorMessage: nil
                )
                return result
            case .timedOut:
                processBox.process.terminate()
                let exitCode = await terminationCoordinator.wait()
                let durationMs = Self.durationMs(since: startDate)
                let snapshot = CommandSnapshot(
                    command: command,
                    arguments: arguments,
                    workingDirectory: workingDirectory,
                    stdout: Self.decoded(stdoutBuffer.data),
                    stderr: Self.decoded(stderrBuffer.data),
                    exitCode: exitCode,
                    durationMs: durationMs,
                    errorMessage: "Timed out after \(timeout) seconds."
                )
                record(snapshot)
                throw ShellCommandRunnerError.timedOut(command: command, timeout: timeout)
            }
        } catch is CancellationError {
            processBox.process.terminate()
            let exitCode = await terminationCoordinator.wait()
            let durationMs = Self.durationMs(since: startDate)
            let snapshot = CommandSnapshot(
                command: command,
                arguments: arguments,
                workingDirectory: workingDirectory,
                stdout: Self.decoded(stdoutBuffer.data),
                stderr: Self.decoded(stderrBuffer.data),
                exitCode: exitCode,
                durationMs: durationMs,
                errorMessage: "Cancelled."
            )
            record(snapshot)
            throw ShellCommandRunnerError.cancelled(command: command)
        }
    }

    private func finalizeResult(
        command: String,
        arguments: [String],
        workingDirectory: URL,
        exitCode: Int32,
        stdoutPipe: Pipe,
        stderrPipe: Pipe,
        stdoutBuffer: ThreadSafeDataBuffer,
        stderrBuffer: ThreadSafeDataBuffer,
        startDate: Date,
        errorMessage: String?
    ) -> CommandResult {
        let stdoutData = Self.collectOutput(from: stdoutPipe.fileHandleForReading, buffer: stdoutBuffer)
        let stderrData = Self.collectOutput(from: stderrPipe.fileHandleForReading, buffer: stderrBuffer)
        let durationMs = Self.durationMs(since: startDate)
        let snapshot = CommandSnapshot(
            command: command,
            arguments: arguments,
            workingDirectory: workingDirectory,
            stdout: Self.decoded(stdoutData),
            stderr: Self.decoded(stderrData),
            exitCode: exitCode,
            durationMs: durationMs,
            errorMessage: errorMessage
        )
        record(snapshot)
        return CommandResult(
            command: command,
            arguments: arguments,
            workingDirectory: workingDirectory,
            stdout: snapshot.stdout,
            stderr: snapshot.stderr,
            exitCode: exitCode,
            durationMs: durationMs
        )
    }

    private func record(_ snapshot: CommandSnapshot) {
        lock.withLock {
            historyStorage.append(snapshot)
            if historyStorage.count > historyLimit {
                historyStorage.removeFirst(historyStorage.count - historyLimit)
            }
        }
    }

    private static func collectOutput(from handle: FileHandle, buffer: ThreadSafeDataBuffer) -> Data {
        handle.readabilityHandler = nil
        let data = handle.readDataToEndOfFile()
        return buffer.data + data
    }

    private static func decoded(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
    }

    private static func durationMs(since startDate: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startDate) * 1000))
    }

    private static func timeoutNanoseconds(_ timeout: TimeInterval) -> UInt64 {
        UInt64(max(0, timeout) * 1_000_000_000)
    }

    private enum RunOutcome {
        case finished(Int32)
        case timedOut
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process: Process

    init(_ process: Process) {
        self.process = process
    }
}

private final class ProcessTerminationCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int32, Never>?
    private var exitCode: Int32?

    func processDidTerminate(_ process: Process) {
        let continuation: CheckedContinuation<Int32, Never>? = lock.withLock {
            let code = process.terminationStatus
            exitCode = code
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }

        continuation?.resume(returning: process.terminationStatus)
    }

    func wait() async -> Int32 {
        if let exitCode {
            return exitCode
        }

        return await withCheckedContinuation { continuation in
            let exitCodeToResume: Int32? = lock.withLock {
                if let exitCode {
                    return exitCode
                }

                self.continuation = continuation
                if let exitCode {
                    self.continuation = nil
                    return exitCode
                }

                return nil
            }

            if let exitCodeToResume {
                continuation.resume(returning: exitCodeToResume)
            }
        }
    }
}

private final class ThreadSafeDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ data: Data) {
        lock.withLock {
            buffer.append(data)
        }
    }

    var data: Data {
        lock.withLock { buffer }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
