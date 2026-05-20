import Foundation

public enum TerminalLauncher {
    public enum LaunchError: Error, LocalizedError, Sendable {
        case launchFailed(String)

        public var errorDescription: String? {
            switch self {
            case let .launchFailed(detail):
                return "Failed to open Terminal: \(detail)"
            }
        }
    }

    public static func openTerminal(at projectURL: URL) throws {
        let cd = "cd " + quoteForShell(projectURL.path)
        try run(appleScript: terminalScript(command: cd))
    }

    public static func openTerminal(at projectURL: URL, command: String) throws {
        let cd = "cd " + quoteForShell(projectURL.path)
        let combined = command.isEmpty ? cd : "\(cd) && \(command)"
        try run(appleScript: terminalScript(command: combined))
    }

    private static func terminalScript(command: String) -> String {
        let escaped = escapeForAppleScript(command)
        return """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
    }

    private static func run(appleScript: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        do {
            try process.run()
        } catch {
            throw LaunchError.launchFailed(error.localizedDescription)
        }
    }

    private static func quoteForShell(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
