import Foundation
@testable import BeadsWorkspace

final class StubTerminalLauncher: TerminalLaunching, @unchecked Sendable {
    struct Call: Equatable {
        let projectURL: URL
        let command: String?
    }

    enum StubError: Error, LocalizedError {
        case launchFailed(String)

        var errorDescription: String? {
            switch self {
            case let .launchFailed(message):
                return message
            }
        }
    }

    private let lock = NSLock()
    private var callLog: [Call] = []
    private var nextError: Error?

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return callLog
    }

    func enqueueFailure(_ error: Error) {
        lock.lock()
        nextError = error
        lock.unlock()
    }

    func openTerminal(at projectURL: URL, command: String?) throws {
        lock.lock()
        callLog.append(Call(projectURL: projectURL, command: command))
        let error = nextError
        nextError = nil
        lock.unlock()

        if let error {
            throw error
        }
    }
}
