import Foundation
import Testing
@testable import BeadsContract

@Suite("Beads JSON Decoder")
struct BeadsJSONDecoderTests {
    @Test("Decodes list fixtures")
    func decodesListFixture() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/bd-list.json")
        let data = try Data(contentsOf: url)

        let issues = try BeadsJSONDecoder.decodeIssues(from: data)

        #expect(issues.count == 5)
        #expect(issues.first?.id == "bd-1")
        #expect(issues.first?.title == "Set up Beads workspace")
    }

    @Test("Decodes ready fixtures")
    func decodesReadyFixture() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/bd-ready.json")
        let data = try Data(contentsOf: url)

        let issues = try BeadsJSONDecoder.decodeIssues(from: data)

        #expect(issues.count == 1)
        #expect(issues[0].id == "bd-2")
        #expect(issues[0].title == "Draft Kanban mapping")
    }

    @Test("Decodes show fixture")
    func decodesShowFixture() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/bd-show.json")
        let data = try Data(contentsOf: url)

        let issue = try BeadsJSONDecoder.decodeIssue(from: data)

        #expect(issue.id == "bd-2")
        #expect(issue.title == "Draft Kanban mapping")
        #expect(issue.assignee == nil)
    }

    @Test("decodeIssues ignores unknown fields on list payloads")
    func decodeIssuesIgnoresUnknownFields() throws {
        let json = """
        [
          {
            "id": "bd-11",
            "title": "Extra fields are fine",
            "status": "open",
            "unexpected": "value",
            "nested": { "ignored": true }
          }
        ]
        """
        let issues = try BeadsJSONDecoder.decodeIssues(from: Data(json.utf8))

        #expect(issues.count == 1)
        #expect(issues[0].id == "bd-11")
        #expect(issues[0].title == "Extra fields are fine")
        #expect(issues[0].status == "open")
    }

    @Test("decodeIssue ignores unknown fields on wrapped payloads")
    func decodeIssueIgnoresUnknownFields() throws {
        let json = """
        {
          "issues": [
            {
              "id": "bd-12",
              "title": "Wrapped extra",
              "priority": 3,
              "unexpected": "value"
            }
          ],
          "total": 1,
          "cursor": "next-page"
        }
        """
        let issue = try BeadsJSONDecoder.decodeIssue(from: Data(json.utf8))

        #expect(issue.id == "bd-12")
        #expect(issue.title == "Wrapped extra")
        #expect(issue.priority == 3)
    }

    @Test("decodeIssue accepts an array of one (real bd show shape)")
    func decodeIssueAcceptsArrayOfOne() throws {
        let json = """
        [
          {"id": "bd-7", "title": "Wrapped"}
        ]
        """
        let issue = try BeadsJSONDecoder.decodeIssue(from: Data(json.utf8))

        #expect(issue.id == "bd-7")
        #expect(issue.title == "Wrapped")
    }

    @Test("decodeIssue throws emptyArray for empty array input")
    func decodeIssueThrowsOnEmptyArray() throws {
        let data = Data("[]".utf8)

        #expect(throws: BeadsDecodeError.self) {
            _ = try BeadsJSONDecoder.decodeIssue(from: data)
        }
    }

    @Test("Missing optional fields do not crash")
    func missingOptionalFieldsDoNotCrash() throws {
        let json = """
        {
          "id": "bd-x",
          "title": "Minimal issue"
        }
        """
        let issue = try BeadsJSONDecoder.decodeIssue(from: Data(json.utf8))

        #expect(issue.id == "bd-x")
        #expect(issue.title == "Minimal issue")
        #expect(issue.status == nil)
        #expect(issue.priority == nil)
    }
}
