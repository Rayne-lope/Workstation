import Foundation
@testable import BeadsWorkspace

final class StubCommandRunner: CommandRunning, @unchecked Sendable {
    struct Stub {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        let error: Error?

        init(stdout: String = "", stderr: String = "", exitCode: Int32 = 0, error: Error? = nil) {
            self.stdout = stdout
            self.stderr = stderr
            self.exitCode = exitCode
            self.error = error
        }
    }

    struct Call: Equatable {
        let command: String
        let arguments: [String]
        let workingDirectory: URL
    }

    enum MockError: Error, LocalizedError {
        case noStubMatched(arguments: [String])

        var errorDescription: String? {
            switch self {
            case let .noStubMatched(arguments):
                return "No stub matched arguments: \(arguments)"
            }
        }
    }

    private let lock = NSLock()
    private var stubs: [(arguments: [String], stub: Stub)] = []
    private var callLog: [Call] = []

    var calls: [Call] {
        lock.withLock { callLog }
    }

    func enqueue(
        arguments: [String],
        stdout: String = "",
        stderr: String = "",
        exitCode: Int32 = 0,
        error: Error? = nil
    ) {
        lock.withLock {
            stubs.append((arguments, Stub(stdout: stdout, stderr: stderr, exitCode: exitCode, error: error)))
        }
    }

    func run(command: String, arguments: [String], workingDirectory: URL) async throws -> CommandResult {
        let stub: Stub = try lock.withLock {
            callLog.append(Call(command: command, arguments: arguments, workingDirectory: workingDirectory))
            guard let index = stubs.firstIndex(where: { $0.arguments == arguments }) else {
                throw MockError.noStubMatched(arguments: arguments)
            }
            let entry = stubs.remove(at: index)
            return entry.stub
        }

        if let error = stub.error {
            throw error
        }

        return CommandResult(
            command: command,
            arguments: arguments,
            workingDirectory: workingDirectory,
            stdout: stub.stdout,
            stderr: stub.stderr,
            exitCode: stub.exitCode,
            durationMs: 0
        )
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
