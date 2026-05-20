import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("IssueFileWatcher")
struct IssueFileWatcherTests {
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Int = 0
        func increment() {
            lock.lock(); defer { lock.unlock() }
            value += 1
        }
        var current: Int {
            lock.lock(); defer { lock.unlock() }
            return value
        }
    }

    private func makeTmpFile() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("beads-watcher-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("issues.jsonl", isDirectory: false)
        FileManager.default.createFile(atPath: file.path, contents: Data())
        return file
    }

    @Test("write to watched file fires onChange after debounce")
    func writeFiresCallback() async throws {
        let file = makeTmpFile()
        let counter = Counter()
        let watcher = IssueFileWatcher(path: file, debounce: 0.1) {
            counter.increment()
        }
        try watcher.start()
        defer { watcher.stop() }

        try Data("hello\n".utf8).append(to: file)
        try await Task.sleep(for: .milliseconds(400))

        #expect(counter.current >= 1)
    }

    @Test("Burst writes within debounce window collapse to a single callback")
    func burstCollapsesToSingle() async throws {
        let file = makeTmpFile()
        let counter = Counter()
        let watcher = IssueFileWatcher(path: file, debounce: 0.3) {
            counter.increment()
        }
        try watcher.start()
        defer { watcher.stop() }

        for i in 0..<5 {
            try Data("burst-\(i)\n".utf8).append(to: file)
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(500))

        #expect(counter.current == 1)
    }

    @Test("Two writes spaced beyond the debounce window fire twice")
    func separatedWritesFireTwice() async throws {
        let file = makeTmpFile()
        let counter = Counter()
        let watcher = IssueFileWatcher(path: file, debounce: 0.1) {
            counter.increment()
        }
        try watcher.start()
        defer { watcher.stop() }

        try Data("one\n".utf8).append(to: file)
        try await Task.sleep(for: .milliseconds(300))
        try Data("two\n".utf8).append(to: file)
        try await Task.sleep(for: .milliseconds(300))

        #expect(counter.current == 2)
    }

    @Test("start throws when the watched path does not exist")
    func failsForMissingPath() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("beads-watcher-missing-\(UUID().uuidString).jsonl")
        let watcher = IssueFileWatcher(path: missing) {}

        #expect(throws: IssueFileWatcher.WatcherError.self) {
            try watcher.start()
        }
    }

    @Test("stop() makes subsequent writes ignored")
    func stopCancelsCallbacks() async throws {
        let file = makeTmpFile()
        let counter = Counter()
        let watcher = IssueFileWatcher(path: file, debounce: 0.1) {
            counter.increment()
        }
        try watcher.start()
        watcher.stop()

        try Data("after-stop\n".utf8).append(to: file)
        try await Task.sleep(for: .milliseconds(400))

        #expect(counter.current == 0)
    }
}

private extension Data {
    func append(to url: URL) throws {
        if let handle = try? FileHandle(forWritingTo: url) {
            try handle.seekToEnd()
            try handle.write(contentsOf: self)
            try handle.close()
        } else {
            try self.write(to: url)
        }
    }
}
