import Foundation

public final class AgentTimelineIngestor: @unchecked Sendable {
    private let lock = NSLock()
    private let runID: UUID
    
    // Ingestor state
    private var lastProcessedLineSequence: Int64 = 0
    private var activeCommandRun: TimelineCommandRun? = nil
    private var activeApprovalRequest: AgentApprovalRequest? = nil
    private var seenStableKeys = Set<String>()
    private var activePhase: String? = nil
    
    // Parallel verification sets
    private var fileWatcherChanges = Set<String>()
    private var gitStatusChanges = Set<String>()
    
    public init(runID: UUID) {
        self.runID = runID
    }
    
    // MARK: - Parallel Verification & Direct Ingestion
    
    private func normalizePath(_ path: String) -> String {
        var clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("file://") {
            clean = String(clean.dropFirst(7))
        }
        return clean
    }
    
    /// Register a file change detected by a file system watcher.
    public func registerFileWatcherChange(path: String) {
        lock.lock()
        defer { lock.unlock() }
        fileWatcherChanges.insert(normalizePath(path))
    }
    
    /// Register all file changes detected by a git status summary.
    public func registerGitStatusSummary(_ summary: GitStatusSummary) {
        lock.lock()
        defer { lock.unlock() }
        for file in summary.changedFiles {
            gitStatusChanges.insert(normalizePath(file.path))
        }
    }
    
    /// Directly ingest a file watcher change event.
    public func ingestFileWatcherChange(path: String, timestamp: Date = Date()) -> [TimelineDelta] {
        lock.lock()
        defer { lock.unlock() }
        
        let normalized = normalizePath(path)
        fileWatcherChanges.insert(normalized)
        
        let sequence = lastProcessedLineSequence + 1
        lastProcessedLineSequence = sequence
        
        let fileKey = "file-watcher-\(runID)-\(normalized)"
        guard seenStableKeys.insert(fileKey).inserted else { return [] }
        
        let fileEvent = AgentTimelineEvent(
            stableKey: fileKey,
            runID: runID,
            sequence: sequence,
            type: .fileChange,
            title: "File modified",
            subtitle: path,
            timestamp: timestamp,
            status: .info,
            source: .fileWatcher,
            confidence: .high,
            relatedFile: path
        )
        return [.insert(fileEvent)]
    }
    
    /// Directly ingest all file changes from a git status summary.
    public func ingestGitStatusSummary(_ summary: GitStatusSummary, timestamp: Date = Date()) -> [TimelineDelta] {
        lock.lock()
        defer { lock.unlock() }
        
        var deltas: [TimelineDelta] = []
        for file in summary.changedFiles {
            let normalized = normalizePath(file.path)
            gitStatusChanges.insert(normalized)
            
            let sequence = lastProcessedLineSequence + 1
            lastProcessedLineSequence = sequence
            
            let fileKey = "file-git-\(runID)-\(normalized)"
            guard seenStableKeys.insert(fileKey).inserted else { continue }
            
            let fileEvent = AgentTimelineEvent(
                stableKey: fileKey,
                runID: runID,
                sequence: sequence,
                type: .fileChange,
                title: "File modified",
                subtitle: file.path,
                timestamp: timestamp,
                status: .info,
                source: .gitStatus,
                confidence: .high,
                relatedFile: file.path
            )
            deltas.append(.insert(fileEvent))
        }
        return deltas
    }
    
    /// Incremental ingestion of a line of terminal output.
    public func ingest(line: TerminalLine) -> [TimelineDelta] {
        lock.lock()
        defer { lock.unlock() }
        
        guard line.sequence > lastProcessedLineSequence else { return [] }
        lastProcessedLineSequence = line.sequence
        
        var deltas: [TimelineDelta] = []
        let cleanText = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return [] }
        
