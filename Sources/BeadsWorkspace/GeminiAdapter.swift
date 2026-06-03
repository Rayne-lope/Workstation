import Foundation

/// Adapter for Google Gemini CLI (`agy`).
/// `agy` has no structured stdout, so this adapter:
/// 1. Spawns `agy --dangerously-skip-permissions "<prompt>"`
/// 2. Detects the newly created session dir under `~/.gemini/antigravity-cli/brain/`
///    (chosen by creation time, only dirs created after launch)
/// 3. Tails `transcript.jsonl` and maps each entry to a TimelineDelta
/// 4. Completes when the process terminates
public final class GeminiAdapter: AgentOutputAdapter, @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var process: Process?
    nonisolated(unsafe) private var pollTask: Task<Void, Never>?
    nonisolated(unsafe) private var finished = false
    nonisolated(unsafe) private var _lastExitCode: Int32?

    public var lastExitCode: Int32? { lock.withLock { _lastExitCode } }

    private static let brainDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".gemini/antigravity-cli/brain")

    public init() {}

    public func start(runID: UUID, prompt: String, worktreeURL: URL) async throws -> AsyncStream<TimelineDelta> {
        let launchTime = Date()
        let process = AgentProcessEnvironment.makeProcess(
            binary: "agy",
            arguments: ["--dangerously-skip-permissions", prompt],
            workingDirectory: worktreeURL
        )
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        let parser = GeminiTranscriptParser(runID: runID)

        return AsyncStream { continuation in
            continuation.yield(parser.startedDelta())

            do {
                try process.run()
            } catch {
                continuation.yield(.insert(AgentTimelineEvent(
                    stableKey: "gemini-start-\(runID)",
                    runID: runID,
                    sequence: 0,
                    type: .problem,
                    title: "Failed to launch Gemini",
                    subtitle: error.localizedDescription,
                    status: .failure,
                    source: .structuredHook,
                    confidence: .high
                )))
                continuation.finish()
                return
            }
            self.lock.withLock { self.process = process }

            let task = Task.detached { [weak self] in
                await self?.tail(
                    process: process,
                    launchTime: launchTime,
                    parser: parser,
                    continuation: continuation
                )
                continuation.finish()
            }
            self.lock.withLock { self.pollTask = task }
            continuation.onTermination = { [weak self] _ in
                self?.terminate()
            }
        }
    }

    public func kill() {
        terminate()
    }

    private func terminate() {
        let (proc, task) = lock.withLock { () -> (Process?, Task<Void, Never>?) in
            guard !finished else { return (nil, nil) }
            finished = true
            return (process, pollTask)
        }
        task?.cancel()
        proc?.interrupt()
    }

    // MARK: - Tailing

    private func tail(
        process: Process,
        launchTime: Date,
        parser: GeminiTranscriptParser,
        continuation: AsyncStream<TimelineDelta>.Continuation
    ) async {
        // Wait up to 8s for the session directory to appear.
        var transcriptURL: URL?
        for _ in 0..<160 {
            if Task.isCancelled { return }
            if let dir = Self.newestSessionDir(after: launchTime) {
                transcriptURL = dir.appendingPathComponent("transcript.jsonl")
                break
            }
            if !process.isRunning { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        guard let transcriptURL else {
            process.waitUntilExit()
            lock.withLock { _lastExitCode = process.terminationStatus }
            for delta in parser.finish(exitCode: process.terminationStatus, confidence: .low) {
                continuation.yield(delta)
            }
            return
        }

        var byteOffset = 0
        // Keep tailing while the process runs (plus a final drain after exit).
        while true {
            if Task.isCancelled { return }
            let running = process.isRunning
            for delta in parser.readNewEntries(from: transcriptURL, byteOffset: &byteOffset) {
                continuation.yield(delta)
            }
            if !running { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        // Final drain.
        for delta in parser.readNewEntries(from: transcriptURL, byteOffset: &byteOffset) {
            continuation.yield(delta)
        }
        let exitCode = process.isRunning ? 0 : process.terminationStatus
        lock.withLock { _lastExitCode = exitCode }
        for delta in parser.finish(exitCode: exitCode, confidence: .high) {
            continuation.yield(delta)
        }
    }

    /// Returns the session dir created most recently after `time`, or nil.
    private static func newestSessionDir(after time: Date) -> URL? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: brainDir,
            includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let candidates = entries.compactMap { url -> (URL, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .isDirectoryKey]),
                  values.isDirectory == true,
                  let created = values.creationDate,
                  created >= time.addingTimeInterval(-1) else { return nil }
            return (url, created)
        }
        return candidates.max(by: { $0.1 < $1.1 })?.0
    }
}

// MARK: - Transcript Parser

final class GeminiTranscriptParser: @unchecked Sendable {
    private let runID: UUID
    private var sequence: Int64 = 0
    private var seenStepIndices = Set<Int>()
    private var emittedDone = false

    init(runID: UUID) {
        self.runID = runID
    }

    private func nextSeq() -> Int64 {
        sequence += 1
        return sequence
    }

    func startedDelta() -> TimelineDelta {
        .insert(AgentTimelineEvent(
            stableKey: "gemini-start-\(runID)",
            runID: runID,
            sequence: nextSeq(),
            type: .started,
            title: "Gemini started",
            status: .working,
            source: .structuredHook,
            confidence: .high
        ))
    }

    func readNewEntries(from url: URL, byteOffset: inout Int) -> [TimelineDelta] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        try? handle.seek(toOffset: UInt64(byteOffset))
        let newData = handle.readDataToEndOfFile()
        guard !newData.isEmpty else { return [] }
        byteOffset += newData.count

        guard let text = String(data: newData, encoding: .utf8) else { return [] }
        var deltas: [TimelineDelta] = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
            let stepIndex = obj["step_index"] as? Int ?? -1
            if stepIndex >= 0 {
                if seenStepIndices.contains(stepIndex) { continue }
                seenStepIndices.insert(stepIndex)
            }
            if let delta = parseEntry(obj, stepIndex: stepIndex) {
                deltas.append(delta)
            }
        }
        return deltas
    }

    func finish(exitCode: Int32, confidence: TimelineEventConfidence) -> [TimelineDelta] {
        guard !emittedDone else { return [] }
        emittedDone = true
        let success = exitCode == 0
        return [.insert(AgentTimelineEvent(
            stableKey: "gemini-done-\(runID)",
            runID: runID,
            sequence: nextSeq(),
            type: .done,
            title: success ? "Done" : "Run failed",
            subtitle: success ? nil : "exit \(exitCode)",
            status: success ? .success : .failure,
            source: .structuredHook,
            confidence: confidence
        ))]
    }

    private func parseEntry(_ obj: [String: Any], stepIndex: Int) -> TimelineDelta? {
        let type = obj["type"] as? String ?? ""
        let keySuffix = stepIndex >= 0 ? "\(stepIndex)" : "\(nextSeq())"
        let stableKey = "gemini-step-\(runID)-\(keySuffix)"

        switch type {
        case "PLANNER_RESPONSE":
            guard let toolCalls = obj["tool_calls"] as? [[String: Any]],
                  let first = toolCalls.first else { return nil }
            let toolName = first["name"] as? String ?? "tool"
            let args = first["args"] as? [String: Any]
            return toolCallDelta(toolName: toolName, args: args, stableKey: stableKey)

        case "READ_FILE", "WRITE_FILE", "EDIT_FILE", "REPLACE_IN_FILE":
            let filePath = stringArg(obj, keys: ["file_path", "FilePath"])
            let isWrite = type != "READ_FILE"
            return .insert(AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: nextSeq(),
                type: .fileChange,
                title: isWrite ? "Writing \(fileName(filePath))" : "Reading \(fileName(filePath))",
                subtitle: filePath,
                status: .success,
                source: .structuredHook,
                confidence: .high,
                relatedFile: filePath
            ))

        case "LIST_DIRECTORY", "GLOB_SEARCH", "GREP_SEARCH", "SEARCH":
            return .insert(AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: nextSeq(),
                type: .command,
                title: "Searching…",
                status: .success,
                source: .structuredHook,
                confidence: .high
            ))

        case "RUN_COMMAND", "RUN_BASH", "BASH":
            let cmd = stringArg(obj, keys: ["command"]) ?? "command"
            return .insert(AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: nextSeq(),
                type: .command,
                title: "$ \(truncate(cmd))",
                status: .success,
                source: .structuredHook,
                confidence: .high,
                relatedCommand: cmd
            ))

        case "ERROR":
            let content = obj["content"] as? String ?? "Error"
            return .appendProblem(AgentRunProblem(
                stableKey: "gemini-err-\(runID)-\(keySuffix)",
                runID: runID,
                severity: .error,
                message: content,
                source: .structuredHook,
                confidence: .high
            ))

        default:
            return nil
        }
    }

    private func toolCallDelta(toolName: String, args: [String: Any]?, stableKey: String) -> TimelineDelta {
        let filePath = (args?["file_path"] as? String) ?? (args?["FilePath"] as? String)
        let cmd = args?["command"] as? String

        let (type, title, subtitle, relatedFile): (TimelineEventType, String, String?, String?) = {
            switch toolName.lowercased() {
            case "read_file":
                return (.fileChange, "Reading \(fileName(filePath))", filePath, filePath)
            case "write_file", "create_file", "edit_file":
                return (.fileChange, "Editing \(fileName(filePath))", filePath, filePath)
            case "run_command", "bash":
                return (.command, "$ \(truncate(cmd ?? "command"))", nil, nil)
            case "list_dir", "list_directory", "glob_search", "grep_search":
                return (.command, "Searching…", nil, nil)
            default:
                return (.command, toolName, nil, nil)
            }
        }()

        return .insert(AgentTimelineEvent(
            stableKey: stableKey,
            runID: runID,
            sequence: nextSeq(),
            type: type,
            title: title,
            subtitle: subtitle,
            status: .working,
            source: .structuredHook,
            confidence: .high,
            relatedFile: relatedFile,
            relatedCommand: cmd
        ))
    }

    private func stringArg(_ obj: [String: Any], keys: [String]) -> String? {
        if let calls = obj["tool_calls"] as? [[String: Any]],
           let args = calls.first?["args"] as? [String: Any] {
            for key in keys {
                if let value = args[key] as? String { return value }
            }
        }
        for key in keys {
            if let value = obj[key] as? String { return value }
        }
        return nil
    }

    private func fileName(_ path: String?) -> String {
        path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file"
    }

    private func truncate(_ s: String) -> String {
        s.count > 60 ? String(s.prefix(60)) + "…" : s
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
