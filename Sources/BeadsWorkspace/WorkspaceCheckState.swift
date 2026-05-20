import Foundation

public enum WorkspaceCheckState: String, Codable, CaseIterable, Sendable {
    case ok = "OK"
    case missing = "Missing"
    case failed = "Failed"
}
