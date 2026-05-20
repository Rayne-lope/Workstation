import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("ProjectWorkspace")
struct ProjectWorkspaceTests {
    @Test("setupHints include bd init, bd setup claude, and brew install beads when markers are missing")
    func setupHintsCoverMissingSetupStates() {
        let workspace = ProjectWorkspace(
            selectedURL: URL(fileURLWithPath: "/tmp/project"),
            rootURL: URL(fileURLWithPath: "/tmp/project"),
            inspectionURL: URL(fileURLWithPath: "/tmp/project"),
            name: "project",
            validationState: .missing,
            checks: [
                WorkspaceCheck(id: ".beads", title: ".beads", state: .missing),
                WorkspaceCheck(id: "AGENTS.md", title: "AGENTS.md", state: .missing),
                WorkspaceCheck(id: "bd-cli", title: "bd CLI", state: .missing),
            ]
        )

        let hints = workspace.setupHints

        #expect(hints.map(\.id) == ["bd-init", "bd-setup-claude", "bd-install"])
        #expect(hints[0].command == "bd init")
        #expect(hints[1].command == "bd setup claude")
        #expect(hints[2].command == "brew install beads")
    }

    @Test("notABeadsProject still suggests bd init")
    func notABeadsProjectSuggestsInit() {
        let workspace = ProjectWorkspace(
            selectedURL: URL(fileURLWithPath: "/tmp/project"),
            rootURL: nil,
            inspectionURL: URL(fileURLWithPath: "/tmp/project"),
            name: "project",
            validationState: .notABeadsProject,
            checks: []
        )

        let hints = workspace.setupHints

        #expect(hints.count == 1)
        #expect(hints.first?.command == "bd init")
    }
}
