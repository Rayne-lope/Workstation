#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation
import Observation

@MainActor
@Observable
public final class RecurringStore {
    public private(set) var metadataByID: [String: RecurringMetadata] = [:]
    public private(set) var errorMessage: String?

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// `.beads/recurring/` under the workspace root.
    public init(workingDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = workingDirectory
            .appendingPathComponent(".beads", isDirectory: true)
            .appendingPathComponent("recurring", isDirectory: true)
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Queries

    public func isRecurring(id: String) -> Bool {
        metadataByID[id]?.isRecurring == true
    }

    public func metadata(id: String) -> RecurringMetadata? {
        metadataByID[id]
    }

    public var recurringIDs: Set<String> {
        Set(metadataByID.values.filter { $0.isRecurring }.map { $0.issueID })
    }

    // MARK: - Loading

    public func load() {
        errorMessage = nil
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            metadataByID = [:]
            return
        }
        do {
            let items = try fileManager.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            var loaded: [String: RecurringMetadata] = [:]
            for url in items {
                if let data = try? Data(contentsOf: url),
                   let value = try? decoder.decode(RecurringMetadata.self, from: data) {
                    loaded[value.issueID] = value
                }
            }
            metadataByID = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mutations

    public func markRecurring(id: String, cadenceDays: Int? = nil) {
        var current = metadataByID[id] ?? RecurringMetadata(issueID: id)
        current.isRecurring = true
        if let cadenceDays {
            current.cadenceDays = cadenceDays
        }
        persist(current)
    }

    public func unmarkRecurring(id: String) {
        guard var current = metadataByID[id] else { return }
        current.isRecurring = false
        // Keep history but flag as inactive. Caller can delete via `removeMetadata` if they want a hard clear.
        persist(current)
    }

    public func setCadence(id: String, days: Int?) {
        var current = metadataByID[id] ?? RecurringMetadata(issueID: id)
        current.cadenceDays = days
        if !current.isRecurring && days != nil {
            current.isRecurring = true
        }
        persist(current)
    }

    public func appendHistory(id: String, entry: RecurringHistoryEntry) {
        var current = metadataByID[id] ?? RecurringMetadata(issueID: id, isRecurring: true)
        current.isRecurring = true
        current.history.append(entry)
        persist(current)
    }

    /// Remove the sidecar file entirely. Use when the underlying issue is permanently deleted
    /// or the user explicitly wants to forget history.
    public func removeMetadata(id: String) {
        metadataByID.removeValue(forKey: id)
        let url = fileURL(for: id)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Persistence

    private func persist(_ metadata: RecurringMetadata) {
        do {
            try ensureRootExists()
            let data = try encoder.encode(metadata)
            try data.write(to: fileURL(for: metadata.issueID), options: .atomic)
            metadataByID[metadata.issueID] = metadata
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureRootExists() throws {
        if !fileManager.fileExists(atPath: rootDirectory.path) {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for issueID: String) -> URL {
        let sanitized = issueID.replacingOccurrences(of: "/", with: "_")
        return rootDirectory.appendingPathComponent("\(sanitized).json", isDirectory: false)
    }
}
