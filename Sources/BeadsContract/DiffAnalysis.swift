import Foundation

/// Result of analysing `git diff --name-only HEAD` in a workspace or worktree directory.
/// Applies the same file-pattern heuristics as PromptGenerator's COMPLETION PROTOCOL.
public struct DiffAnalysis: Sendable {
    public enum Suggestion: Sendable {
        /// All changed files are pure logic / backend — safe to self-close.
        case close
        /// At least one changed file looks like UI / visual — flag for human review.
        case review
    }

    /// All files that appear in the diff.
    public let changedFiles: [String]
    /// Suggested action based on file patterns.
    public let suggestion: Suggestion
    /// Files that matched a UI/visual pattern (reason for a `.review` suggestion).
    public let uiFiles: [String]
    /// Files classified as logic/data (no UI patterns).
    public let logicFiles: [String]

    public init(
        changedFiles: [String],
        suggestion: Suggestion,
        uiFiles: [String],
        logicFiles: [String]
    ) {
        self.changedFiles = changedFiles
        self.suggestion = suggestion
        self.uiFiles = uiFiles
        self.logicFiles = logicFiles
    }

    // MARK: - File pattern heuristics (mirrors PromptGenerator COMPLETION PROTOCOL)

    /// Returns `true` if the given file path looks like a UI / visual file.
    /// Matches the patterns used in PromptGenerator's REQUIRES HUMAN REVIEW block.
    public static func isUIFile(_ path: String) -> Bool {
        let lower = path.lowercased()
        let filename = (path as NSString).lastPathComponent.lowercased()
        let ext = (path as NSString).pathExtension.lowercased()

        // Extension-based checks
        let uiExtensions: Set<String> = [
            "jsx", "tsx", "vue", "html", "htm",
            "css", "scss", "sass", "less",
            "storyboard", "xib",
            "xcassets",
            "strings", "stringsdict", "arb", "po", "pot"
        ]
        if uiExtensions.contains(ext) { return true }

        // Name-based checks (View, Screen, Component, Widget, etc.)
        let uiNameKeywords = [
            "view", "screen", "component", "widget", "page",
            "layout", "template", "localizable", "sheet"
        ]
        if uiNameKeywords.contains(where: { filename.contains($0) }) { return true }

        // Path segment checks (assets, images, icons, public, etc.)
        let uiPathSegments = [
            "assets/", "images/", "icons/", "resources/",
            "public/", "static/", "res/"
        ]
        if uiPathSegments.contains(where: { lower.contains($0) }) { return true }

        return false
    }
}
