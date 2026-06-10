import Foundation

/// Adapter for Claude Code's `--output-format stream-json` JSONL output.
public final class ClaudeAdapter: AgentOutputAdapter, @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var process: Process?
    nonisolated(unsafe) private var finished = false
    nonisolated(unsafe) private var _lastExitCode: Int32?

    public var lastExitCode: Int32? { lock.withLock { _lastExitCode } }

    public init() {}

    public func start(runID: UUID, prompt: String, worktreeURL: URL) async throws -> AsyncStream<TimelineDelta> {
        let process = AgentProcessEnvironment.makeProcess(
            binary: "claude",
            arguments: [
                // --output-format only works in --print (non-interactive) mode.
                "--print", prompt,
                "--output-format", "stream-json",
                "--verbose",
                "--dangerously-skip-permissions"
            ],
            workingDirectory: worktreeURL
        )

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardInput = FileHandle.nullDevice

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        let stderrTail = CappedDataBuffer()
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrTail.append(data)
        }

        let parser = ClaudeStreamParser(runID: runID)
        let lineBuffer = LineBuffer()
        let handlerLock = NSLock()

        return AsyncStream { continuation in
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                handlerLock.lock()
                let lines = lineBuffer.append(data)
                let deltas = lines.flatMap { parser.parse(line: $0) }
                handlerLock.unlock()
                for delta in deltas { continuation.yield(delta) }
            }

            process.terminationHandler = { proc in
                self.lock.withLock { self._lastExitCode = proc.terminationStatus }
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                handlerLock.lock()
                var tail: [TimelineDelta] = []
                if let remainder = lineBuffer.flush() {
                    tail = parser.parse(line: remainder)
                }
                if proc.terminationStatus != 0, let stderrText = stderrTail.text {
                    tail.append(.appendProblem(AgentRunProblem(
                        stableKey: "claude-stderr-\(runID)",
                        runID: runID,
                        severity: .error,
                        message: stderrText,
                        source: .structuredHook,
                        confidence: .high
                    )))
                }
                tail.append(contentsOf: parser.finish(exitCode: proc.terminationStatus))
                handlerLock.unlock()
                for delta in tail { continuation.yield(delta) }
                continuation.finish()
            }

            do {
                try process.run()
            } catch {
                continuation.yield(.insert(AgentTimelineEvent(
                    stableKey: "claude-start-\(runID)",
                    runID: runID,
                    sequence: 1,
                    type: .problem,
                    title: "Failed to launch Claude",
                    subtitle: error.localizedDescription,
                    status: .failure,
                    source: .structuredHook,
                    confidence: .high
                )))
                continuation.finish()
                return
            }

            self.lock.withLock { self.process = process }
            continuation.onTermination = { [weak self] _ in
                self?.terminateProcess()
            }
        }
    }

    public func kill() {
        terminateProcess()
    }

    private func terminateProcess() {
        let proc = lock.withLock { () -> Process? in
            guard !finished else { return nil }
            finished = true
            return process
        }
        proc?.interrupt()
    }
}

// MARK: - Stream Parser

/// Parses Claude `stream-json` lines, tracking in-flight tool calls so completion
/// events preserve the original card title/file rather than clobbering them.
/// Access is serialized by the adapter's handlerLock.
final class ClaudeStreamParser: @unchecked Sendable {
    private let runID: UUID
    private var sequence: Int64 = 0
    private var pendingTools: [String: AgentTimelineEvent] = [:]
    private var emittedDone = false

    init(runID: UUID) {
        self.runID = runID
    }

    private func nextSeq() -> Int64 {
        sequence += 1
        return sequence
    }

    func parse(line: String) -> [TimelineDelta] {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return [] }

