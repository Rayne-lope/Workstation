#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation
import Observation

/// Persists per-issue focus sessions to `.beads/focus/<issueID>.json`.
/// Each session tracks multiple completed intervals and one active interval.
@MainActor
@Observable
final class FocusSessionStore {
    private(set) var sessions: [String: FocusSessionData] = [:]
    private(set) var errorMessage: String?

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// `.beads/focus/` under the workspace root.
    init(workingDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = workingDirectory
            .appendingPathComponent(".beads", isDirectory: true)
            .appendingPathComponent("focus", isDirectory: true)
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

    func session(for issueID: String) -> FocusSessionData? {
        sessions[issueID]
    }

    func totalMs(for issueID: String) -> Int64 {
        sessions[issueID]?.totalActiveMs ?? 0
    }

    // MARK: - Loading

    func load() {
        errorMessage = nil
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            sessions = [:]
            return
        }
        do {
            let items = try fileManager.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            var loaded: [String: FocusSessionData] = [:]
            for url in items {
                if let data = try? Data(contentsOf: url),
                   let value = try? decoder.decode(FocusSessionData.self, from: data) {
                    loaded[value.issueID] = value
                }
            }
            sessions = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mutations

    /// Start a new focus interval for the given issue. If there's already an active
    /// interval, it is closed first (as if End was pressed).
    func startFocus(issueID: String) {
        var session = sessions[issueID] ?? FocusSessionData(issueID: issueID)

        // Close any existing active interval
        if let active = session.activeInterval {
            var ended = active
            ended.endedAt = Date()
            session.completedIntervals.append(ended)
        }

        session.activeInterval = FocusInterval(startedAt: Date())
        persist(session)
    }

    /// End the current active interval without starting a new one.
    func endFocus(issueID: String) {
        guard var session = sessions[issueID], session.isActive else { return }
        if let active = session.activeInterval {
            var ended = active
            ended.endedAt = Date()
            session.completedIntervals.append(ended)
        }
        session.activeInterval = nil
        persist(session)
    }

    /// Pause the active interval — effectively adds current elapsed time to pauseMs
    /// and ends the interval. Resume will start a new interval.
    func pauseFocus(issueID: String) {
        guard var session = sessions[issueID], session.isActive else { return }

        let now = Date()
        // Add elapsed time to pause total
        if let active = session.activeInterval {
            let elapsedMs = Int64(now.timeIntervalSince(active.startedAt) * 1000)
            session.totalPauseMs += elapsedMs
            // End the active interval (pause = end without completing)
            var ended = active
            ended.endedAt = now
            session.completedIntervals.append(ended)
        }
        session.activeInterval = nil
        persist(session)
    }

    /// Resume from a paused state — starts a new interval.
    func resumeFocus(issueID: String) {
        guard var session = sessions[issueID], !session.isActive else { return }
        session.activeInterval = FocusInterval(startedAt: Date())
        persist(session)
    }

    /// Toggle: if no active session, start; if active for same issue, end; if active for different issue, switch.
    func toggleFocus(for issueID: String) {
        if let existing = sessions[issueID], existing.isActive {
            endFocus(issueID: issueID)
        } else if sessions[issueID] != nil {
            // Issue has sessions but not active — start
            startFocus(issueID: issueID)
        } else {
            // No session yet
            startFocus(issueID: issueID)
        }
    }

    /// Clear all focus data for an issue (e.g. when issue is closed).
    func clearSession(for issueID: String) {
        sessions.removeValue(forKey: issueID)
        let url = fileURL(for: issueID)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Persistence

    private func persist(_ session: FocusSessionData) {
        do {
            try ensureRootExists()
            let data = try encoder.encode(session)
            try data.write(to: fileURL(for: session.issueID), options: .atomic)
            sessions[session.issueID] = session
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