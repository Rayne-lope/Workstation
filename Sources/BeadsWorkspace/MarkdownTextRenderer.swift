import Foundation

enum MarkdownTextRenderer {
    enum Mode {
        case detail
        case preview
    }

    static func attributedString(from raw: String, mode: Mode) -> AttributedString? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let parsed = (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
        switch mode {
        case .detail:
            return parsed
        case .preview:
            return parsed.strippingBlockPresentationIntents()
        }
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
