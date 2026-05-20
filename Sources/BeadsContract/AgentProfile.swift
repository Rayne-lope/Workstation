import Foundation

public enum AgentAvatarKind: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case codex
    case claude
    case other
    case initials

    public var id: String { rawValue }

    public var fallbackMonogram: String {
        switch self {
        case .codex:
            return "CX"
        case .claude:
            return "CL"
        case .other:
            return "AI"
        case .initials:
            return ""
        }
    }
}

public struct AgentProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var role: AgentRole
    public var command: String
    public var defaultPromptTemplate: String
    public var commandArgsTemplate: String
    public var avatarKind: AgentAvatarKind
    public var canExecuteCode: Bool
    public var shouldClaimIssue: Bool
    public var shouldCloseIssue: Bool
    public var shouldRequestHumanReview: Bool
    public var isBuiltIn: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        role: AgentRole,
        command: String,
        defaultPromptTemplate: String = "",
        commandArgsTemplate: String = "",
        avatarKind: AgentAvatarKind = .initials,
        canExecuteCode: Bool = false,
        shouldClaimIssue: Bool = false,
        shouldCloseIssue: Bool = false,
        shouldRequestHumanReview: Bool = false,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.command = command
        self.defaultPromptTemplate = defaultPromptTemplate
        self.commandArgsTemplate = commandArgsTemplate
        self.avatarKind = avatarKind
        self.canExecuteCode = canExecuteCode
        self.shouldClaimIssue = shouldClaimIssue
        self.shouldCloseIssue = shouldCloseIssue
        self.shouldRequestHumanReview = shouldRequestHumanReview
        self.isBuiltIn = isBuiltIn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.role = try container.decode(AgentRole.self, forKey: .role)
        self.command = try container.decode(String.self, forKey: .command)
        self.defaultPromptTemplate = try container.decodeIfPresent(String.self, forKey: .defaultPromptTemplate) ?? ""
        self.commandArgsTemplate = try container.decodeIfPresent(String.self, forKey: .commandArgsTemplate) ?? ""
        self.avatarKind = try container.decodeIfPresent(AgentAvatarKind.self, forKey: .avatarKind) ?? .initials
        self.canExecuteCode = try container.decodeIfPresent(Bool.self, forKey: .canExecuteCode) ?? false
        self.shouldClaimIssue = try container.decodeIfPresent(Bool.self, forKey: .shouldClaimIssue) ?? false
        self.shouldCloseIssue = try container.decodeIfPresent(Bool.self, forKey: .shouldCloseIssue) ?? false
        self.shouldRequestHumanReview = try container.decodeIfPresent(Bool.self, forKey: .shouldRequestHumanReview) ?? false
        self.isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }
}

public extension AgentProfile {
    static let specWriterID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let codingExecutorID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let reviewerID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let testerID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let codexExecutorID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

    static let builtInProfiles: [AgentProfile] = [
        AgentProfile(
            id: specWriterID,
            name: "Codex Spec Writer",
            role: .specWriter,
            command: "codex",
            commandArgsTemplate: "--dangerously-bypass-approvals-and-sandbox \"{{prompt}}\"",
            avatarKind: .codex,
            canExecuteCode: false,
            shouldClaimIssue: false,
            shouldCloseIssue: false,
            isBuiltIn: true
        ),
        AgentProfile(
            id: codingExecutorID,
            name: "Claude Code Executor",
            role: .codingExecutor,
            command: "claude",
            commandArgsTemplate: "--dangerously-skip-permissions \"{{prompt}}\"",
            avatarKind: .claude,
            canExecuteCode: true,
            shouldClaimIssue: true,
            shouldCloseIssue: false,
            shouldRequestHumanReview: true,
            isBuiltIn: true
        ),
        AgentProfile(
            id: codexExecutorID,
            name: "Codex Code Executor",
            role: .codingExecutor,
            command: "codex",
            commandArgsTemplate: "--dangerously-bypass-approvals-and-sandbox \"{{prompt}}\"",
            avatarKind: .codex,
            canExecuteCode: true,
            shouldClaimIssue: true,
            shouldCloseIssue: false,
            shouldRequestHumanReview: true,
            isBuiltIn: true
        ),
        AgentProfile(
            id: reviewerID,
            name: "AI Reviewer",
            role: .reviewer,
            command: "claude",
            commandArgsTemplate: "--dangerously-skip-permissions \"{{prompt}}\"",
            avatarKind: .claude,
            canExecuteCode: false,
            shouldClaimIssue: false,
            shouldCloseIssue: false,
            isBuiltIn: true
        ),
        AgentProfile(
            id: testerID,
            name: "AI Tester",
            role: .tester,
            command: "claude",
            commandArgsTemplate: "--dangerously-skip-permissions \"{{prompt}}\"",
            avatarKind: .claude,
            canExecuteCode: false,
            shouldClaimIssue: false,
            shouldCloseIssue: false,
            isBuiltIn: true
        )
    ]
}

public extension String {
    var beadsAvatarInitial: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first(where: { $0.isLetter || $0.isNumber }) else {
            return "?"
        }
        return String(first).uppercased()
    }
}

public extension AgentProfile {
    var avatarMonogram: String {
        switch avatarKind {
        case .codex, .claude, .other:
            return avatarKind.fallbackMonogram
        case .initials:
            return name.beadsAvatarInitial
        }
    }

    var claimAssigneeToken: String {
        avatarKind.claimAssigneeToken
    }
}

public extension AgentAvatarKind {
    var claimAssigneeToken: String {
        switch self {
        case .claude:
            return "claude"
        case .codex:
            return "codex"
        case .other, .initials:
            return "other"
        }
    }
}
