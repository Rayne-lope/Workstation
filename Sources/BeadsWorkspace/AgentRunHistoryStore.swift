import Foundation
import Observation

@MainActor
@Observable
public final class AgentRunHistoryStore {
    public private(set) var records: [AgentRunRecord] = []
    public private(set) var errorMessage: String?

    private let fileManager: FileManager
    private let fileURL: URL
    private let maxEntries: Int
    private let clock: @Sendable () -> Date

    public init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil,
        maxEntries: Int = 50,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.maxEntries = max(1, maxEntries)
        self.clock = clock
        load()
    }

    public func recordLaunchAttempt(
        issueID: String,
        issueTitle: String,
        agentProfileID: UUID?,
        agentName: String,
        command: String,
        prompt: String,
        projectPath: String,
        worktree: AgentRunWorktreeMetadata? = nil,
        status: AgentRunStatus = .prepared,
        notes: String? = nil
    ) -> AgentRunRecord {
        let record = AgentRunRecord(
            issueID: issueID,
            issueTitle: issueTitle,
            agentProfileID: agentProfileID,
            agentName: agentName,
            command: command,
            prompt: prompt,
            projectPath: projectPath,
            worktree: worktree,
            startedAt: clock(),
            completedAt: status.isFinalized ? clock() : nil,
            status: status,
            notes: notes
        )
        upsert(record)
        return record
    }

    public func updateStatus(id: UUID, status: AgentRunStatus, notes: String? = nil) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        var updated = records[index]
        updated.status = status
        if let notes {
            updated.notes = notes
        }
        updated.completedAt = status.isFinalized ? clock() : nil
        records[index] = updated
        normalizeAndPersist()
    }

    public func updateNotes(id: UUID, notes: String?) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        var updated = records[index]
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = (trimmed?.isEmpty ?? true) ? nil : notes
        records[index] = updated
        normalizeAndPersist()
    }

    public func record(id: UUID) -> AgentRunRecord? {
        records.first { $0.id == id }
    }

    public func latestRecord(forIssueID issueID: String) -> AgentRunRecord? {
        records.first { $0.issueID == issueID }
    }

    public func clearErrorMessage() {
        errorMessage = nil
    }

    private func upsert(_ record: AgentRunRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
        normalizeAndPersist()
    }

    private func normalizeAndPersist() {
        records.sort {
            if $0.startedAt != $1.startedAt {
                return $0.startedAt > $1.startedAt
            }
            return $0.id.uuidString > $1.id.uuidString
        }
        if records.count > maxEntries {
            records = Array(records.prefix(maxEntries))
        }
        persist()
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            records = []
            errorMessage = nil
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([AgentRunRecord].self, from: data)
            records = decoded.sorted {
                if $0.startedAt != $1.startedAt {
                    return $0.startedAt > $1.startedAt
                }
                return $0.id.uuidString > $1.id.uuidString
            }
            errorMessage = nil
        } catch {
            records = []
            errorMessage = "Failed to load agent run history: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: [.atomic])
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save agent run history: \(error.localizedDescription)"
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return baseDirectory
            .appendingPathComponent("BeadsKanbanApp", isDirectory: true)
            .appendingPathComponent("agent-run-history.json", isDirectory: false)
    }
}
