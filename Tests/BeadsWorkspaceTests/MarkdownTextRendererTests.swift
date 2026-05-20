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
}
