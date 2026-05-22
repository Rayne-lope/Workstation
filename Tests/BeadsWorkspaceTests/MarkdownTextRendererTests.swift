import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("Markdown Text Renderer")
struct MarkdownTextRendererTests {
    @Test("detail mode keeps block presentation intents for headings")
    func detailModeKeepsHeadingPresentationIntent() throws {
        let rendered = try #require(
            MarkdownTextRenderer.attributedString(
                from: "# Heading\n\nBody",
                mode: .detail
            )
        )

        #expect(hasPresentationIntent(rendered))
        #expect(String(rendered.characters).contains("Heading"))
        #expect(String(rendered.characters).contains("Body"))
    }

    @Test("preview mode strips block presentation intents")
    func previewModeStripsBlockPresentationIntent() throws {
        let rendered = try #require(
            MarkdownTextRenderer.attributedString(
                from: "# Heading\n\nBody",
                mode: .preview
            )
        )

        #expect(!hasPresentationIntent(rendered))
        #expect(String(rendered.characters).contains("Heading"))
        #expect(String(rendered.characters).contains("Body"))
    }

    @Test("detail mode preserves list and code block content")
    func detailModePreservesListAndCodeBlockContent() throws {
        let markdown = """
        - First item
        - Second item

        ```swift
        print("hello")
        ```
        """
        let rendered = try #require(
            MarkdownTextRenderer.attributedString(
                from: markdown,
                mode: .detail
            )
        )

        let plain = String(rendered.characters)
        #expect(plain.contains("First item"))
        #expect(plain.contains("Second item"))
        #expect(plain.contains("print(\"hello\")"))
    }

    @Test("plain text falls back without losing content")
    func plainTextFallsBackWithoutLosingContent() throws {
        let raw = "Plain text description with no markdown"
        let rendered = try #require(
            MarkdownTextRenderer.attributedString(
                from: raw,
                mode: .detail
            )
        )

        #expect(String(rendered.characters) == raw)
    }

    private func hasPresentationIntent(_ attributed: AttributedString) -> Bool {
        for run in attributed.runs {
            if run.presentationIntent != nil {
                return true
            }
        }
        return false
    }

    @Test("parseContentBlocks parses standard markdown table with pipes and alignments")
    func parseContentBlocksParsesStandardTable() throws {
        let markdown = """
        Here is a list of features:
        | Feature | Status | Priority |
        |:---|---:|:---:|
        | Boards | Done | 1 |
        | Timeline | In Progress | 2 |
        
        That is all!
        """
        
        let blocks = MarkdownTextRenderer.parseContentBlocks(from: markdown)
        #expect(blocks.count == 3)
        
        // Block 0: "Here is a list of features:"
        if case .text(let txt) = blocks[0] {
            #expect(txt.contains("Here is a list of features:"))
        } else {
            Issue.record("Expected first block to be text")
        }
        
        // Block 1: The table
        if case .table(let headers, let alignments, let rows) = blocks[1] {
            #expect(headers == ["Feature", "Status", "Priority"])
            #expect(alignments == [.left, .right, .center])
            #expect(rows.count == 2)
            #expect(rows[0] == ["Boards", "Done", "1"])
            #expect(rows[1] == ["Timeline", "In Progress", "2"])
        } else {
            Issue.record("Expected second block to be a table")
        }
        
        // Block 2: "That is all!"
        if case .text(let txt) = blocks[2] {
            #expect(txt.contains("That is all!"))
        } else {
            Issue.record("Expected third block to be text")
        }
    }

    @Test("parseContentBlocks parses table without outer bounding pipes")
    func parseContentBlocksNoBoundingPipes() throws {
        let markdown = """
        Col 1 | Col 2
        ---|---
        A | B
        C | D
        """
        
        let blocks = MarkdownTextRenderer.parseContentBlocks(from: markdown)
        #expect(blocks.count == 1)
        
        if case .table(let headers, let alignments, let rows) = blocks[0] {
            #expect(headers == ["Col 1", "Col 2"])
            #expect(alignments == [.left, .left])
            #expect(rows.count == 2)
            #expect(rows[0] == ["A", "B"])
            #expect(rows[1] == ["C", "D"])
        } else {
            Issue.record("Expected table block")
        }
    }

    @Test("parseContentBlocks gracefully handles skewed or missing cells")
    func parseContentBlocksGracefulSkewedCells() throws {
        let markdown = """
        | Header 1 | Header 2 |
        |---|---|
        | SingleCell |
        | ExtraCell 1 | ExtraCell 2 | ExtraCell 3 |
        """
        
        let blocks = MarkdownTextRenderer.parseContentBlocks(from: markdown)
        #expect(blocks.count == 1)
        
        if case .table(let headers, _, let rows) = blocks[0] {
            #expect(headers.count == 2)
            #expect(rows.count == 2)
            // SingleCell should be padded with empty string to match header count
            #expect(rows[0] == ["SingleCell", ""])
            // ExtraCell row should be truncated to match header count
            #expect(rows[1] == ["ExtraCell 1", "ExtraCell 2"])
        } else {
            Issue.record("Expected table block")
        }
    }
}
