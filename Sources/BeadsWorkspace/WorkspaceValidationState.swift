import Foundation

public enum WorkspaceValidationState: String, Codable, CaseIterable, Sendable {
    case valid = "Valid"
    case missing = "Missing"
    case failed = "Failed"
    case notABeadsProject = "Not a Beads project"
}
