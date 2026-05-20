import Foundation

public struct WorkspaceCheck: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let state: WorkspaceCheckState
    public let detail: String?

    public init(id: String, title: String, state: WorkspaceCheckState, detail: String? = nil) {
        self.id = id
        self.title = title
        self.state = state
        self.detail = detail
    }
}
