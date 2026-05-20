import Foundation

public enum WorkspaceSelectionError: LocalizedError, Sendable {
    case unreachableFolder(URL)

    public var errorDescription: String? {
        switch self {
        case let .unreachableFolder(url):
            return "Unable to access folder at \(url.path)."
        }
    }
}
