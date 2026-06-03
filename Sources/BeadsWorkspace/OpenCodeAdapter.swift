import Foundation

/// Adapter for OpenCode's `--format json` JSONL output.
/// Supports all OpenCode models: Kimi, Zhipu, DeepSeek, MiniMax, Codex.
/// Extracts the model flag from commandArgsTemplate (e.g. `-m opencode-go/kimi-k2.5`).
public final class OpenCodeAdapter: AgentOutputAdapter, @unchecked Sendable {
    private let commandArgsTemplate: String
    private let lock = NSLock()
    nonisolated(unsafe) private var process: Process?
    nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    public init(commandArgsTemplate: String) {
        self.commandArgsTemplate = commandArgsTemplate
    }

    private func storeProcess(_ proc: Process) { lock.withLock { process = proc } }
    private func storeTask(_ task: Task<Void, Never>) { lock.withLock { streamTask = task } }

    public func start(runID: UUID, prompt: String, worktreeURL: URL) async throws -> AsyncStream<TimelineDelta> {
        let model = extractModel(from: commandArgsTemplate)
        let seq = SequenceCounter()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["opencode", "run", "--format", "json"]
        if let model {
            args += ["-m", model]
        }
        args.append(prompt)
        proc.arguments = args
        proc.currentDirectoryURL = worktreeURL

        let stdoutPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = Pipe()

        try proc.run()
        storeProcess(proc)

        let fileHandle = stdoutPipe.fileHandleForReading
        let modelLabel = model ?? "OpenCode"
        return AsyncStream { continuation in
            let task = Task.detached {
                defer { continuation.finish() }
                // Emit started event
                let startEvent = AgentTimelineEvent(
                    stableKey: "opencode-start-\(runID)",
                    runID: runID,
                    sequence: seq.next(),
                    type: .started,
                    title: "\(modelLabel) started",
                    status: .working,
                    source: .structuredHook,
                    confidence: .high
                )
                continuation.yield(.insert(startEvent))

                var buffer = Data()
                while true {
                    guard !Task.isCancelled else { return }
                    let chunk = fileHandle.availableData
                    if chunk.isEmpty {
                        if !proc.isRunning { break }
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        continue
                    }
                    buffer.append(chunk)
                    while let newlineRange = buffer.range(of: Data([0x0A])) {
                        let lineData = buffer[buffer.startIndex..<newlineRange.lowerBound]
                        buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
                        guard !lineData.isEmpty,
                              let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
                              !line.isEmpty else { continue }
                        if let delta = OpenCodeAdapter.parse(line: line, runID: runID, seq: seq) {
                            continuation.yield(delta)
                        }
                    }
                }

                // Drain remaining
                let remaining = fileHandle.readDataToEndOfFile()
                buffer.append(remaining)
                while let newlineRange = buffer.range(of: Data([0x0A])) {
                    let lineData = buffer[buffer.startIndex..<newlineRange.lowerBound]
                    buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
                    if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
                       !line.isEmpty,
                       let delta = OpenCodeAdapter.parse(line: line, runID: runID, seq: seq) {
                        continuation.yield(delta)
                    }
                }

                let exitCode = proc.terminationStatus
                let doneEvent = AgentTimelineEvent(
                    stableKey: "opencode-done-\(runID)",
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

    // MARK: - Model extraction

    private func extractModel(from template: String) -> String? {
        // Template looks like: "run -m opencode-go/kimi-k2.5 \"{{prompt}}\""
        let parts = template.components(separatedBy: " ")
        guard let mIndex = parts.firstIndex(of: "-m"), parts.indices.contains(mIndex + 1) else {
            return nil
        }
        return parts[mIndex + 1]
    }

    // MARK: - JSON Parsing

    /// OpenCode `--format json` outputs one JSON object per line.
    /// The schema is based on OpenCode's Part[] types.
    private static func parse(line: String, runID: UUID, seq: SequenceCounter) -> TimelineDelta? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // OpenCode event types observed in practice:
        // {"type":"tool_use","tool":"read_file","input":{"file_path":"..."}}
        // {"type":"tool_result","tool":"read_file","output":"...","exit_code":0}
        // {"type":"text","content":"..."}
        // {"type":"session_complete"}
        // {"type":"error","message":"..."}

        let type = obj["type"] as? String ?? ""
        let stableKey: String

        switch type {
        case "tool_use":
            let tool = obj["tool"] as? String ?? "tool"
            let input = obj["input"] as? [String: Any]
            let toolID = obj["id"] as? String ?? UUID().uuidString
            stableKey = "opencode-tool-\(runID)-\(toolID)"
            let (eventType, title, subtitle, relatedFile) = toolUseMapping(tool: tool, input: input)
            let event = AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: seq.next(),
                type: eventType,
                title: title,
                subtitle: subtitle,
                status: .working,
                source: .structuredHook,
                confidence: .high,
                relatedFile: relatedFile
            )
            return .insert(event)

        case "tool_result":
            let tool = obj["tool"] as? String ?? "tool"
            let toolID = obj["id"] as? String ?? ""
            let exitCode = obj["exit_code"] as? Int ?? 0
            stableKey = "opencode-tool-\(runID)-\(toolID)"
            let updatedEvent = AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: seq.next(),
                type: .command,
                title: exitCode == 0 ? "\(tool) done" : "\(tool) failed",
                status: exitCode == 0 ? .success : .failure,
                source: .structuredHook,
                confidence: .high
            )
            return .update(stableKey: stableKey, updatedEvent)

        case "session_complete":
            let event = AgentTimelineEvent(
                stableKey: "opencode-done-\(runID)",
                runID: runID,
                sequence: seq.next(),
                type: .done,
                title: "Done",
                status: .success,
                source: .structuredHook,
                confidence: .high
            )
            return .insert(event)

        case "error":
            let msg = obj["message"] as? String ?? "Unknown error"
            let problem = AgentRunProblem(
                stableKey: "opencode-err-\(runID)-\(seq.next())",
                runID: runID,
                severity: .error,
                message: msg,
                source: .structuredHook,
                confidence: .high
            )
            return .appendProblem(problem)

        default:
            return nil
        }
    }

    private static func toolUseMapping(
        tool: String,
        input: [String: Any]?
    ) -> (TimelineEventType, String, String?, String?) {
        let filePath = input?["file_path"] as? String ?? input?["path"] as? String
        let command = input?["command"] as? String

        switch tool {
        case "read_file":
            let name = filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file"
            return (.fileChange, "Reading \(name)", filePath, filePath)
        case "write_file", "create_file":
            let name = filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file"
            return (.fileChange, "Writing \(name)", filePath, filePath)
        case "edit_file", "patch_file":
            let name = filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file"
            return (.fileChange, "Editing \(name)", filePath, filePath)
        case "bash", "run_command", "execute":
            let cmd = command ?? "shell command"
            let truncated = cmd.count > 60 ? String(cmd.prefix(60)) + "…" : cmd
            return (.command, "$ \(truncated)", nil, nil)
        case "list_directory", "glob", "search_files", "grep":
            return (.command, "Searching…", filePath, nil)
        default:
            return (.command, tool, nil, nil)
        }
    }
}
