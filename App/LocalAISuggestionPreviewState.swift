import Foundation
import Observation

@MainActor
@Observable
final class LocalAISuggestionPreviewState: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let sourceLabel: String
    let originalText: String
    let primaryActionTitle: String

    var draftText: String
    var isRegenerating = false
    var errorMessage: String?

    private let regenerateAction: @MainActor () async throws -> String
    private let applyAction: @MainActor (String) -> Void

    init(
        title: String,
        subtitle: String,
        sourceLabel: String,
        generatedText: String,
        primaryActionTitle: String = "Apply",
        regenerate: @escaping @MainActor () async throws -> String,
        onApply: @escaping @MainActor (String) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.sourceLabel = sourceLabel
        self.originalText = generatedText
        self.primaryActionTitle = primaryActionTitle
        self.draftText = generatedText
        self.regenerateAction = regenerate
        self.applyAction = onApply
    }

    var trimmedDraftText: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func regenerate() async {
        guard !isRegenerating else { return }
        isRegenerating = true
        defer { isRegenerating = false }

        do {
            draftText = try await regenerateAction()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func apply() {
        applyAction(draftText)
    }
}