        switch type {
        case "system":
            guard (obj["subtype"] as? String) == "init" else { return [] }
            return [.insert(AgentTimelineEvent(
                stableKey: "claude-start-\(runID)",
                runID: runID,
                sequence: nextSeq(),
                type: .started,
                title: "Claude Code started",
                status: .working,
                source: .structuredHook,
                confidence: .high
            ))]

        case "assistant":
            guard let message = obj["message"] as? [String: Any],
                  let contents = message["content"] as? [[String: Any]] else { return [] }
            var deltas: [TimelineDelta] = []
            for content in contents {
                guard let contentType = content["type"] as? String,
                      contentType == "tool_use",
                      let toolName = content["name"] as? String,
                      let toolID = content["id"] as? String else { continue }
                let input = content["input"] as? [String: Any]
                let event = toolCallEvent(toolName: toolName, toolID: toolID, input: input)
                pendingTools[toolID] = event
                deltas.append(.insert(event))
            }
            return deltas

        case "user", "tool":
            // Tool results arrive as a user turn with tool_result content blocks.
            let contents: [[String: Any]]
            if let message = obj["message"] as? [String: Any],
               let c = message["content"] as? [[String: Any]] {
                contents = c
            } else if let c = obj["content"] as? [[String: Any]] {
                contents = c
            } else {
                return []
            }
            var deltas: [TimelineDelta] = []
            for content in contents {
                guard (content["type"] as? String) == "tool_result",
                      let toolUseID = content["tool_use_id"] as? String else { continue }
                let isError = content["is_error"] as? Bool ?? false
                if let original = pendingTools.removeValue(forKey: toolUseID) {
                    // Preserve the original card; only flip status.
                    let updated = AgentTimelineEvent(
                        id: original.id,
                        stableKey: original.stableKey,
                        runID: runID,
                        sequence: original.sequence,
                        type: original.type,
                        title: original.title,
                        subtitle: original.subtitle,
                        timestamp: original.timestamp,
                        status: isError ? .failure : .success,
                        source: .structuredHook,
                        confidence: .high,
                        relatedFile: original.relatedFile,
                        relatedCommand: original.relatedCommand
                    )
                    deltas.append(.update(stableKey: original.stableKey, updated))
                }
            }
            return deltas

        case "result":
            // On error the `result` field carries the reason (e.g. "Failed to
            // authenticate. API Error: 401 …"); surface it on the failure card.
            let isError = obj["is_error"] as? Bool ?? false
            let detail = isError ? obj["result"] as? String : nil
            return finish(exitCode: isError ? 1 : 0, detail: detail)

        default:
            return []
        }
    }

    func finish(exitCode: Int32, detail: String? = nil) -> [TimelineDelta] {
        guard !emittedDone else { return [] }
        emittedDone = true
        let success = exitCode == 0
        let failureSubtitle = detail.map { truncate($0, max: 160) } ?? "exit \(exitCode)"
        return [.insert(AgentTimelineEvent(
            stableKey: "claude-done-\(runID)",
            runID: runID,
            sequence: nextSeq(),
            type: .done,
            title: success ? "Done" : "Run failed",
            subtitle: success ? nil : failureSubtitle,
            status: success ? .success : .failure,
            source: .structuredHook,
            confidence: .high
        ))]
    }

    private func toolCallEvent(toolName: String, toolID: String, input: [String: Any]?) -> AgentTimelineEvent {
        let stableKey = "claude-tool-\(runID)-\(toolID)"
        let filePath = input?["file_path"] as? String
        let command = input?["command"] as? String
        let description = input?["description"] as? String

        let (eventType, title, subtitle, relatedFile): (TimelineEventType, String, String?, String?) = {
            switch toolName {
            case "Read", "NotebookRead":
                return (.fileChange, "Reading \(fileName(filePath))", filePath, filePath)
            case "Write":
                return (.fileChange, "Writing \(fileName(filePath))", filePath, filePath)
            case "Edit", "MultiEdit", "NotebookEdit":
                return (.fileChange, "Editing \(fileName(filePath))", filePath, filePath)
            case "Bash":
                let cmd = command ?? description ?? "shell command"
                return (.command, "$ \(truncate(cmd))", nil, nil)
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

        return AgentTimelineEvent(
            stableKey: stableKey,
            runID: runID,
            sequence: nextSeq(),
            type: eventType,
            title: title,
            subtitle: subtitle,
            status: .working,
            source: .structuredHook,
            confidence: .high,
            relatedFile: relatedFile,
            relatedCommand: command
        )
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
