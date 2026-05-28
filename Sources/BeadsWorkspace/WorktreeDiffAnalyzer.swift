import Foundation
#if canImport(BeadsContract)
import BeadsContract
#endif

/// Runs `git diff --name-only HEAD` in a given directory and classifies changed
/// files using the same UI/logic heuristics as PromptGenerator's COMPLETION PROTOCOL.
public actor WorktreeDiffAnalyzer {
    public init() {}

    /// Analyse the git diff in `directory` and return a `DiffAnalysis`.
    public func analyze(in directory: URL) async -> DiffAnalysis {
        let changedFiles = await listChangedFiles(in: directory)
        return Self.classify(changedFiles)
    }

    // MARK: - Git diff

    private func listChangedFiles(in directory: URL) async -> [String] {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["git", "diff", "--name-only", "HEAD"]
            process.currentDirectoryURL = directory

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()  // discard stderr

            do {
                try process.run()
            } catch {
                continuation.resume(returning: [])
                return
            }

            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let files = output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            continuation.resume(returning: files)
        }
    }

    // MARK: - Classification

    /// Classify a list of file paths into UI vs logic buckets and produce a suggestion.
    static func classify(_ files: [String]) -> DiffAnalysis {
        var uiFiles: [String] = []
        var logicFiles: [String] = []

        for file in files {
            if DiffAnalysis.isUIFile(file) {
                uiFiles.append(file)
            } else {
                logicFiles.append(file)
            }
        }

        let suggestion: DiffAnalysis.Suggestion = uiFiles.isEmpty ? .close : .review
        return DiffAnalysis(
            changedFiles: files,
            suggestion: suggestion,
            uiFiles: uiFiles,
            logicFiles: logicFiles
        )
    }
}
