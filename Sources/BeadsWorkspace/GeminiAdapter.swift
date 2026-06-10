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
            // --print runs the prompt non-interactively; a bare positional
            // prompt would drop agy into its interactive UI and hang. Flags go
            // before the prompt: Go's flag parser stops at the first positional.
            arguments: ["--dangerously-skip-permissions", "--print", prompt],
            workingDirectory: worktreeURL
        )
        process.standardInput = FileHandle.nullDevice
        let drainPipe = Pipe()
        process.standardOutput = drainPipe
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        // Drain both pipes so agy never blocks on a full buffer; output is
        // unstructured, the transcript file is the real data source.
        drainPipe.fileHandleForReading.readabilityHandler = { _ = $0.availableData }
        stderrPipe.fileHandleForReading.readabilityHandler = { _ = $0.availableData }
        process.terminationHandler = { _ in
            drainPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
        }

        let parser = GeminiTranscriptParser(runID: runID)

        return AsyncStream { continuation in
            continuation.yield(parser.startedDelta())

            do {
                try process.run()
            } catch {
                continuation.yield(.insert(AgentTimelineEvent(
                    // Distinct from the started card's key or the store dedups it away.
                    stableKey: "gemini-launchfail-\(runID)",
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
        // Wait up to 15s for the transcript file to appear. The session dir is
        // created first; the transcript lands in .system_generated/logs a bit later.
        var transcriptURL: URL?
        for _ in 0..<300 {
            if Task.isCancelled { return }
            if let dir = Self.newestSessionDir(after: launchTime) {
                let candidate = dir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                if FileManager.default.fileExists(atPath: candidate.path) {
                    transcriptURL = candidate
                    break
                }
            }
            if !process.isRunning { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        // Fast runs can exit between checks; look once more after the loop.
        if transcriptURL == nil, let dir = Self.newestSessionDir(after: launchTime) {
            let candidate = dir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if FileManager.default.fileExists(atPath: candidate.path) {
                transcriptURL = candidate
            }
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
    /// Last seen `status` per step_index; a step reappears with a new status
    /// (RUNNING → DONE) and should update its card instead of duplicating it.
    private var lastStatusByStep: [Int: String] = [:]
    /// Sequence assigned on first encounter, reused on updates so the card
    /// keeps its position in the timeline.
    private var stepSequences: [Int: Int64] = [:]
    private var emittedDone = false

    init(runID: UUID) {
        self.runID = runID
    }

    private func nextSeq() -> Int64 {
        sequence += 1
        return sequence
    }

    private func seq(forStep stepIndex: Int) -> Int64 {
        if stepIndex >= 0, let existing = stepSequences[stepIndex] { return existing }
        let next = nextSeq()
        if stepIndex >= 0 { stepSequences[stepIndex] = next }
        return next
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
            var isUpdate = false
            if stepIndex >= 0 {
                let status = obj["status"] as? String ?? "DONE"
                if lastStatusByStep[stepIndex] == status { continue }
                isUpdate = lastStatusByStep[stepIndex] != nil
                lastStatusByStep[stepIndex] = status
            }
            if let delta = parseEntry(obj, stepIndex: stepIndex, isUpdate: isUpdate) {
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

    private func parseEntry(_ obj: [String: Any], stepIndex: Int, isUpdate: Bool) -> TimelineDelta? {
        let type = obj["type"] as? String ?? ""
        let keySuffix = stepIndex >= 0 ? "\(stepIndex)" : "\(nextSeq())"
        let stableKey = "gemini-step-\(runID)-\(keySuffix)"
        let status: TimelineEventStatus = (obj["status"] as? String ?? "DONE") == "RUNNING" ? .working : .success

        switch type {
        case "PLANNER_RESPONSE":
            guard let toolCalls = obj["tool_calls"] as? [[String: Any]],
                  let first = toolCalls.first else { return nil }
            let toolName = first["name"] as? String ?? "tool"
            let args = first["args"] as? [String: Any]
            return toolCallDelta(
                toolName: toolName,
                args: args,
                stableKey: stableKey,
                sequence: seq(forStep: stepIndex),
                status: status,
                isUpdate: isUpdate
            )

        case "ERROR_MESSAGE":
            let content = obj["content"] as? String ?? "Error"
            return .appendProblem(AgentRunProblem(
                stableKey: "gemini-err-\(runID)-\(keySuffix)",
                runID: runID,
                severity: .error,
                message: truncate(content, max: 300),
                source: .structuredHook,
                confidence: .high
            ))

        default:
            // Tool *result* steps (VIEW_FILE, RUN_COMMAND, CODE_ACTION, GREP_SEARCH,
            // LIST_DIRECTORY, …) duplicate the PLANNER_RESPONSE tool_calls that
            // requested them; the tool_call args are richer, so results are skipped.
            return nil
        }
    }

    private func toolCallDelta(
        toolName: String,
        args: [String: Any]?,
        stableKey: String,
        sequence: Int64,
        status: TimelineEventStatus,
        isUpdate: Bool
    ) -> TimelineDelta {
        let filePath = decodedArg(args, "AbsolutePath") ?? decodedArg(args, "TargetFile")
        let cmd = decodedArg(args, "CommandLine")
        let action = decodedArg(args, "toolAction") ?? decodedArg(args, "toolSummary")

        let (type, title, subtitle, relatedFile): (TimelineEventType, String, String?, String?) = {
            switch toolName {
            case "view_file":
                return (.fileChange, "Reading \(fileName(filePath))", filePath, filePath)
            case "write_to_file":
                return (.fileChange, "Writing \(fileName(filePath))", filePath, filePath)
            case "replace_file_content", "multi_replace_file_content":
                return (.fileChange, "Editing \(fileName(filePath))", filePath, filePath)
            case "run_command":
                return (.command, "$ \(truncate(cmd ?? "command"))", nil, nil)
            case "grep_search":
                let query = decodedArg(args, "Query")
                return (.command, "Searching: \(truncate(query ?? "files"))", action, nil)
            case "list_dir":
                return (.command, action ?? "Listing directory", decodedArg(args, "DirectoryPath"), nil)
            case "search_web":
                return (.command, "Web search", decodedArg(args, "query"), nil)
            case "manage_task":
                return (.phase, action ?? "Updating task list", nil, nil)
            default:
                return (.command, action ?? toolName, nil, nil)
            }
        }()

        let event = AgentTimelineEvent(
            stableKey: stableKey,
            runID: runID,
            sequence: sequence,
            type: type,
            title: title,
            subtitle: subtitle,
            status: status,
            source: .structuredHook,
            confidence: .high,
            relatedFile: relatedFile,
            relatedCommand: cmd
        )
        return isUpdate ? .update(stableKey: stableKey, event) : .insert(event)
    }

    /// agy serializes every tool_call arg value as a JSON fragment
    /// (`"\"text\""`, `"5000"`, `"false"`); decode string fragments to plain text.
    private func decodedArg(_ args: [String: Any]?, _ key: String) -> String? {
        guard let raw = args?[key] as? String, !raw.isEmpty else { return nil }
        if raw.hasPrefix("\""), let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded.isEmpty ? nil : decoded
        }
        return raw
    }

    private func fileName(_ path: String?) -> String {
        path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file"
    }

    private func truncate(_ s: String, max: Int = 60) -> String {
        s.count > max ? String(s.prefix(max)) + "…" : s
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
