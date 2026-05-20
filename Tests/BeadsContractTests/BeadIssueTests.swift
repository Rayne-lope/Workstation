import Foundation
import Testing
@testable import BeadsContract

@Suite("BeadIssue")
struct BeadIssueTests {
    @Test("Decodes blocked_by, dependencies, and dependents from bd JSON")
    func decodesDependencyFields() throws {
        let json = """
        {
            "id": "Workstation-a",
            "title": "Outer",
            "status": "open",
            "blocked_by": ["Workstation-b"],
            "dependencies": [
                { "id": "Workstation-b", "title": "Blocker", "status": "open" }
            ],
            "dependents": [
                { "id": "Workstation-c", "title": "Downstream", "status": "open" }
            ]
        }
        """
        let issue = try JSONDecoder().decode(BeadIssue.self, from: Data(json.utf8))
        #expect(issue.blockedBy == ["Workstation-b"])
        #expect(issue.dependencies?.count == 1)
        #expect(issue.dependencies?.first?.id == "Workstation-b")
        #expect(issue.dependents?.first?.id == "Workstation-c")
    }

    @Test("Legacy JSON without dependency fields decodes with all three nil")
    func legacyJSONDecodesWithNilDependencyFields() throws {
        let json = """
        {
            "id": "bd-legacy",
            "title": "Old shape",
            "status": "open",
            "priority": 2
        }
        """
        let issue = try JSONDecoder().decode(BeadIssue.self, from: Data(json.utf8))
        #expect(issue.blockedBy == nil)
        #expect(issue.dependencies == nil)
        #expect(issue.dependents == nil)
    }

    @Test("bd list/ready 'dependencies' as edge objects decodes silently (dependencies = nil)")
    func edgeShapeDependenciesDecodesTolerantly() throws {
        // `bd list --json` and `bd ready --json` include a `dependencies` field with edge rows,
        // not nested issues. The decoder must NOT throw on this shape; it should ignore it.
        let json = """
        {
          "id": "Workstation-pb5",
          "title": "Auto-reload",
          "status": "open",
          "dependencies": [
            { "issue_id": "Workstation-pb5", "depends_on_id": "Workstation-mqo", "type": "blocks" }
          ]
        }
        """
        let issue = try JSONDecoder().decode(BeadIssue.self, from: Data(json.utf8))
        #expect(issue.id == "Workstation-pb5")
        #expect(issue.dependencies == nil)
    }

    @Test("Roundtrips dependency fields through Codable")
    func codableRoundtrip() throws {
        let blocker = BeadIssue(id: "bd-x", title: "Blocker", status: "open")
        let dependent = BeadIssue(id: "bd-y", title: "Down", status: "open")
        let original = BeadIssue(
            id: "bd-a",
            title: "Center",
            status: "open",
            blockedBy: ["bd-x"],
            dependencies: [blocker],
            dependents: [dependent]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BeadIssue.self, from: data)
        #expect(decoded.blockedBy == ["bd-x"])
        #expect(decoded.dependencies?.first?.id == "bd-x")
        #expect(decoded.dependents?.first?.id == "bd-y")
    }
}
