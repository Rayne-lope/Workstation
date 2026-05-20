import Foundation

public struct GitChangedFile: Codable, Hashable, Sendable, Identifiable {
    public let path: String
    public let status: String

    public var id: String { "\(status)|\(path)" }

    public init(path: String, status: String) {
        self.path = path
        self.status = status
    }
}

public struct GitStatusSummary: Codable, Hashable, Sendable {
    public let branchName: String?
    public let isDirty: Bool
    public let changedFiles: [GitChangedFile]
    public let lastCommitSummary: String?

    public init(
        branchName: String?,
        isDirty: Bool,
        changedFiles: [GitChangedFile],
        lastCommitSummary: String?
    ) {
        self.branchName = branchName
        self.isDirty = isDirty
        self.changedFiles = changedFiles
        self.lastCommitSummary = lastCommitSummary
    }
}

public extension GitStatusSummary {
    func filtered(ignoringPaths ignoredPaths: Set<String>) -> GitStatusSummary {
        guard !ignoredPaths.isEmpty else { return self }

        let filteredChangedFiles = changedFiles.filter { !ignoredPaths.contains($0.path) }
        return GitStatusSummary(
            branchName: branchName,
            isDirty: !filteredChangedFiles.isEmpty,
            changedFiles: filteredChangedFiles,
            lastCommitSummary: lastCommitSummary
        )
    }
}
