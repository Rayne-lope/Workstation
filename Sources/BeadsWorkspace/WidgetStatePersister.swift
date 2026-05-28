#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
public final class WidgetStatePersister: Sendable {
    public static let shared = WidgetStatePersister()

    private let encoder: JSONEncoder
    private let fileManager: FileManager

    private init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        self.fileManager = .default
    }

    public func persist(
        workspaceName: String?,
        workspacePath: String?,
        issues: [BeadIssue],
        readyIssueIDs: Set<String>,
        blockedByDependencyIDs: Set<String>,
        activeRun: WidgetState.ActiveRun?
    ) {
        // Calculate column stats
        var backlog = 0
        var ready = 0
        var inProgress = 0
        var review = 0
        var blocked = 0
        var done = 0

        var needsReview: [WidgetState.NeedsReviewIssue] = []

        for issue in issues {
            let col = KanbanStateMapper.column(
                for: issue,
                readyIDs: readyIssueIDs,
                blockedIDs: blockedByDependencyIDs
            )
            switch col {
            case .backlog: backlog += 1
            case .ready: ready += 1
            case .inProgress: inProgress += 1
            case .review:
                review += 1
                needsReview.append(WidgetState.NeedsReviewIssue(
                    id: issue.id,
                    title: issue.title,
                    priority: issue.priority ?? 2,
                    updatedAt: issue.updatedAt ?? ""
                ))
            case .blocked: blocked += 1
            case .done: done += 1
            }
        }

        // Sort needsReview by priority (lower number = higher priority), then by newest updatedAt
        needsReview.sort { (a, b) -> Bool in
            if a.priority != b.priority {
                return a.priority < b.priority
            }
            return a.updatedAt > b.updatedAt
        }

        let stats = WidgetState.ColumnStats(
            backlog: backlog,
            ready: ready,
            inProgress: inProgress,
            review: review,
            blocked: blocked,
            done: done
        )

        let state = WidgetState(
            lastUpdated: Date(),
            workspaceName: workspaceName,
            workspacePath: workspacePath,
            stats: stats,
            activeRun: activeRun,
            needsReviewIssues: needsReview
        )

        do {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser
            let baseDir = appSupport.appendingPathComponent("local.beads.workstation", isDirectory: true)
            if !fileManager.fileExists(atPath: baseDir.path) {
                try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
            }
            let fileURL = baseDir.appendingPathComponent("widget_state.json", isDirectory: false)
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)

            // Notify WidgetKit
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            NSLog("WidgetStatePersister error: %@", error.localizedDescription)
        }
    }
}
