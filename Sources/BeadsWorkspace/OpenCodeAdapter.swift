import Foundation

/// Adapter for OpenCode's `run --format json` JSONL output.
/// Supports all OpenCode models: Kimi, Zhipu, DeepSeek, MiniMax.
/// Extracts the model flag from commandArgsTemplate (e.g. `-m opencode-go/kimi-k2.5`).
///
/// NOTE: The exact `--format json` schema is not officially documented; the parser
/// below handles the common event shapes and degrades gracefully (unknown lines are
/// ignored, not fatal). Verify against real output and adjust `OpenCodeStreamParser`.
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
        process.standardError = Pipe()

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
                handlerLock.lock()
                var tail: [TimelineDelta] = []
                if let remainder = lineBuffer.flush() {
                    tail = parser.parse(line: remainder)
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
                    stableKey: "opencode-start-\(runID)",
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
    private var pendingTools: [String: AgentTimelineEvent] = [:]
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
            let tool = obj["tool"] as? String ?? "tool"
            let input = obj["input"] as? [String: Any]
            let toolID = obj["id"] as? String ?? UUID().uuidString
            let stableKey = "opencode-tool-\(runID)-\(toolID)"
            let (eventType, title, subtitle, relatedFile) = toolUseMapping(tool: tool, input: input)
            let event = AgentTimelineEvent(
                stableKey: stableKey,
                runID: runID,
                sequence: nextSeq(),
                type: eventType,
                title: title,
                subtitle: subtitle,
                status: .working,
                source: .structuredHook,
                confidence: .high,
                relatedFile: relatedFile
            )
            pendingTools[toolID] = event
            return [.insert(event)]

        case "tool_result":
            let toolID = obj["id"] as? String ?? ""
            let exitCode = obj["exit_code"] as? Int ?? 0
            guard let original = pendingTools.removeValue(forKey: toolID) else { return [] }
            let updated = AgentTimelineEvent(
                id: original.id,
                stableKey: original.stableKey,
                runID: runID,
                sequence: original.sequence,
                type: original.type,
                title: original.title,
                subtitle: original.subtitle,
                timestamp: original.timestamp,
                status: exitCode == 0 ? .success : .failure,
                source: .structuredHook,
                confidence: .high,
                relatedFile: original.relatedFile,
                relatedCommand: original.relatedCommand
            )
            return [.update(stableKey: original.stableKey, updated)]

        case "session_complete":
            return finish(exitCode: 0)

        case "error":
            let msg = obj["message"] as? String ?? "Unknown error"
            return [.appendProblem(AgentRunProblem(
                stableKey: "opencode-err-\(runID)-\(nextSeq())",
                runID: runID,
                severity: .error,
                message: msg,
                source: .structuredHook,
                confidence: .high
            ))]

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
        let filePath = input?["file_path"] as? String ?? input?["path"] as? String
        let command = input?["command"] as? String

        switch tool {
        case "read_file":
            return (.fileChange, "Reading \(fileName(filePath))", filePath, filePath)
        case "write_file", "create_file":
            return (.fileChange, "Writing \(fileName(filePath))", filePath, filePath)
        case "edit_file", "patch_file":
            return (.fileChange, "Editing \(fileName(filePath))", filePath, filePath)
        case "bash", "run_command", "execute":
            let cmd = command ?? "shell command"
            return (.command, "$ \(truncate(cmd))", nil, nil)
        case "list_directory", "glob", "search_files", "grep":
            return (.command, "Searching…", filePath, nil)
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
