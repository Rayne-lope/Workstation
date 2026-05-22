import Foundation
import Observation

@MainActor
@Observable
public final class CopilotTranscriptStore {
    public private(set) var conversations: [String: [CopilotConversationMessage]] = [:]
    public private(set) var errorMessage: String?

    private let fileManager: FileManager
    private let fileURL: URL

    public init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        load()
    }

    public func messages(forIssueID issueID: String) -> [CopilotConversationMessage] {
        conversations[issueID] ?? []
    }

    public func save(messages: [CopilotConversationMessage], forIssueID issueID: String) {
        conversations[issueID] = messages
        persist()
    }

    public func clear(forIssueID issueID: String) {
        conversations[issueID] = nil
        persist()
    }

    public func clearAll() {
        conversations = [:]
        persist()
    }

    public func clearErrorMessage() {
        errorMessage = nil
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            conversations = [:]
            errorMessage = nil
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            conversations = try decoder.decode([String: [CopilotConversationMessage]].self, from: data)
            errorMessage = nil
        } catch {
            conversations = [:]
            errorMessage = "Failed to load Copilot transcripts: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let encoder = JSONEncoder()
            let data = try encoder.encode(conversations)
            try data.write(to: fileURL, options: [.atomic])
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save Copilot transcripts: \(error.localizedDescription)"
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return baseDirectory
            .appendingPathComponent("Workstation", isDirectory: true)
            .appendingPathComponent("copilot-transcripts.json", isDirectory: false)
    }
}
