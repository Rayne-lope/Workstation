import Foundation

/// Shared environment + IO helpers for agent output adapters.
///
/// GUI apps launched from Finder/Spotlight inherit a minimal PATH that excludes
/// Homebrew, npm-global, nvm, bun, etc. Agent CLIs (`claude`, `opencode`, `agy`)
/// live in those directories, so spawning them via `/usr/bin/env` with the bare
/// inherited PATH fails with "command not found". This helper resolves the user's
/// real login-shell PATH once and unions it with common install locations.
public enum AgentProcessEnvironment {
    /// Cached environment dictionary. Resolved once on first access.
    public static let shared: [String: String] = resolve()

    private static func resolve() -> [String: String] {
        var env = ProcessInfo.processInfo.environment

        let resolvedPaths = loginShellPath()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let commonPaths = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin",
            "\(home)/.local/bin", "\(home)/.bun/bin", "\(home)/.deno/bin",
            "\(home)/.npm-global/bin", "\(home)/.cargo/bin", "\(home)/.volta/bin",
        ]
        let inherited = (env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
            .split(separator: ":").map(String.init)

        // Union, preserving order: login-shell PATH first (most accurate), then
        // common locations, then whatever was inherited. Dedupe keeps it tidy.
        var seen = Set<String>()
        var ordered: [String] = []
        for path in resolvedPaths + commonPaths + inherited where !path.isEmpty {
            if seen.insert(path).inserted { ordered.append(path) }
        }
        env["PATH"] = ordered.joined(separator: ":")

        // Disable color/ANSI so JSON output stays clean and parseable.
        env["NO_COLOR"] = "1"
        env["CLICOLOR"] = "0"
        env["CLICOLOR_FORCE"] = "0"
        env["FORCE_COLOR"] = "0"
        env["CLAUDE_COLOR"] = "0"
        env["TERM"] = "dumb"
        return env
    }

    /// Runs `zsh -lc 'echo $PATH'` to capture the user's login-shell PATH
    /// (sources `.zshenv`/`.zprofile`/`.zlogin`). Returns [] on any failure.
    private static func loginShellPath() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "echo $PATH"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        // Guard against a hung shell: kill after 3s.
        let deadline = DispatchTime.now() + 3.0
        let timeoutQueue = DispatchQueue(label: "agent.path.timeout")
        timeoutQueue.asyncAfter(deadline: deadline) {
            if process.isRunning { process.terminate() }
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }

        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // rc files may print noise; the PATH is the last line containing a slash.
        let candidate = output.split(separator: "\n")
            .map(String.init)
            .last(where: { $0.contains("/") }) ?? output
        return candidate.split(separator: ":").map(String.init)
    }

    /// Builds a Process configured to run `binary args...` via `/usr/bin/env`
    /// with the resolved environment and working directory. Arguments are passed
    /// argv-style (no shell parsing), so the prompt needs no escaping.
    public static func makeProcess(
        binary: String,
        arguments: [String],
        workingDirectory: URL
    ) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [binary] + arguments
        process.currentDirectoryURL = workingDirectory
        process.environment = shared
        return process
    }
}

/// Accumulates streamed bytes and yields complete UTF-8 lines.
/// Not thread-safe on its own; callers serialize access (e.g. a single
/// readabilityHandler queue) or guard externally.
public final class LineBuffer: @unchecked Sendable {
    private var buffer = Data()

    public init() {}

    /// Appends new data and returns any complete lines (newline-delimited).
    public func append(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        while let idx = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<idx]
            buffer.removeSubrange(buffer.startIndex...idx)
            if let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespaces), !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }

    /// Returns any trailing data not terminated by a newline, then clears.
    public func flush() -> String? {
        defer { buffer.removeAll() }
        guard !buffer.isEmpty,
              let line = String(data: buffer, encoding: .utf8)?
                .trimmingCharacters(in: .whitespaces),
              !line.isEmpty else { return nil }
        return line
    }
}
