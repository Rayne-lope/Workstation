import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("ArchiveStore")
struct ArchiveStoreTests {
    private func freshTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-store-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("partitionName parses dates correctly into quarters")
    func partitionNameParsing() {
        let date1 = "2026-05-22T14:09:45Z"
        let part1 = ArchiveStore.partitionName(for: date1)
        #expect(part1 == "2026-Q2")

        let date2 = "2025-01-15T09:00:00Z"
        let part2 = ArchiveStore.partitionName(for: date2)
        #expect(part2 == "2025-Q1")

        let date3 = "2024-12-31"
        let part3 = ArchiveStore.partitionName(for: date3)
        #expect(part3 == "2024-Q4")

        let date4 = "2023-09-30"
        let part4 = ArchiveStore.partitionName(for: date4)
        #expect(part4 == "2023-Q3")
    }

    @Test("partitionName falls back gracefully to current date for invalid or missing values")
    func partitionNameFallback() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fixedDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 23))!
        
        let partNil = ArchiveStore.partitionName(for: nil, currentDate: fixedDate)
        #expect(partNil == "2026-Q2")

        let partEmpty = ArchiveStore.partitionName(for: "", currentDate: fixedDate)
        #expect(partEmpty == "2026-Q2")

        let partInvalid = ArchiveStore.partitionName(for: "not-a-date", currentDate: fixedDate)
        #expect(partInvalid == "2026-Q2")
    }

    @Test("load() on empty workspace yields empty archived list")
    func loadEmpty() {
        let dir = freshTempDir()
        let store = ArchiveStore(workingDirectory: dir)
        store.load()
        #expect(store.archivedIssues.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test("archiveIssues moves issues to local files and calls service delete method")
    func archiveIssuesSuccessfully() async throws {
        let dir = freshTempDir()
        let store = ArchiveStore(workingDirectory: dir)

        // Make mock issues
        let issue1 = BeadIssue(
            id: "Workstation-1",
            title: "Completed Task 1",
            status: "closed",
            priority: 1,
            issueType: "task",
            closedAt: "2026-05-10T12:00:00Z"
        )
        let issue2 = BeadIssue(
            id: "Workstation-2",
            title: "Completed Task 2",
            status: "closed",
            priority: 2,
            issueType: "feature",
            closedAt: "2026-02-15T12:00:00Z"
        )

        // Stub Command Runner to simulate success on bd delete
        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["delete", "Workstation-1", "Workstation-2", "--force"], stdout: "")
        let service = BeadsService(commandRunner: runner)

        await store.archiveIssues([issue1, issue2], service: service)

        #expect(store.errorMessage == nil)
        #expect(runner.calls.count == 1)
        #expect(runner.calls[0].arguments == ["delete", "Workstation-1", "Workstation-2", "--force"])

        // Verify files are written to `.beads/archive`
        let archiveDir = dir
            .appendingPathComponent(".beads", isDirectory: true)
            .appendingPathComponent("archive", isDirectory: true)

        let q2File = archiveDir.appendingPathComponent("2026-Q2.json")
        let q1File = archiveDir.appendingPathComponent("2026-Q1.json")

        #expect(FileManager.default.fileExists(atPath: q2File.path))
        #expect(FileManager.default.fileExists(atPath: q1File.path))

        // Check content via load on a new store instance
        let newStore = ArchiveStore(workingDirectory: dir)
        newStore.load()

        #expect(newStore.archivedIssues.count == 2)
        #expect(newStore.archivedIssues.first { $0.id == "Workstation-1" }?.title == "Completed Task 1")
        #expect(newStore.archivedIssues.first { $0.id == "Workstation-2" }?.issueType == "feature")
    }

    @Test("archiveIssues deduplicates and preserves updates correctly")
    func archiveIssuesDeduplicates() async throws {
        let dir = freshTempDir()
        let store = ArchiveStore(workingDirectory: dir)

        let issue1 = BeadIssue(
            id: "Workstation-1",
            title: "Completed Task 1",
            status: "closed",
            priority: 1,
            issueType: "task",
            closedAt: "2026-05-10T12:00:00Z"
        )

        let runner = StubCommandRunner()
        runner.enqueue(arguments: ["delete", "Workstation-1", "--force"], stdout: "")
        let service = BeadsService(commandRunner: runner)

        // Archive once
        await store.archiveIssues([issue1], service: service)

        // Update issue content
        let issue1Updated = BeadIssue(
            id: "Workstation-1",
            title: "Completed Task 1 Updated",
            status: "closed",
            priority: 1,
            issueType: "task",
            closedAt: "2026-05-10T12:00:00Z"
        )

        runner.enqueue(arguments: ["delete", "Workstation-1", "--force"], stdout: "")

        // Archive again
        await store.archiveIssues([issue1Updated], service: service)

        let reader = ArchiveStore(workingDirectory: dir)
        reader.load()

        #expect(reader.archivedIssues.count == 1)
        #expect(reader.archivedIssues.first?.title == "Completed Task 1 Updated")
    }
}
