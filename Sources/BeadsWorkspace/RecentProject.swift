import Foundation

public struct RecentProject: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let selectedPath: String
    public let rootPath: String?
    public let name: String
    public let lastOpenedAt: Date

    public init(
        id: UUID = UUID(),
        selectedPath: String,
        rootPath: String?,
        name: String,
        lastOpenedAt: Date
    ) {
        self.id = id
        self.selectedPath = selectedPath
        self.rootPath = rootPath
        self.name = name
        self.lastOpenedAt = lastOpenedAt
    }
}
