import Foundation

public enum TimelineEventType: String, Codable, Sendable {
    case started
    case phase
    case command
    case commandOutput
    case fileChange
    case build
    case test
    case problem
    case needsApproval
    case approvalResolved
    case paused
    case cancelled
    case done
}

public enum TimelineEventStatus: String, Codable, Sendable {
    case queued
    case working
    case success
    case warning
    case failure
    case info
    case stale
}

public enum TimelineEventSource: String, Codable, Sendable {
    case structuredHook
    case workstationMarker
    case commandLifecycle
    case fileWatcher
    case gitStatus
    case terminalRegex
    case heuristic
}

public enum TimelineEventConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
}

public enum ApprovalRiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical
}

public enum DenialBehavior: String, Codable, Sendable {
    case continueWithFallback
    case askForAlternative
    case stopRun
}

public enum ApprovalState: String, Codable, Sendable {
    case active
    case responding
    case accepted
    case rejected
    case expired
    case stale
    case failedToSend
}

public struct TerminalLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let runID: UUID
    public let sequence: Int64
    public let text: String
    public let timestamp: Date
    public let rawByteRangeStart: Int?
    public let rawByteRangeEnd: Int?

    public init(
        id: UUID = UUID(),
        runID: UUID,
        sequence: Int64,
        text: String,
        timestamp: Date = Date(),
        rawByteRangeStart: Int? = nil,
        rawByteRangeEnd: Int? = nil
    ) {
        self.id = id
        self.runID = runID
        self.sequence = sequence
        self.text = text
        self.timestamp = timestamp
        self.rawByteRangeStart = rawByteRangeStart
        self.rawByteRangeEnd = rawByteRangeEnd
    }
}

public struct AgentTimelineEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stableKey: String
    public let runID: UUID
    public let sequence: Int64
    public let type: TimelineEventType
    public let title: String
    public let subtitle: String?
    public let timestamp: Date
    public var status: TimelineEventStatus
    public let source: TimelineEventSource
    public let confidence: TimelineEventConfidence
    public var rawExcerpt: String?
    public var rawLineStart: Int64?
    public var rawLineEnd: Int64?
    public var relatedFile: String?
    public var relatedCommand: String?

    public init(
        id: UUID = UUID(),
        stableKey: String,
        runID: UUID,
        sequence: Int64,
        type: TimelineEventType,
        title: String,
        subtitle: String? = nil,
        timestamp: Date = Date(),
        status: TimelineEventStatus,
        source: TimelineEventSource,
        confidence: TimelineEventConfidence,
        rawExcerpt: String? = nil,
        rawLineStart: Int64? = nil,
        rawLineEnd: Int64? = nil,
        relatedFile: String? = nil,
        relatedCommand: String? = nil
    ) {
        self.id = id
        self.stableKey = stableKey
        self.runID = runID
        self.sequence = sequence
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.timestamp = timestamp
        self.status = status
        self.source = source
        self.confidence = confidence
        self.rawExcerpt = rawExcerpt
        self.rawLineStart = rawLineStart
        self.rawLineEnd = rawLineEnd
        self.relatedFile = relatedFile
        self.relatedCommand = relatedCommand
    }
}

public struct TimelineCommandRun: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stableKey: String
    public let runID: UUID
    public let command: String
    public let workingDirectory: String?
    public let startedAt: Date
    public var endedAt: Date?
    public var exitCode: Int32?
    public var outputPreview: String?
    public var outputLineCount: Int
    public var status: TimelineEventStatus

    public init(
        id: UUID = UUID(),
        stableKey: String,
        runID: UUID,
        command: String,
        workingDirectory: String? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        exitCode: Int32? = nil,
        outputPreview: String? = nil,
        outputLineCount: Int = 0,
        status: TimelineEventStatus = .queued
    ) {
        self.id = id
        self.stableKey = stableKey
        self.runID = runID
        self.command = command
        self.workingDirectory = workingDirectory
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exitCode = exitCode
        self.outputPreview = outputPreview
        self.outputLineCount = outputLineCount
        self.status = status
    }
}

public struct AgentRunProblem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stableKey: String
    public let runID: UUID
    public let severity: ProblemSeverity
    public let message: String
    public let filePath: String?
    public let line: Int?
    public let column: Int?
    public let source: TimelineEventSource
    public let confidence: TimelineEventConfidence
    public let rawLine: Int64?

    public init(
        id: UUID = UUID(),
        stableKey: String,
        runID: UUID,
        severity: ProblemSeverity,
        message: String,
        filePath: String? = nil,
        line: Int? = nil,
        column: Int? = nil,
        source: TimelineEventSource,
        confidence: TimelineEventConfidence,
        rawLine: Int64? = nil
    ) {
        self.id = id
        self.stableKey = stableKey
        self.runID = runID
        self.severity = severity
        self.message = message
        self.filePath = filePath
        self.line = line
        self.column = column
        self.source = source
        self.confidence = confidence
        self.rawLine = rawLine
    }
}

public enum ProblemSeverity: String, Codable, Sendable {
    case notice
    case warning
    case error
}

public struct AgentApprovalRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stableKey: String
    public let runID: UUID
    public let promptHash: String?
    public let prompt: String
    public let proposedInput: String
    public let rejectInput: String
    public let riskLevel: ApprovalRiskLevel
    public let commandPreview: String?
    public let fallbackInstruction: String?
    public let denialBehavior: DenialBehavior
    public let filePreview: [String]
    public let createdAt: Date
    public var expiresAt: Date?
    public var state: ApprovalState

    public init(
        id: UUID = UUID(),
        stableKey: String,
        runID: UUID,
        promptHash: String? = nil,
        prompt: String,
        proposedInput: String,
        rejectInput: String,
        riskLevel: ApprovalRiskLevel,
        commandPreview: String? = nil,
        fallbackInstruction: String? = nil,
        denialBehavior: DenialBehavior = .stopRun,
        filePreview: [String] = [],
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        state: ApprovalState = .active
    ) {
        self.id = id
        self.stableKey = stableKey
        self.runID = runID
        self.promptHash = promptHash
        self.prompt = prompt
        self.proposedInput = proposedInput
        self.rejectInput = rejectInput
        self.riskLevel = riskLevel
        self.commandPreview = commandPreview
        self.fallbackInstruction = fallbackInstruction
        self.denialBehavior = denialBehavior
        self.filePreview = filePreview
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.state = state
    }
}

public enum TimelineDelta: Sendable {
    case insert(AgentTimelineEvent)
    case update(stableKey: String, AgentTimelineEvent)
    case appendProblem(AgentRunProblem)
    case updateApproval(AgentApprovalRequest?)
    case group(stableKey: String)
}
