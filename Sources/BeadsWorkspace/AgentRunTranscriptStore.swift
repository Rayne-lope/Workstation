import Foundation
import Observation

@MainActor
@Observable
public final class AgentRunTranscriptStore {
    public private(set) var messages: [AgentRunMessage] = []
    public private(set) var errorMessage: String?

    private let fileManager: FileManager
    private let fileURL: URL
    private let clock: @Sendable () -> Date

    public init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.clock = clock
        load()
    }

    public func messages(forRunID runID: UUID) -> [AgentRunMessage] {
        messages
            .filter { $0.runID == runID }
            .sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt < $1.createdAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    @discardableResult
    public func append(
        runID: UUID,
        role: AgentRunMessageRole,
        content: String
    ) -> AgentRunMessage? {
        if role == .agent {
            if let lastIndex = messages.lastIndex(where: { $0.runID == runID }),
               messages[lastIndex].role == .agent {
                messages[lastIndex].content += content
                persist()
                return messages[lastIndex]
            }
            guard !content.isEmpty else { return nil }
            let message = AgentRunMessage(
                runID: runID,
                role: role,
                content: content,
                createdAt: clock()
            )
            messages.append(message)
            persist()
            return message
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let message = AgentRunMessage(
            runID: runID,
            role: role,
            content: content,
            createdAt: clock()
        )
        messages.append(message)
        persist()
        return message
    }

    public func updateContent(id: UUID, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages[index].content = content
        persist()
    }

    public func updateRole(id: UUID, role: AgentRunMessageRole) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].role = role
        persist()
    }

    public func delete(id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages.remove(at: index)
        persist()
    }

    public func deleteAll(forRunID runID: UUID) {
        let before = messages.count
        messages.removeAll { $0.runID == runID }
        if messages.count != before {
            persist()
        }
    }

    public func clearErrorMessage() {
        errorMessage = nil
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            messages = []
            errorMessage = nil
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            messages = try decoder.decode([AgentRunMessage].self, from: data)
            errorMessage = nil
        } catch {
            messages = []
            errorMessage = "Failed to load agent run transcript: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let encoder = JSONEncoder()
            let data = try encoder.encode(messages)
            try data.write(to: fileURL, options: [.atomic])
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save agent run transcript: \(error.localizedDescription)"
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return baseDirectory
            .appendingPathComponent("Workstation", isDirectory: true)
            .appendingPathComponent("agent-run-transcripts.json", isDirectory: false)
    }
}
