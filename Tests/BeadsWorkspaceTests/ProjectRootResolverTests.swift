import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("Project Root Resolver")
struct ProjectRootResolverTests {
    @Test("Finds project root from subfolder")
    func findsProjectRootFromSubfolder() throws {
        let root = try makeTemporaryDirectory(named: "project-root")
        defer { try? FileManager.default.removeItem(at: root) }

        let project = root.appendingPathComponent("project", isDirectory: true)
        let src = project.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: project.appendingPathComponent(".git").path, contents: Data(), attributes: nil)
        FileManager.default.createFile(atPath: project.appendingPathComponent(".beads").path, contents: Data(), attributes: nil)

        let discovery = ProjectRootResolver().resolve(from: src)

        #expect(discovery.rootURL == project)
    }

    @Test("Returns nil when no marker exists")
    func returnsNilWhenNoMarkerExists() throws {
        let folder = try makeTemporaryDirectory(named: "no-marker")
        defer { try? FileManager.default.removeItem(at: folder) }

        let discovery = ProjectRootResolver().resolve(from: folder)

        #expect(discovery.rootURL == nil)
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return URL(fileURLWithPath: url.path, isDirectory: true)
    }
}
