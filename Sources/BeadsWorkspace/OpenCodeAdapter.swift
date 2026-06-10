import Foundation

/// Adapter for OpenCode's `run --format json` JSONL output.
/// Supports all OpenCode models: Kimi, Zhipu, DeepSeek, MiniMax.
/// Extracts the model flag from commandArgsTemplate (e.g. `-m opencode-go/kimi-k2.5`).
///
/// Each line is `{"type":..., "timestamp":..., "sessionID":..., ...data}` where data
/// holds a `part` (message part) or `error`. `tool_use` is emitted only once the tool
/// reaches `completed`/`error`, so cards land with a final status (no pending phase).
/// Unknown lines are ignored, not fatal.
public final class OpenCodeAdapter: AgentOutputAdapter, @unchecked Sendable {
    private let commandArgsTemplate: String
    private let lock = NSLock()
    nonisolated(unsafe) private var process: Process?
    nonisolated(unsafe) private var finished = false
    nonisolated(unsafe) private var _lastExitCode: Int32?

    public var lastExitCode: Int32? { lock.withLock { _lastExitCode } }

    public init(commandArgsTemplate: String) {
        self.commandArgsTemplate = commandArgsTemplate
    }

    public func start(runID: UUID, prompt: String, worktreeURL: URL) async throws -> AsyncStream<TimelineDelta> {
        let model = extractModel(from: commandArgsTemplate)
        var args = ["run", "--format", "json"]
        if let model { args += ["-m", model] }
        args.append(prompt)

        let process = AgentProcessEnvironment.makeProcess(
            binary: "opencode",
            arguments: args,
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

        let parser = OpenCodeStreamParser(runID: runID, modelLabel: model ?? "OpenCode")
        let lineBuffer = LineBuffer()
        let handlerLock = NSLock()

        return AsyncStream { continuation in
            // Emit a started event immediately.
            continuation.yield(parser.startedDelta())

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
                        stableKey: "opencode-stderr-\(runID)",
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
                    // Distinct from the started card's key or the store dedups it away.
                    stableKey: "opencode-launchfail-\(runID)",
                    runID: runID,
                    sequence: 1,
                    type: .problem,
                    title: "Failed to launch OpenCode",
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

    private func extractModel(from template: String) -> String? {
        let parts = template.components(separatedBy: " ")
        guard let mIndex = parts.firstIndex(of: "-m"), parts.indices.contains(mIndex + 1) else {
            return nil
        }
        return parts[mIndex + 1]
    }
}

// MARK: - Stream Parser

final class OpenCodeStreamParser: @unchecked Sendable {
    private let runID: UUID
    private let modelLabel: String
    private var sequence: Int64 = 0
    private var emittedDone = false

    init(runID: UUID, modelLabel: String) {
        self.runID = runID
        self.modelLabel = modelLabel
    }

    private func nextSeq() -> Int64 {
        sequence += 1
        return sequence
    }

    func startedDelta() -> TimelineDelta {
        .insert(AgentTimelineEvent(
            stableKey: "opencode-start-\(runID)",
            runID: runID,
            sequence: nextSeq(),
            type: .started,
            title: "\(modelLabel) started",
            status: .working,
            source: .structuredHook,
            confidence: .high
        ))
    }

    func parse(line: String) -> [TimelineDelta] {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let type = obj["type"] as? String ?? ""

        switch type {
        case "tool_use":
            guard let part = obj["part"] as? [String: Any] else { return [] }
            let tool = part["tool"] as? String ?? "tool"
            let state = part["state"] as? [String: Any]
            let input = state?["input"] as? [String: Any]
            let failed = (state?["status"] as? String) == "error"
            let callID = (part["callID"] as? String) ?? (part["id"] as? String) ?? UUID().uuidString
            let stableKey = "opencode-tool-\(runID)-\(callID)"
            let (eventType, title, subtitle, relatedFile) = toolUseMapping(tool: tool, input: input)
            return [.insert(AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: nextSeq(),
                type: eventType,
                title: title,
                subtitle: subtitle,
                status: failed ? .failure : .success,
                source: .structuredHook,
                confidence: .high,
                relatedFile: relatedFile,
                relatedCommand: input?["command"] as? String
            ))]

        case "error":
            let msg: String
            if let error = obj["error"] as? [String: Any] {
                msg = ((error["data"] as? [String: Any])?["message"] as? String)
                    ?? (error["name"] as? String)
                    ?? "Unknown error"
            } else {
                msg = obj["message"] as? String ?? "Unknown error"
            }
            return [.appendProblem(AgentRunProblem(
                stableKey: "opencode-err-\(runID)-\(nextSeq())",
                runID: runID,
                severity: .error,
                message: msg,
                source: .structuredHook,
                confidence: .high
            ))]

        case "step_start", "step_finish", "text", "reasoning":
            return []

        default:
            return []
        }
    }

    func finish(exitCode: Int32) -> [TimelineDelta] {
        guard !emittedDone else { return [] }
        emittedDone = true
        let success = exitCode == 0
        return [.insert(AgentTimelineEvent(
            stableKey: "opencode-done-\(runID)",
            runID: runID,
            sequence: nextSeq(),
            type: .done,
            title: success ? "Done" : "Run failed",
            subtitle: success ? nil : "exit \(exitCode)",
            status: success ? .success : .failure,
            source: .structuredHook,
            confidence: .high
        ))]
    }

    private func toolUseMapping(
        tool: String,
        input: [String: Any]?
    ) -> (TimelineEventType, String, String?, String?) {
        let filePath = input?["filePath"] as? String ?? input?["path"] as? String
        let command = input?["command"] as? String

        switch tool {
        case "read":
            return (.fileChange, "Reading \(fileName(filePath))", filePath, filePath)
        case "write":
            return (.fileChange, "Writing \(fileName(filePath))", filePath, filePath)
        case "edit", "multiedit", "patch":
            return (.fileChange, "Editing \(fileName(filePath))", filePath, filePath)
        case "bash":
            let cmd = command ?? input?["description"] as? String ?? "shell command"
            return (.command, "$ \(truncate(cmd))", nil, nil)
        case "grep", "glob", "list":
            let pattern = input?["pattern"] as? String
            return (.command, "Searching: \(truncate(pattern ?? tool))", filePath, nil)
        case "webfetch":
            return (.command, "Fetching URL", input?["url"] as? String, nil)
        case "todowrite", "todoread":
            return (.phase, "Updating task list", nil, nil)
        default:
            return (.command, tool, nil, nil)
        }
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
