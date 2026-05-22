import Foundation

enum MarkdownTextRenderer {
    enum Mode {
        case detail
        case preview
        case copilot
    }

    static func attributedString(from raw: String, mode: Mode) -> AttributedString? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let parsed = (try? AttributedString(markdown: raw, options: AttributedString.MarkdownParsingOptions(interpretedStyles: .essential))) ?? AttributedString(raw)

        switch mode {
        case .detail, .preview:
            return parsed.strippingBlockPresentationIntents()
        case .copilot:
            return applyCopilotStyling(parsed)
        }
    }

    /// Apply dark theme styling for copilot chat bubbles.
    /// Uses DM Sans for body text, preserves bold/italic/strikethrough.
    private static func applyCopilotStyling(_ text: AttributedString) -> AttributedString {
        var result = text

        // Base font: DM Sans 13pt
        let baseFont = NSFont(name: "DM Sans", size: 13) ?? NSFont.systemFont(ofSize: 13)
        let boldFont = NSFont(name: "DM Sans", size: 13)?.bold() ?? NSFont.boldSystemFont(ofSize: 13)
        let italicFont = NSFont(name: "DM Sans-Italic", size: 13) ?? NSFont.italicSystemFont(ofSize: 13)

        // Apply base attributes to all runs that don't have custom styling
        for run in result.runs {
            if run.font == nil && run.presentationIntent?.contains(.strong) != true {
                result[run.range].font = baseFont
                result[run.range].foregroundColor = NSColor(WorkstationTheme.textPrimary)
            }

            // Bold for strong emphasis
            if run.presentationIntent?.contains(.strong) == true {
                result[run.range].font = boldFont
            }

            // Italic for emphasis
            if run.presentationIntent?.contains(.emphasis) == true {
                result[run.range].font = italicFont
            }
        }

        return result
    }

    /// Render markdown text for copilot assistant bubbles using SwiftUI Text.
    /// Falls back to plain text if markdown parsing fails.
    static func copilotText(for raw: String) -> Text {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Text("")
        }

        // Use AttributedString for markdown rendering, then convert to SwiftUI Text
        // SwiftUI Text can accept AttributedString directly in iOS 17+/macOS 14+
        if let attributed = try? AttributedString(markdown: trimmed, options: AttributedString.MarkdownParsingOptions(interpretedStyles: .essential)) {
            return Text(attributed)
        }

        // Fallback to plain text
        return Text(trimmed)
    }
}

private extension AttributedString {
    func strippingBlockPresentationIntents() -> AttributedString {
        var copy = self
        for run in runs where run.presentationIntent != nil {
            copy[run.range].presentationIntent = nil
        }
        return copy
    }
}

private extension NSFont {
    func bold() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.bold)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
