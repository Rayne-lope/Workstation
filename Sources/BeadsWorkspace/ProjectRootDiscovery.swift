import Foundation

public struct ProjectRootDiscovery: Hashable, Sendable {
    public let selectedURL: URL
    public let rootURL: URL?

    public init(selectedURL: URL, rootURL: URL?) {
        self.selectedURL = selectedURL
        self.rootURL = rootURL
    }
}

public struct ProjectRootResolver: Sendable {
    public init() {}

    public func resolve(from selectedURL: URL) -> ProjectRootDiscovery {
        let startURL = isDirectory(at: selectedURL) ? selectedURL : selectedURL.deletingLastPathComponent()
        var currentPath = startURL.standardizedFileURL.resolvingSymlinksInPath().path

        while true {
            let currentURL = URL(fileURLWithPath: currentPath, isDirectory: true)
            if containsBeadsMarker(at: currentURL) {
                return ProjectRootDiscovery(selectedURL: selectedURL, rootURL: currentURL)
            }

            let parentPath = (currentPath as NSString).deletingLastPathComponent
            if parentPath.isEmpty || parentPath == currentPath {
                break
            }
            currentPath = parentPath
        }

        return ProjectRootDiscovery(selectedURL: selectedURL, rootURL: nil)
    }

    private func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func containsBeadsMarker(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) ||
            FileManager.default.fileExists(atPath: url.appendingPathComponent(".beads").path)
    }
}
