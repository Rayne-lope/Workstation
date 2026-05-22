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
        let cd = try makeCDCommand(projectURL: projectURL)
        try run(appleScript: terminalScript(command: cd))
    }

    public static func openTerminal(at projectURL: URL, command: String) throws {
        let cd = try makeCDCommand(projectURL: projectURL)
        let combined = command.isEmpty ? cd : "\(cd) && \(command)"
        try run(appleScript: terminalScript(command: combined))
    }

    static func makeCDCommand(projectURL: URL) throws -> String {
        let path = projectURL.path
        guard !path.isEmpty else {
            throw LaunchError.launchFailed("Project path is empty")
        }
        return "cd " + quoteForShell(path)
    }

    static func terminalScript(command: String) -> String {
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

    static func quoteForShell(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escapes a string for inclusion in an AppleScript double-quoted string literal.
    /// Only `"` needs escaping; backslashes are left intact because the input
    /// already contains shell escapes (e.g. `\"`) that must survive to the shell.
    static func escapeForAppleScript(_ string: String) -> String {
        string.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
