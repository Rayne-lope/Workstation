import Foundation

/// Adapter for Google Gemini CLI (`agy`).
/// Since `agy` doesn't have structured stdout, this adapter:
/// 1. Spawns `agy --dangerously-skip-permissions "<prompt>"`
/// 2. Detects the newly created session dir under `~/.gemini/antigravity-cli/brain/`
/// 3. Tails `transcript.jsonl` via a polling file watcher
/// 4. Maps each JSONL entry to a TimelineDelta
public final class GeminiAdapter: AgentOutputAdapter, @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var process: Process?
    nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    private static let brainDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".gemini/antigravity-cli/brain")

    public init() {}

    private func storeProcess(_ proc: Process) { lock.withLock { process = proc } }
    private func storeTask(_ task: Task<Void, Never>) { lock.withLock { streamTask = task } }

    public func start(runID: UUID, prompt: String, worktreeURL: URL) async throws -> AsyncStream<TimelineDelta> {
        let seq = SequenceCounter()
        let existingSessionDirs = Set((try? snapshotBrainDir()) ?? [])

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["agy", "--dangerously-skip-permissions", prompt]
        proc.currentDirectoryURL = worktreeURL
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()

        try proc.run()
        storeProcess(proc)

        return AsyncStream { continuation in
            let task = Task.detached {
                defer { continuation.finish() }

                // Emit started event
                let startEvent = AgentTimelineEvent(
                    stableKey: "gemini-start-\(runID)",
                    runID: runID,
                    sequence: seq.next(),
                    type: .started,
                    title: "Gemini started",
                    status: .working,
                    source: .structuredHook,
                    confidence: .high
                )
                continuation.yield(.insert(startEvent))

                // Wait up to 5s for the session directory to appear
                var sessionDir: URL?
                for _ in 0..<100 {
                    guard !Task.isCancelled else { return }
                    if let newDir = try? self.detectNewSessionDir(excluding: existingSessionDirs) {
                        sessionDir = newDir
                        break
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }

                guard let transcriptURL = sessionDir?.appendingPathComponent("transcript.jsonl") else {
                    // Can't find session dir — wait for process to finish and emit done
                    proc.waitUntilExit()
                    let exitCode = proc.terminationStatus
                    let doneEvent = AgentTimelineEvent(
                        stableKey: "gemini-done-\(runID)",
                        runID: runID,
                        sequence: seq.next(),
                        type: .done,
                        title: exitCode == 0 ? "Done" : "Run failed",
                        status: exitCode == 0 ? .success : .failure,
                        source: .structuredHook,
                        confidence: .low
                    )
                    continuation.yield(.insert(doneEvent))
                    return
                }

                // Tail transcript.jsonl while process runs
                var byteOffset: Int = 0
                var seenStepIndices = Set<Int>()

                while proc.isRunning || byteOffset < (try? transcriptURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 {
                    guard !Task.isCancelled else { return }
                    if let newDeltas = GeminiAdapter.readNewEntries(
                        from: transcriptURL,
                        byteOffset: &byteOffset,
                        seenStepIndices: &seenStepIndices,
                        runID: runID,
                        seq: seq
                    ) {
                        for delta in newDeltas {
                            continuation.yield(delta)
                        }
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }

                // Final drain
                _ = GeminiAdapter.readNewEntries(
                    from: transcriptURL,
                    byteOffset: &byteOffset,
                    seenStepIndices: &seenStepIndices,
                    runID: runID,
                    seq: seq
                )?.forEach { continuation.yield($0) }

                let exitCode = proc.terminationStatus
                let doneEvent = AgentTimelineEvent(
                    stableKey: "gemini-done-\(runID)",
                    runID: runID,
                    sequence: seq.next(),
                    type: .done,
                    title: exitCode == 0 ? "Done" : "Run failed (exit \(exitCode))",
                    status: exitCode == 0 ? .success : .failure,
                    source: .structuredHook,
                    confidence: .high
                )
                continuation.yield(.insert(doneEvent))
            }
            self.storeTask(task)
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func kill() {
        let (proc, task) = lock.withLock { (process, streamTask) }
        task?.cancel()
        proc?.interrupt()
    }

    // MARK: - Session Dir Detection

    private func snapshotBrainDir() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: Self.brainDir.path)
    }

    private func detectNewSessionDir(excluding existing: Set<String>) throws -> URL? {
        let current = try FileManager.default.contentsOfDirectory(atPath: Self.brainDir.path)
        let newDirs = current.filter { !existing.contains($0) }
        guard let newest = newDirs.sorted().last else { return nil }
        return Self.brainDir.appendingPathComponent(newest)
    }

    // MARK: - Transcript Parsing

    private static func readNewEntries(
        from url: URL,
        byteOffset: inout Int,
        seenStepIndices: inout Set<Int>,
        runID: UUID,
        seq: SequenceCounter
    ) -> [TimelineDelta]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        handle.seek(toFileOffset: UInt64(byteOffset))
        let newData = handle.readDataToEndOfFile()
        guard !newData.isEmpty else { return nil }
        byteOffset += newData.count

        guard let text = String(data: newData, encoding: .utf8) else { return nil }
        var deltas: [TimelineDelta] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
            let stepIndex = obj["step_index"] as? Int ?? -1
            if stepIndex >= 0 && seenStepIndices.contains(stepIndex) { continue }
            if stepIndex >= 0 { seenStepIndices.insert(stepIndex) }
            if let delta = parseEntry(obj, runID: runID, seq: seq) {
                deltas.append(delta)
            }
        }
        return deltas.isEmpty ? nil : deltas
    }

    private static func parseEntry(_ obj: [String: Any], runID: UUID, seq: SequenceCounter) -> TimelineDelta? {
        let type = obj["type"] as? String ?? ""
        let stepIndex = obj["step_index"] as? Int ?? Int(seq.next())
        let stableKey = "gemini-step-\(runID)-\(stepIndex)"

        switch type {
        case "PLANNER_RESPONSE":
            guard let toolCalls = obj["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty else { return nil }
            let toolName = toolCalls.first?["name"] as? String ?? "tool"
            let args = toolCalls.first?["args"] as? [String: Any]
            return toolCallDelta(toolName: toolName, args: args, stableKey: stableKey, runID: runID, seq: seq)

        case "READ_FILE", "WRITE_FILE", "EDIT_FILE", "REPLACE_IN_FILE":
            let args = obj["tool_calls"] as? [[String: Any]],
                filePath = (args?.first?["args"] as? [String: Any])?["file_path"] as? String
                    ?? (args?.first?["args"] as? [String: Any])?["FilePath"] as? String
            let isWrite = type != "READ_FILE"
            let name = filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file"
            let event = AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: seq.next(),
                type: .fileChange,
                title: isWrite ? "Writing \(name)" : "Reading \(name)",
                subtitle: filePath,
                status: .success,
                source: .structuredHook,
                confidence: .high,
                relatedFile: filePath
            )
            return .insert(event)

        case "LIST_DIRECTORY", "GLOB_SEARCH", "GREP_SEARCH", "SEARCH":
            let event = AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: seq.next(),
                type: .command,
                title: "Searching…",
                status: .success,
                source: .structuredHook,
                confidence: .high
            )
            return .insert(event)

        case "RUN_COMMAND", "RUN_BASH", "BASH":
            let args = obj["tool_calls"] as? [[String: Any]]
            let cmd = (args?.first?["args"] as? [String: Any])?["command"] as? String ?? "command"
            let truncated = cmd.count > 60 ? String(cmd.prefix(60)) + "…" : cmd
            let event = AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: seq.next(),
                type: .command,
                title: "$ \(truncated)",
                status: .success,
                source: .structuredHook,
                confidence: .high,
                relatedCommand: cmd
            )
            return .insert(event)

        case "FINAL_ANSWER", "FINAL_RESPONSE":
            // Done event is emitted separately when process exits
            return nil

        case "ERROR":
            let content = obj["content"] as? String ?? "Error"
            let problem = AgentRunProblem(
                stableKey: "gemini-err-\(runID)-\(stepIndex)",
                runID: runID,
                severity: .error,
                message: content,
                source: .structuredHook,
                confidence: .high
            )
            return .appendProblem(problem)

        default:
            return nil
        }
    }

    private static func toolCallDelta(
        toolName: String,
        args: [String: Any]?,
        stableKey: String,
        runID: UUID,
        seq: SequenceCounter
    ) -> TimelineDelta {
        let filePath = (args?["file_path"] as? String) ?? (args?["FilePath"] as? String)
        let cmd = args?["command"] as? String

        let (type, title, subtitle, relatedFile): (TimelineEventType, String, String?, String?) = {
            switch toolName.lowercased() {
            case "read_file":
                let name = filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file"
                return (.fileChange, "Reading \(name)", filePath, filePath)
            case "write_file", "create_file", "edit_file":
                let name = filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file"
                return (.fileChange, "Editing \(name)", filePath, filePath)
            case "run_command", "bash":
                let c = cmd ?? "command"
                return (.command, "$ \(String(c.prefix(60)))", nil, nil)
            case "list_dir", "list_directory", "glob_search", "grep_search":
                return (.command, "Searching…", nil, nil)
            default:
                return (.command, toolName, nil, nil)
            }
        }()

        let event = AgentTimelineEvent(
            stableKey: stableKey,
            runID: runID,
            sequence: seq.next(),
            type: type,
            title: title,
            subtitle: subtitle,
            status: .working,
            source: .structuredHook,
            confidence: .high,
            relatedFile: relatedFile,
            relatedCommand: cmd
        )
        return .insert(event)
    }
}
