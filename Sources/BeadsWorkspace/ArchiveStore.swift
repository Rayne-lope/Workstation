#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation
import Observation

@MainActor
@Observable
public final class ArchiveStore {
    public private(set) var archivedIssues: [BeadIssue] = []
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    private let workingDirectory: URL
    private let archiveDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(workingDirectory: URL, fileManager: FileManager = .default) {
        self.workingDirectory = workingDirectory
        self.archiveDirectory = workingDirectory
            .appendingPathComponent(".beads", isDirectory: true)
            .appendingPathComponent("archive", isDirectory: true)
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Quarter Partition helper

    public static func partitionName(for closedAtString: String?, currentDate: Date = Date()) -> String {
        guard let closedAt = closedAtString, closedAt.count >= 7 else {
            return currentQuarterString(currentDate: currentDate)
        }
        let year = closedAt.prefix(4)
        let monthString = closedAt.dropFirst(5).prefix(2)
        guard let month = Int(monthString) else {
            return currentQuarterString(currentDate: currentDate)
        }
        let quarter: String
        switch month {
        case 1...3: quarter = "Q1"
        case 4...6: quarter = "Q2"
        case 7...9: quarter = "Q3"
        default: quarter = "Q4"
        }
        return "\(year)-\(quarter)"
    }

    private static func currentQuarterString(currentDate: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        let quarter: String
        switch month {
        case 1...3: quarter = "Q1"
        case 4...6: quarter = "Q2"
        case 7...9: quarter = "Q3"
        default: quarter = "Q4"
        }
        return "\(year)-\(quarter)"
    }

    // MARK: - Loading

    public func load() {
        errorMessage = nil
        guard fileManager.fileExists(atPath: archiveDirectory.path) else {
            archivedIssues = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let files = try fileManager.contentsOfDirectory(at: archiveDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

            var allIssues: [BeadIssue] = []
            for fileURL in files {
                if let data = try? Data(contentsOf: fileURL),
                   let issues = try? decoder.decode([BeadIssue].self, from: data) {
                    allIssues.append(contentsOf: issues)
                }
            }

            // Deduplicate by ID just in case
            var seen = Set<String>()
            let deduped = allIssues.filter { issue in
                seen.insert(issue.id).inserted
            }

            archivedIssues = deduped.sorted { lhs, rhs in
                let lc = lhs.closedAt ?? lhs.updatedAt ?? ""
                let rc = rhs.closedAt ?? rhs.updatedAt ?? ""
                if lc != rc { return lc > rc }
                return lhs.id < rhs.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Archiving / Sweeping

    public func archiveIssues(_ issuesToArchive: [BeadIssue], service: BeadsService) async {
        guard !issuesToArchive.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try ensureArchiveDirectoryExists()

            // Group issues by partition
            var partitioned: [String: [BeadIssue]] = [:]
            for issue in issuesToArchive {
                let partition = Self.partitionName(for: issue.closedAt)
                partitioned[partition, default: []].append(issue)
            }

            // Process each partition
            for (partition, issues) in partitioned {
                let fileURL = archiveFileURL(for: partition)
                var existing: [BeadIssue] = []

                if fileManager.fileExists(atPath: fileURL.path) {
                    if let data = try? Data(contentsOf: fileURL),
                       let parsed = try? decoder.decode([BeadIssue].self, from: data) {
                        existing = parsed
                    }
                }

                // Merge and deduplicate, prioritizing the new data if any overlap exists
                var mergedMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
                for issue in issues {
                    mergedMap[issue.id] = issue
                }

                let mergedIssues = Array(mergedMap.values).sorted { lhs, rhs in
                    let lc = lhs.closedAt ?? lhs.updatedAt ?? ""
                    let rc = rhs.closedAt ?? rhs.updatedAt ?? ""
                    if lc != rc { return lc > rc }
                    return lhs.id < rhs.id
                }

                let data = try encoder.encode(mergedIssues)
                try data.write(to: fileURL, options: .atomic)
            }

            // Batch delete the issues from the active Dolt database
            let idsToDelete = issuesToArchive.map(\.id)
            try await service.deleteIssues(ids: idsToDelete, in: workingDirectory)

            // Reload the local state
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureArchiveDirectoryExists() throws {
        if !fileManager.fileExists(atPath: archiveDirectory.path) {
            try fileManager.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)
        }
    }

    private func archiveFileURL(for partition: String) -> URL {
        archiveDirectory.appendingPathComponent("\(partition).json", isDirectory: false)
    }
}
