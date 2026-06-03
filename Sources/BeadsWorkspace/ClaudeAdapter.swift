import Foundation

/// Adapter for Claude Code's `--output-format stream-json` JSONL output.
public final class ClaudeAdapter: AgentOutputAdapter, @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var process: Process?
    nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    public init() {}

    private func storeProcess(_ proc: Process) {
        lock.withLock { process = proc }
    }

    private func storeTask(_ task: Task<Void, Never>) {
        lock.withLock { streamTask = task }
    }

    public func start(runID: UUID, prompt: String, worktreeURL: URL) async throws -> AsyncStream<TimelineDelta> {
        let seq = SequenceCounter()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [
            "claude",
            "--output-format", "stream-json",
            "--dangerously-skip-permissions",
            prompt
        ]
        proc.currentDirectoryURL = worktreeURL

        let stdoutPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = Pipe()

        try proc.run()
        storeProcess(proc)

        let fileHandle = stdoutPipe.fileHandleForReading
        return AsyncStream { continuation in
            let task: Task<Void, Never> = Task.detached {
                defer { continuation.finish() }
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
                        if let delta = ClaudeAdapter.parse(line: line, runID: runID, seq: seq) {
                            continuation.yield(delta)
                        }
                    }
                }
                // Drain remaining buffer
                let remaining = fileHandle.readDataToEndOfFile()
                buffer.append(remaining)
                while let newlineRange = buffer.range(of: Data([0x0A])) {
                    let lineData = buffer[buffer.startIndex..<newlineRange.lowerBound]
                    buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
                    if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
                       !line.isEmpty,
                       let delta = ClaudeAdapter.parse(line: line, runID: runID, seq: seq) {
                        continuation.yield(delta)
                    }
                }
                // Final done event if not already emitted
                let exitCode = proc.terminationStatus
                if exitCode != 0 {
                    let doneEvent = AgentTimelineEvent(
                        stableKey: "claude-done-\(runID)",
                        runID: runID,
                        sequence: seq.next(),
                        type: .done,
                        title: "Run failed (exit \(exitCode))",
                        status: .failure,
                        source: .structuredHook,
                        confidence: .high
                    )
                    continuation.yield(.insert(doneEvent))
                }
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

    // MARK: - JSON Parsing

    private static func parse(line: String, runID: UUID, seq: SequenceCounter) -> TimelineDelta? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return nil }

        switch type {
        case "system":
            guard (obj["subtype"] as? String) == "init" else { return nil }
            let event = AgentTimelineEvent(
                stableKey: "claude-start-\(runID)",
                runID: runID,
                sequence: seq.next(),
                type: .started,
                title: "Claude Code started",
                status: .working,
                source: .structuredHook,
                confidence: .high
            )
            return .insert(event)

        case "assistant":
            guard let message = obj["message"] as? [String: Any],
                  let contents = message["content"] as? [[String: Any]] else { return nil }
            for content in contents {
                guard let contentType = content["type"] as? String,
                      contentType == "tool_use",
                      let toolName = content["name"] as? String,
                      let toolID = content["id"] as? String else { continue }
                let input = content["input"] as? [String: Any]
                return toolCallDelta(
                    toolName: toolName,
                    toolID: toolID,
                    input: input,
                    runID: runID,
                    seq: seq
                )
            }
            return nil

        case "tool":
            guard let contents = obj["content"] as? [[String: Any]] else { return nil }
            for content in contents {
                guard let contentType = content["type"] as? String,
                      contentType == "tool_result",
                      let toolUseID = content["tool_use_id"] as? String else { continue }
                let isError = content["is_error"] as? Bool ?? false
                let stableKey = "claude-tool-\(runID)-\(toolUseID)"
                // We update whatever event has this stableKey
                let updatedEvent = AgentTimelineEvent(
                    stableKey: stableKey,
                    runID: runID,
                    sequence: seq.next(),
                    type: .command,
                    title: isError ? "Tool failed" : "Tool completed",
                    status: isError ? .failure : .success,
                    source: .structuredHook,
                    confidence: .high
                )
                return .update(stableKey: stableKey, updatedEvent)
            }
            return nil

        case "result":
            let subtype = obj["subtype"] as? String ?? ""
            let isError = obj["is_error"] as? Bool ?? false
            let isSuccess = subtype == "success" && !isError
            let event = AgentTimelineEvent(
                stableKey: "claude-done-\(runID)",
                runID: runID,
                sequence: seq.next(),
                type: .done,
                title: isSuccess ? "Done" : "Run failed",
                status: isSuccess ? .success : .failure,
                source: .structuredHook,
                confidence: .high
            )
            return .insert(event)

        default:
            return nil
        }
    }

    private static func toolCallDelta(
        toolName: String,
        toolID: String,
        input: [String: Any]?,
        runID: UUID,
        seq: SequenceCounter
    ) -> TimelineDelta {
        let stableKey = "claude-tool-\(runID)-\(toolID)"
        let filePath = input?["file_path"] as? String
        let command = input?["command"] as? String
        let description = input?["description"] as? String

        let (eventType, title, subtitle, relatedFile): (TimelineEventType, String, String?, String?) = {
            switch toolName {
            case "Read", "NotebookRead":
                return (.fileChange, "Reading \(filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file")", filePath, filePath)
            case "Write":
                return (.fileChange, "Writing \(filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file")", filePath, filePath)
            case "Edit", "MultiEdit", "NotebookEdit":
                return (.fileChange, "Editing \(filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "file")", filePath, filePath)
            case "Bash":
                let cmd = command ?? description ?? "shell command"
                let truncated = cmd.count > 60 ? String(cmd.prefix(60)) + "…" : cmd
                return (.command, "$ \(truncated)", nil, nil)
            case "Glob", "Grep", "LS":
                return (.command, "Searching: \(toolName)", description, nil)
            case "WebFetch", "WebSearch":
                return (.command, toolName == "WebSearch" ? "Web search" : "Fetching URL", nil, nil)
            case "TodoWrite", "TodoRead":
                return (.phase, "Updating task list", nil, nil)
            default:
                return (.command, toolName, description, nil)
            }
        }()

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
            relatedFile: relatedFile,
            relatedCommand: command
        )
        return .insert(event)
    }
}

// MARK: - Helpers

final class SequenceCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64 = 0
    func next() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
