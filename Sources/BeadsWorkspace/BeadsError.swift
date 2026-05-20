import Foundation

public enum BeadsAppError: Error, LocalizedError, Sendable {
    case bdNotInstalled
    case invalidProjectFolder
    case beadsNotInitialized
    case commandFailed(command: String, stderr: String, exitCode: Int32)
    case jsonDecodeFailed(raw: String)
    case timeout(command: String)
    case permissionDenied(path: String)

    public var userFacingMessage: String {
        errorDescription ?? "An unknown error occurred."
    }

    public var errorDescription: String? {
        switch self {
        case .bdNotInstalled:
            return "bd is not installed or is not available on your PATH."
        case .invalidProjectFolder:
            return "The selected folder is not a valid project folder."
        case .beadsNotInitialized:
            return "This project has not been initialized as a Beads workspace."
        case let .commandFailed(command, stderr, exitCode):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = trimmed.isEmpty ? "" : ": \(trimmed)"
            return "\(command) failed (exit \(exitCode))\(suffix)"
        case .jsonDecodeFailed:
            return "bd returned JSON that the app could not decode."
        case let .timeout(command):
            return "\(command) timed out."
        case let .permissionDenied(path):
            return "Permission denied for \(path)."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .bdNotInstalled:
            return "Install bd and make sure `bd --version` works in Terminal."
        case .invalidProjectFolder:
            return "Choose a different folder or fix folder permissions."
        case .beadsNotInitialized:
            return "Run `bd init` in the project root to create the Beads workspace."
        case .commandFailed:
            return "Run the command manually in Terminal and inspect stderr."
        case .jsonDecodeFailed:
            return "Open the debug panel, inspect the raw JSON, and update the parser if the schema changed."
        case .timeout:
            return "Try again or run the command manually to confirm it finishes."
        case .permissionDenied:
            return "Grant access to the folder or choose a different project root."
        }
    }
}

public typealias BeadsError = BeadsAppError
