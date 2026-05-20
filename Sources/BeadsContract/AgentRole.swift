import Foundation

public enum AgentRole: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case specWriter
    case codingExecutor
    case reviewer
    case tester
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .specWriter: return "Spec Writer"
        case .codingExecutor: return "Coding Executor"
        case .reviewer: return "Reviewer"
        case .tester: return "Tester"
        case .custom: return "Custom"
        }
    }
}
