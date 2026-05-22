import Testing
@testable import BeadsWorkspace

@Suite("IssueDraft")
struct IssueDraftTests {
    @Test("parses structured JSON into an editable draft")
    func parsesStructuredJSON() throws {
        let raw = """
        {
          "title": "Build issue detailer",
          "description": "Turn rough ideas into drafts.",
          "implementation_notes": "Start with a rough idea field.",
          "acceptance_criteria": [
            "User can generate a draft",
            "User can edit the draft"
          ],
          "issue_type": "feature",
          "priority": 1,
          "labels": ["ai", "drafting"],
          "split_suggestions": ["Split parsing into a helper"],
          "dependency_suggestions": ["Depends on local AI settings"]
        }
        """

        let draft = try IssueDraft.parse(from: raw)
        #expect(draft.title == "Build issue detailer")
        #expect(draft.description == "Turn rough ideas into drafts.")
        #expect(draft.implementationNotes == "Start with a rough idea field.")
        #expect(draft.acceptanceCriteria.contains("User can generate a draft"))
        #expect(draft.acceptanceCriteria.contains("User can edit the draft"))
        #expect(draft.issueType == "feature")
        #expect(draft.priority == 1)
        #expect(draft.labels == "ai, drafting")
        #expect(draft.splitSuggestions.contains("Split parsing into a helper"))
        #expect(draft.dependencySuggestions.contains("Depends on local AI settings"))

        let input = draft.createInput()
        #expect(input.title == "Build issue detailer")
        #expect(input.designNotes == "Start with a rough idea field.")
        #expect(input.labels == ["ai", "drafting"])
    }

    @Test("parses labeled plain text into a structured draft")
    func parsesLabeledPlainText() throws {
        let raw = """
        Title: Add issue detailer
        Description: Let users turn rough ideas into drafts.
        Implementation Notes: Use the local AI response preview.
        Acceptance Criteria:
        - User can generate a structured draft
        - User can edit it
        Type: feature
        Priority: 2
        Labels: ai, draft
        Split Suggestions:
        - Extract parsing into a helper
        Dependency Suggestions:
        - Needs local AI service
        """

        let draft = try IssueDraft.parse(from: raw)
        #expect(draft.title == "Add issue detailer")
        #expect(draft.description.contains("rough ideas into drafts"))
        #expect(draft.implementationNotes.contains("local AI response preview"))
        #expect(draft.acceptanceCriteria.contains("User can generate a structured draft"))
        #expect(draft.issueType == "feature")
        #expect(draft.priority == 2)
        #expect(draft.labels == "ai, draft")
        #expect(draft.splitSuggestions.contains("Extract parsing into a helper"))
        #expect(draft.dependencySuggestions.contains("Needs local AI service"))
    }

    @Test("missing optional fields still produce a usable draft")
    func parsesMinimalJSON() throws {
        let draft = try IssueDraft.parse(from: #"{"title":"Minimal draft"}"#)

        #expect(draft.title == "Minimal draft")
        #expect(draft.description.isEmpty)
        #expect(draft.implementationNotes.isEmpty)
        #expect(draft.acceptanceCriteria.isEmpty)
        #expect(draft.issueType == nil)
        #expect(draft.priority == nil)
        #expect(draft.labels.isEmpty)
    }

    @Test("unparseable output fails gracefully")
    func rejectsUnparseableOutput() {
        #expect(throws: IssueDraftParseError.self) {
            _ = try IssueDraft.parse(from: "This is just a loose paragraph with no draft fields.")
        }
    }
}