        // 0. Detect and process structured Workstation JSON Markers
        if cleanText.hasPrefix("::workstation-json::") {
            let jsonString = String(cleanText.dropFirst("::workstation-json::".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let marker = parseWorkstationMarker(jsonString) {
                return processMarker(marker, line: line)
            } else {
                // Malformed marker is ignored by the timeline parser and preserved in Raw Log
                return []
            }
        }
        
        // 1. Process "Started" on the very first sequence
        if line.sequence == 1 {
            let startKey = "start-\(runID)-\(line.sequence)"
            if seenStableKeys.insert(startKey).inserted {
                let startEvent = AgentTimelineEvent(
                    stableKey: startKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .started,
                    title: "Agent Started",
                    subtitle: "Ingestion pipeline initialized",
                    status: .success,
                    source: .commandLifecycle,
                    confidence: .high,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence
                )
                deltas.append(.insert(startEvent))
            }
        }
        
        // 2. Command matching
        if let commandText = matchCommandLine(cleanText) {
            let cmdKey = "cmd-\(runID)-\(line.sequence)"
            let cmdRun = TimelineCommandRun(
                stableKey: cmdKey,
                runID: runID,
                command: commandText,
                startedAt: line.timestamp,
                status: .working
            )
            self.activeCommandRun = cmdRun
            
            let cmdEvent = AgentTimelineEvent(
                stableKey: cmdKey,
                runID: runID,
                sequence: line.sequence,
                type: .command,
                title: "Running command",
                subtitle: commandText,
                status: .working,
                source: .terminalRegex,
                confidence: .high,
                rawExcerpt: cleanText,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence,
                relatedCommand: commandText
            )
            deltas.append(.insert(cmdEvent))
            
            // Complete/update any active approval since the process has advanced
            if activeApprovalRequest != nil {
                activeApprovalRequest = nil
                deltas.append(.updateApproval(nil))
            }
            
            return deltas // Return early since command line is high signal
        }
        
        // 3. Command Exit / Exit code matching
        if cleanText.contains("exit 0") || cleanText.contains("BUILD SUCCEEDED") {
            if let active = activeCommandRun {
                var updated = active
                updated.endedAt = line.timestamp
                updated.exitCode = 0
                updated.status = .success
                
                let cmdKey = active.stableKey
                let successEvent = AgentTimelineEvent(
                    stableKey: cmdKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .command,
                    title: "Command succeeded",
                    subtitle: active.command,
                    status: .success,
                    source: .terminalRegex,
                    confidence: .high,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence,
                    relatedCommand: active.command
                )
                deltas.append(.update(stableKey: cmdKey, successEvent))
                activeCommandRun = nil
                
                // Complete/update any active approval since the process has advanced
                if activeApprovalRequest != nil {
                    activeApprovalRequest = nil
                    deltas.append(.updateApproval(nil))
                }
                
                return deltas // Return early since command completion is high signal
            }
        } else if cleanText.contains("exit ") || cleanText.contains("BUILD FAILED") || cleanText.contains("Command failed") {
            if let active = activeCommandRun {
                var updated = active
                updated.endedAt = line.timestamp
                updated.exitCode = 1
                updated.status = .failure
                
                let cmdKey = active.stableKey
                let failEvent = AgentTimelineEvent(
                    stableKey: cmdKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .command,
                    title: "Command failed",
                    subtitle: active.command,
                    status: .failure,
                    source: .terminalRegex,
                    confidence: .high,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence,
                    relatedCommand: active.command
                )
                deltas.append(.update(stableKey: cmdKey, failEvent))
                activeCommandRun = nil
                
                if activeApprovalRequest != nil {
                    activeApprovalRequest = nil
                    deltas.append(.updateApproval(nil))
                }
                
                return deltas // Return early
            }
        }
        
        // 4. Swift Compiler / General problems matching
        if let problem = parseProblem(cleanText, sequence: line.sequence) {
            let probKey = "prob-\(runID)-\(line.sequence)"
            if seenStableKeys.insert(probKey).inserted {
                let agentProblem = AgentRunProblem(
                    stableKey: probKey,
                    runID: runID,
                    severity: problem.severity,
                    message: problem.message,
                    filePath: problem.file,
                    line: problem.line,
                    column: problem.column,
                    source: .terminalRegex,
                    confidence: .medium,
                    rawLine: line.sequence
                )
                deltas.append(.appendProblem(agentProblem))
                
                let probEvent = AgentTimelineEvent(
                    stableKey: probKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .problem,
                    title: problem.severity == .error ? "Error detected" : "Warning detected",
                    subtitle: problem.message,
                    status: problem.severity == .error ? .failure : .warning,
                    source: .terminalRegex,
                    confidence: .medium,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence,
                    relatedFile: problem.file
                )
                deltas.append(.insert(probEvent))
            }
        }
        
        // 5. Test results matching
        if let testSummary = parseTestSummary(cleanText) {
            let testKey = "test-\(runID)-\(line.sequence)"
            if seenStableKeys.insert(testKey).inserted {
                let testEvent = AgentTimelineEvent(
                    stableKey: testKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .test,
                    title: "Tests executed",
                    subtitle: testSummary.message,
                    status: testSummary.failedCount > 0 ? .failure : .success,
                    source: .terminalRegex,
                    confidence: .high,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence
                )
                deltas.append(.insert(testEvent))
            }
        } else if cleanText.contains("swift test") || cleanText.contains("Test Suite") {
            let testSuiteKey = "test-suite-\(runID)-\(line.sequence)"
            if seenStableKeys.insert(testSuiteKey).inserted {
                let status: TimelineEventStatus = cleanText.contains("failed") ? .failure : (cleanText.contains("passed") ? .success : .working)
                let testEvent = AgentTimelineEvent(
                    stableKey: testSuiteKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .test,
                    title: "Testing activity",
                    subtitle: cleanText,
                    status: status,
                    source: .terminalRegex,
                    confidence: .medium,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence
                )
                deltas.append(.insert(testEvent))
            }
        }
        
        // 6. Build stage matching
        if let buildStage = matchBuildStage(cleanText) {
            let buildKey = "build-\(runID)-\(line.sequence)"
            if seenStableKeys.insert(buildKey).inserted {
                let buildEvent = AgentTimelineEvent(
                    stableKey: buildKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .build,
                    title: "Building Workstation",
                    subtitle: buildStage,
                    status: .working,
                    source: .terminalRegex,
                    confidence: .medium,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence
                )
                deltas.append(.insert(buildEvent))
            }
        }
        
        // 7. File changes matching
        if let fileChange = parseFileChange(cleanText) {
            let fileKey = "file-\(runID)-\(line.sequence)"
            if seenStableKeys.insert(fileKey).inserted {
                let normalized = normalizePath(fileChange)
                let isVerifiedByGit = gitStatusChanges.contains(normalized)
                let isVerifiedByWatcher = fileWatcherChanges.contains(normalized)
                
                let source: TimelineEventSource
                let confidence: TimelineEventConfidence
                
                if isVerifiedByGit {
                    source = .gitStatus
                    confidence = .high
                } else if isVerifiedByWatcher {
                    source = .fileWatcher
                    confidence = .high
                } else {
                    source = .terminalRegex
                    confidence = .low
                }
                
                let fileEvent = AgentTimelineEvent(
                    stableKey: fileKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .fileChange,
                    title: "File modified",
                    subtitle: fileChange,
                    status: .info,
                    source: source,
                    confidence: confidence,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence,
                    relatedFile: fileChange
                )
                deltas.append(.insert(fileEvent))
            }
        }
        
        // 8. Approval prompt matching
        if let approvalPrompt = parseApprovalPrompt(cleanText) {
            let appKey = "approval-\(runID)-\(line.sequence)"
            let promptHash = String(approvalPrompt.hashValue)
            
            // Check if we already have this active prompt or if it is distinct
            if activeApprovalRequest?.promptHash != promptHash {
                let request = AgentApprovalRequest(
                    stableKey: appKey,
                    runID: runID,
                    promptHash: promptHash,
                    prompt: approvalPrompt,
                    proposedInput: "y\r",
                    rejectInput: "n\r",
                    riskLevel: classifyRisk(approvalPrompt),
                    commandPreview: activeCommandRun?.command,
                    state: .active
                )
                activeApprovalRequest = request
                deltas.append(.updateApproval(request))
                
                let approvalEvent = AgentTimelineEvent(
                    stableKey: appKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .needsApproval,
                    title: "Approval required",
                    subtitle: approvalPrompt,
                    status: .warning,
                    source: .terminalRegex,
                    confidence: .high,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence
                )
                deltas.append(.insert(approvalEvent))
            }
        }
        
        // 9. Done completion matching
        if isDoneLine(cleanText) {
            let doneKey = "done-\(runID)-\(line.sequence)"
            if seenStableKeys.insert(doneKey).inserted {
                let doneEvent = AgentTimelineEvent(
                    stableKey: doneKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .done,
                    title: "Agent finished",
                    subtitle: "Session completed successfully",
                    status: .success,
                    source: .terminalRegex,
                    confidence: .high,
                    rawExcerpt: cleanText,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence
                )
                deltas.append(.insert(doneEvent))
                
                if activeApprovalRequest != nil {
                    activeApprovalRequest = nil
                    deltas.append(.updateApproval(nil))
                }
            }
        }
        
        return deltas
    }
    
    // MARK: - Parser Helpers
    
    private func matchCommandLine(_ text: String) -> String? {
        if text.hasPrefix("$ ") {
            return String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        if text.hasPrefix("> ") {
            return String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        
        let execPrefix = "Executing command: "
        if text.hasPrefix(execPrefix) {
            return String(text.dropFirst(execPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        
        let cmdPrefix = "CommandLine: "
        if text.hasPrefix(cmdPrefix) {
            return String(text.dropFirst(cmdPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        
        return nil
    }
    
    private struct ExtractedProblem {
        let severity: ProblemSeverity
        let message: String
        let file: String?
        let line: Int?
        let column: Int?
    }
    
    private func parseProblem(_ text: String, sequence: Int64) -> ExtractedProblem? {
        let lower = text.lowercased()
        
        // 1. Full swift compiler format check (e.g. file.swift:42:17: error: message)
        if let errorRange = text.range(of: ": error:") {
            let message = String(text[errorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let fileAndCoords = String(text[..<errorRange.lowerBound])
            let parts = fileAndCoords.components(separatedBy: ":")
            if parts.count >= 2 {
                let file = parts[0].trimmingCharacters(in: .whitespaces)
                let line = Int(parts[1])
                let col = parts.count >= 3 ? Int(parts[2]) : nil
                return ExtractedProblem(severity: .error, message: message, file: file, line: line, column: col)
            }
        }
        
        if let warnRange = text.range(of: ": warning:") {
            let message = String(text[warnRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let fileAndCoords = String(text[..<warnRange.lowerBound])
            let parts = fileAndCoords.components(separatedBy: ":")
            if parts.count >= 2 {
                let file = parts[0].trimmingCharacters(in: .whitespaces)
                let line = Int(parts[1])
                let col = parts.count >= 3 ? Int(parts[2]) : nil
                return ExtractedProblem(severity: .warning, message: message, file: file, line: line, column: col)
            }
        }
        
        // 2. Simple fallback checks
        if text.hasPrefix("error:") || text.hasPrefix("fatal error:") || lower.contains("permission denied") || lower.contains("no such file") {
            let msg = text.hasPrefix("error:") ? String(text.dropFirst(6)) : (text.hasPrefix("fatal error:") ? String(text.dropFirst(12)) : text)
            return ExtractedProblem(severity: .error, message: msg.trimmingCharacters(in: .whitespaces), file: nil, line: nil, column: nil)
        }
        
        if text.hasPrefix("warning:") {
            let msg = String(text.dropFirst(8))
            return ExtractedProblem(severity: .warning, message: msg.trimmingCharacters(in: .whitespaces), file: nil, line: nil, column: nil)
        }
        
        return nil
    }
    
    private struct TestSummary {
        let message: String
        let passedCount: Int
        let failedCount: Int
    }
    
    private func parseTestSummary(_ text: String) -> TestSummary? {
        let lower = text.lowercased()
        if lower.contains("executed") && lower.contains("tests") && lower.contains("failures") {
            let failed = lower.contains("0 failures") ? 0 : 1
            return TestSummary(message: text, passedCount: 1, failedCount: failed)
        }
        if lower.contains("tests passed") || lower.contains("tests failed") {
            let failed = lower.contains("0 tests failed") || lower.contains("0 failed") ? 0 : 1
            return TestSummary(message: text, passedCount: 1, failedCount: failed)
        }
        return nil
    }
    
    private func matchBuildStage(_ text: String) -> String? {
        if text.hasPrefix("CompileSwift") {
            return "Compiling Swift sources"
        }
        if text.hasPrefix("Ld ") {
            return "Linking binary"
        }
        if text.hasPrefix("CodeSign ") {
            return "Code signing"
        }
        if text.hasPrefix("ProcessInfoPlistFile ") {
            return "Processing Info.plist"
        }
        return nil
    }
    
    private func parseFileChange(_ text: String) -> String? {
        let clean = text.trimmingCharacters(in: .whitespaces)
        if clean.hasPrefix("modified:") {
            return clean.components(separatedBy: "modified:").last?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let createdPrefix = "Created file file://"
        if clean.hasPrefix(createdPrefix) {
            return clean.components(separatedBy: "file://").last?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let changesPrefix = "Changes made to: "
        if clean.hasPrefix(changesPrefix) {
            return String(clean.dropFirst(changesPrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func parseApprovalPrompt(_ text: String) -> String? {
        let lower = text.lowercased()
        
        let containsPromptFormat = text.contains("[y/N]") || text.contains("[Y/n]") || text.contains("(y/n)") || text.contains("[y/n]")
        let containsQuestionKeywords = lower.contains("do you want to continue") || lower.contains("confirm?") || lower.contains("proceed?") || lower.contains("allow?") || lower.contains("setuju?") || lower.contains("lanjutkan?") || lower.contains("persetujuan")
        
        if containsPromptFormat || containsQuestionKeywords {
            return text
        }
        return nil
    }
    
    private func classifyRisk(_ prompt: String) -> ApprovalRiskLevel {
        let lower = prompt.lowercased()
        if lower.contains("rm -rf") || lower.contains("delete") || lower.contains("erase") || lower.contains("force") || lower.contains("critical") {
            return .critical
        }
        if lower.contains("write") || lower.contains("modify") || lower.contains("change") || lower.contains("high") {
            return .high
        }
        if lower.contains("run") || lower.contains("execute") || lower.contains("medium") {
            return .medium
        }
        return .low
    }
    
    private func isDoneLine(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("completed the session") || lower.contains("closed workstation-")
    }
    
    // MARK: - Workstation JSON Annotation Markers
    
    public struct WorkstationMarker: Codable, Sendable {
        public let type: String
        public let title: String?
        public let command: String?
        public let cwd: String?
        public let exitCode: Int32?
        public let file: String?
        public let line: Int?
        public let column: Int?
        public let message: String?
        public let severity: String?
        public let prompt: String?
        public let proposedInput: String?
        public let rejectInput: String?
        public let riskLevel: String?
        public let totalCount: Int?
        public let commandPreview: String?
        public let fallbackInstruction: String?
        public let denialBehavior: String?
        
        public init(
            type: String,
            title: String? = nil,
            command: String? = nil,
            cwd: String? = nil,
            exitCode: Int32? = nil,
            file: String? = nil,
            line: Int? = nil,
            column: Int? = nil,
            message: String? = nil,
            severity: String? = nil,
            prompt: String? = nil,
            proposedInput: String? = nil,
            rejectInput: String? = nil,
            riskLevel: String? = nil,
            totalCount: Int? = nil,
            commandPreview: String? = nil,
            fallbackInstruction: String? = nil,
            denialBehavior: String? = nil
        ) {
            self.type = type
            self.title = title
            self.command = command
            self.cwd = cwd
            self.exitCode = exitCode
            self.file = file
            self.line = line
            self.column = column
            self.message = message
            self.severity = severity
            self.prompt = prompt
            self.proposedInput = proposedInput
            self.rejectInput = rejectInput
            self.riskLevel = riskLevel
            self.totalCount = totalCount
            self.commandPreview = commandPreview
            self.fallbackInstruction = fallbackInstruction
            self.denialBehavior = denialBehavior
        }
    }
    
    private func parseWorkstationMarker(_ jsonString: String) -> WorkstationMarker? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        // Defensive size limit (8KB)
        guard data.count <= 8192 else { return nil }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(WorkstationMarker.self, from: data)
        } catch {
            return nil
        }
    }
    
    private func processMarker(_ marker: WorkstationMarker, line: TerminalLine) -> [TimelineDelta] {
        var deltas: [TimelineDelta] = []
        let type = marker.type
        
        switch type {
        case "group":
            let phaseTitle = marker.title ?? "Phase"
            let groupKey = "group-\(runID)-\(phaseTitle)"
            self.activePhase = phaseTitle
            
            let phaseEvent = AgentTimelineEvent(
                stableKey: groupKey,
                runID: runID,
                sequence: line.sequence,
                type: .phase,
                title: phaseTitle,
                status: .working,
                source: .workstationMarker,
                confidence: .high,
                rawExcerpt: line.text,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence
            )
            deltas.append(.insert(phaseEvent))
            
        case "endgroup":
            let phaseTitle = marker.title ?? self.activePhase ?? "Phase"
            let groupKey = "group-\(runID)-\(phaseTitle)"
            
            let successEvent = AgentTimelineEvent(
                stableKey: groupKey,
                runID: runID,
                sequence: line.sequence,
                type: .phase,
                title: phaseTitle,
                status: .success,
                source: .workstationMarker,
                confidence: .high,
                rawExcerpt: line.text,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence
            )
            deltas.append(.update(stableKey: groupKey, successEvent))
            if self.activePhase == phaseTitle {
                self.activePhase = nil
            }
            
        case "command":
            let cmdText = marker.command ?? ""
            let cmdKey = "cmd-\(runID)-\(line.sequence)"
            let cmdRun = TimelineCommandRun(
                stableKey: cmdKey,
                runID: runID,
                command: cmdText,
                workingDirectory: marker.cwd,
                startedAt: line.timestamp,
                status: .working
            )
            self.activeCommandRun = cmdRun
            
            let cmdEvent = AgentTimelineEvent(
                stableKey: cmdKey,
                runID: runID,
                sequence: line.sequence,
                type: .command,
                title: "Running command",
                subtitle: cmdText,
                status: .working,
                source: .workstationMarker,
                confidence: .high,
                rawExcerpt: line.text,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence,
                relatedCommand: cmdText
            )
            deltas.append(.insert(cmdEvent))
            
            if activeApprovalRequest != nil {
                activeApprovalRequest = nil
                deltas.append(.updateApproval(nil))
            }
            
        case "commandEnd":
            let exitCode = marker.exitCode ?? 0
            if let active = activeCommandRun {
                var updated = active
                updated.endedAt = line.timestamp
                updated.exitCode = exitCode
                updated.status = exitCode == 0 ? .success : .failure
                
                let cmdKey = active.stableKey
                let cmdEvent = AgentTimelineEvent(
                    stableKey: cmdKey,
                    runID: runID,
                    sequence: line.sequence,
                    type: .command,
                    title: exitCode == 0 ? "Command succeeded" : "Command failed",
                    subtitle: active.command,
                    status: exitCode == 0 ? .success : .failure,
                    source: .workstationMarker,
                    confidence: .high,
                    rawExcerpt: line.text,
                    rawLineStart: line.sequence,
                    rawLineEnd: line.sequence,
                    relatedCommand: active.command
                )
                deltas.append(.update(stableKey: cmdKey, cmdEvent))
                activeCommandRun = nil
            }
            
        case "fileChanged":
            let file = marker.file ?? ""
            let fileKey = "file-\(runID)-\(line.sequence)"
            let fileEvent = AgentTimelineEvent(
                stableKey: fileKey,
                runID: runID,
                sequence: line.sequence,
                type: .fileChange,
                title: "File modified",
                subtitle: file,
                status: .info,
                source: .workstationMarker,
                confidence: .high,
                rawExcerpt: line.text,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence,
                relatedFile: file
            )
            deltas.append(.insert(fileEvent))
            
        case "problem":
            let severity: ProblemSeverity = {
                switch marker.severity ?? "" {
                case "warning": return .warning
                case "notice": return .notice
                default: return .error
                }
            }()
            let message = marker.message ?? ""
            let probKey = "prob-\(runID)-\(line.sequence)"
            
            let problem = AgentRunProblem(
                stableKey: probKey,
                runID: runID,
                severity: severity,
                message: message,
                filePath: marker.file,
                line: marker.line,
                column: marker.column,
                source: .workstationMarker,
                confidence: .high,
                rawLine: line.sequence
            )
            deltas.append(.appendProblem(problem))
            
            let probEvent = AgentTimelineEvent(
                stableKey: probKey,
                runID: runID,
                sequence: line.sequence,
                type: .problem,
                title: severity == .error ? "Error detected" : "Warning detected",
                subtitle: message,
                status: severity == .error ? .failure : .warning,
                source: .workstationMarker,
                confidence: .high,
                rawExcerpt: line.text,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence,
                relatedFile: marker.file
            )
            deltas.append(.insert(probEvent))
            
        case "approval":
            let prompt = marker.prompt ?? ""
            let proposed = (marker.proposedInput ?? "y\r").replacingOccurrences(of: "\n", with: "\r")
            let reject = (marker.rejectInput ?? "n\r").replacingOccurrences(of: "\n", with: "\r")
            let risk: ApprovalRiskLevel = {
                switch marker.riskLevel ?? "" {
                case "critical": return .critical
                case "high": return .high
                case "medium": return .medium
                default: return .low
                }
            }()
            let denial: DenialBehavior = {
                switch marker.denialBehavior ?? "" {
                case "continueWithFallback": return .continueWithFallback
                case "askForAlternative": return .askForAlternative
                default: return .stopRun
                }
            }()
            let appKey = "approval-\(runID)-\(line.sequence)"
            let promptHash = String(prompt.hashValue)
            
            let request = AgentApprovalRequest(
                stableKey: appKey,
                runID: runID,
                promptHash: promptHash,
                prompt: prompt,
                proposedInput: proposed,
                rejectInput: reject,
                riskLevel: risk,
                commandPreview: marker.commandPreview,
                fallbackInstruction: marker.fallbackInstruction,
                denialBehavior: denial,
                state: .active
            )
            activeApprovalRequest = request
            deltas.append(.updateApproval(request))
            
            let approvalEvent = AgentTimelineEvent(
                stableKey: appKey,
                runID: runID,
                sequence: line.sequence,
                type: .needsApproval,
                title: "Approval required",
                subtitle: prompt,
                status: .warning,
                source: .workstationMarker,
                confidence: .high,
                rawExcerpt: line.text,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence
            )
            deltas.append(.insert(approvalEvent))
            
        case "testSummary":
            let message = marker.message ?? "Tests executed"
            let status: TimelineEventStatus = (marker.exitCode ?? 0) == 0 ? .success : .failure
            let testKey = "test-\(runID)-\(line.sequence)"
            
            let testEvent = AgentTimelineEvent(
                stableKey: testKey,
                runID: runID,
                sequence: line.sequence,
                type: .test,
                title: "Tests executed",
                subtitle: message,
                status: status,
                source: .workstationMarker,
                confidence: .high,
                rawExcerpt: line.text,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence
            )
            deltas.append(.insert(testEvent))
            
        case "done":
            let message = marker.message ?? "Agent completed the session"
            let doneKey = "done-\(runID)-\(line.sequence)"
            
            let doneEvent = AgentTimelineEvent(
                stableKey: doneKey,
                runID: runID,
                sequence: line.sequence,
                type: .done,
                title: "Agent finished",
                subtitle: message,
                status: .success,
                source: .workstationMarker,
                confidence: .high,
                rawExcerpt: line.text,
                rawLineStart: line.sequence,
                rawLineEnd: line.sequence
            )
            deltas.append(.insert(doneEvent))
            
            if activeApprovalRequest != nil {
                activeApprovalRequest = nil
                deltas.append(.updateApproval(nil))
            }
            
        default:
            break
        }
        
        return deltas
    }
}
