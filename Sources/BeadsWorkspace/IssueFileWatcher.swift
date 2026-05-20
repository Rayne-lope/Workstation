import Foundation

/// Watches a single file path with `DispatchSource.makeFileSystemObjectSource`
/// and calls `onChange` after a debounce window. Handles atomic-rewrite
/// (rename/delete) by reattaching to the new inode after each event.
public final class IssueFileWatcher: @unchecked Sendable {
    public enum WatcherError: Error, LocalizedError {
        case openFailed(path: String, code: Int32)

        public var errorDescription: String? {
            switch self {
            case let .openFailed(path, code):
                return "Failed to open \(path) for watching (errno \(code))."
            }
        }
    }

    private let path: URL
    private let debounceInterval: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue: DispatchQueue

    private let lock = NSLock()
    private var source: DispatchSourceFileSystemObject?
    private var debounceTimer: DispatchSourceTimer?
    private var fileDescriptor: Int32 = -1
    private var pendingRestart: Bool = false

    public init(
        path: URL,
        debounce: TimeInterval = 0.3,
        queue: DispatchQueue = DispatchQueue(label: "beads.file-watcher", qos: .utility),
        onChange: @escaping @Sendable () -> Void
    ) {
        self.path = path
        self.debounceInterval = debounce
        self.queue = queue
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    public func start() throws {
        try lock.withLock {
            guard source == nil else { return }
            try openAndAttachLocked()
        }
    }

    public func stop() {
        lock.withLock {
            debounceTimer?.cancel()
            debounceTimer = nil
            source?.cancel()
            source = nil
            fileDescriptor = -1
            pendingRestart = false
        }
    }

    // MARK: - Locked helpers (caller holds `lock`)

    private func openAndAttachLocked() throws {
        let fd = open(path.path, O_EVTONLY)
        guard fd >= 0 else {
            throw WatcherError.openFailed(path: path.path, code: errno)
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            self?.handleEvent()
        }
        src.setCancelHandler {
            close(fd)
        }
        self.fileDescriptor = fd
        self.source = src
        src.resume()
    }

    private func handleEvent() {
        lock.withLock {
            // If file was renamed or deleted, the FD is stale — schedule a
            // restart after debounce so we re-bind to the new inode.
            if let data = source?.data, data.contains(.delete) || data.contains(.rename) {
                pendingRestart = true
            }
            armDebounceLocked()
        }
    }

    private func armDebounceLocked() {
        debounceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + debounceInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let shouldRestart: Bool = self.lock.withLock {
                self.debounceTimer = nil
                let restart = self.pendingRestart
                self.pendingRestart = false
                return restart
            }
            self.onChange()
            if shouldRestart {
                self.restart()
            }
        }
        debounceTimer = timer
        timer.resume()
    }

    private func restart() {
        lock.withLock {
            source?.cancel()
            source = nil
            fileDescriptor = -1
            // Try to reattach; if the file does not exist yet (mid-rename),
            // a single retry after 100ms is usually enough.
            do {
                try openAndAttachLocked()
            } catch {
                queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self else { return }
                    self.lock.withLock {
                        try? self.openAndAttachLocked()
                    }
                }
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
