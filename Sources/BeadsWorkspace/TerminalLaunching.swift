import Foundation
import Darwin

public protocol TerminalLaunching: Sendable {
    func openTerminal(at projectURL: URL, command: String?, runID: UUID?) throws
}

public extension TerminalLaunching {
    func openTerminal(at projectURL: URL, command: String?) throws {
        try openTerminal(at: projectURL, command: command, runID: nil)
    }
}

public enum PTYError: LocalizedError, Sendable {
    case openFailed
    case grantFailed
    case unlockFailed
    case ptsnameFailed
    case openSlaveFailed
    
    public var errorDescription: String? {
        switch self {
        case .openFailed: return "Failed to open PTY master."
        case .grantFailed: return "Failed to grant PTY slave permissions."
        case .unlockFailed: return "Failed to unlock PTY slave."
        case .ptsnameFailed: return "Failed to get PTY slave name."
        case .openSlaveFailed: return "Failed to open PTY slave file descriptor."
        }
    }
}

public extension Notification.Name {
    static let ptyOutputReceived = Notification.Name("beads.pty.outputReceived")
    static let ptyProcessTerminated = Notification.Name("beads.pty.processTerminated")
}

public final class TerminalBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    
    public init() {}
    
    public func append(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer += text
    }
    
    public func take() -> String {
        lock.lock()
        defer { lock.unlock() }
        let current = buffer
        buffer = ""
        return current
    }
    
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return buffer.isEmpty
    }
}

public final class PTYProcessRegistry: @unchecked Sendable {
    public static let shared = PTYProcessRegistry()
    
    private struct ActiveSession {
        let process: Process
        let masterFd: Int32
        let slaveFd: Int32
        let buffer: TerminalBuffer
    }
    
    private let lock = NSLock()
    private var activeSessions: [UUID: ActiveSession] = [:]
    private var deadBuffers: [UUID: TerminalBuffer] = [:]
    
    private init() {}
    
    public func register(runID: UUID, process: Process, masterFd: Int32, slaveFd: Int32) {
        lock.lock()
        defer { lock.unlock() }
        let buffer = TerminalBuffer()
        activeSessions[runID] = ActiveSession(process: process, masterFd: masterFd, slaveFd: slaveFd, buffer: buffer)
        deadBuffers.removeValue(forKey: runID)
    }
    
    public func deregister(runID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if let session = activeSessions.removeValue(forKey: runID) {
            close(session.slaveFd)
            deadBuffers[runID] = session.buffer
        }
    }
    
    public func killProcess(for runID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard let session = activeSessions.removeValue(forKey: runID) else { return }
        
        let pid = session.process.processIdentifier
        if pid > 0 {
            kill(-pid, SIGINT)
            kill(pid, SIGINT)
        }
        
        session.process.terminate()
        close(session.slaveFd)
        deadBuffers[runID] = session.buffer
    }

    public func buffer(for runID: UUID) -> TerminalBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return activeSessions[runID]?.buffer ?? deadBuffers[runID]
    }

    public func removeBuffer(for runID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        deadBuffers.removeValue(forKey: runID)
    }

    /// Notify the subprocess of a new terminal column/row size (TIOCSWINSZ).
    /// Call this whenever the embedded console panel is resized.
    public func resizeTerminal(for runID: UUID, cols: UInt16, rows: UInt16) {
        lock.lock()
        defer { lock.unlock() }
        guard let session = activeSessions[runID] else { return }
        var ws = winsize()
        ws.ws_col = cols
        ws.ws_row = rows
        ws.ws_xpixel = 0
        ws.ws_ypixel = 0
        _ = ioctl(session.masterFd, TIOCSWINSZ, &ws)
    }

    /// Send input string (stdin) directly to the running process master FD.
    @discardableResult
    public func writeInput(for runID: UUID, text: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let session = activeSessions[runID] else { return false }
        
        guard let data = text.data(using: .utf8), !data.isEmpty else { return true }
        
        let masterFd = session.masterFd
        return data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            let bytesWritten = write(masterFd, baseAddress, data.count)
            return bytesWritten >= 0
        }
    }
}

public final class PTYRunner: @unchecked Sendable {
    public static let shared = PTYRunner()
    
    private init() {}
    
    public func startSession(
        runID: UUID,
        projectURL: URL,
        command: String
    ) throws {
        // 1. Open master PTY
        let masterFd = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterFd >= 0 else {
            throw PTYError.openFailed
        }
        
        // 2. Grant and unlock slave PTY
        guard grantpt(masterFd) == 0 else {
            close(masterFd)
            throw PTYError.grantFailed
        }
        guard unlockpt(masterFd) == 0 else {
            close(masterFd)
            throw PTYError.unlockFailed
        }
        
        // 3. Get slave path
        guard let namePtr = ptsname(masterFd) else {
            close(masterFd)
            throw PTYError.ptsnameFailed
        }
        let slavePath = String(cString: namePtr)
        
        // 4. Open slave FD
        let slaveFd = open(slavePath, O_RDWR | O_NOCTTY)
        guard slaveFd >= 0 else {
            close(masterFd)
            throw PTYError.openSlaveFailed
        }
        
        // Make masterFd non-blocking
        let flags = fcntl(masterFd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(masterFd, F_SETFL, flags | O_NONBLOCK)
        }
        
        // 5. Configure Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = projectURL
        
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"
        env["CLICOLOR"] = "0"
        env["CLICOLOR_FORCE"] = "0"
        env["FORCE_COLOR"] = "0"
        env["CLAUDE_COLOR"] = "0"
        process.environment = env
        
        // Connect FDs using FileHandle
        let slaveHandle = FileHandle(fileDescriptor: slaveFd, closeOnDealloc: true)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle
        
        // Register in active processes registry
        PTYProcessRegistry.shared.register(runID: runID, process: process, masterFd: masterFd, slaveFd: slaveFd)

        // Set initial terminal window size (220 cols × 50 rows matches a typical wide console)
        var ws = winsize()
        ws.ws_col = 220
        ws.ws_row = 50
        ws.ws_xpixel = 0
        ws.ws_ypixel = 0
        _ = ioctl(masterFd, TIOCSWINSZ, &ws)

        // UTF-8 carry-over buffer for incomplete multibyte sequences
        let utf8Carry = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
        utf8Carry.initialize(repeating: 0, count: 4)
        var carryCount = 0
        
        // 6. Asynchronous reading loop
        let readSource = DispatchSource.makeReadSource(fileDescriptor: masterFd, queue: DispatchQueue.global(qos: .userInteractive))

        readSource.setEventHandler {
            var combined = Data()
            if carryCount > 0 {
                combined.append(utf8Carry, count: carryCount)
                carryCount = 0
            }
            
            let bufferSize = 8192
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            
            var shouldCancel = false
            while true {
                let bytesRead = read(masterFd, buffer, bufferSize)
                if bytesRead > 0 {
                    combined.append(buffer, count: bytesRead)
                } else if bytesRead == 0 {
                    // EOF
                    shouldCancel = true
                    break
                } else {
                    let err = errno
                    if err == EAGAIN || err == EWOULDBLOCK {
                        // No more data available right now
                        break
                    } else if err == EINTR {
                        // Interrupted, try again
                        continue
                    } else {
                        // Error
                        shouldCancel = true
                        break
                    }
                }
            }
            
            if !combined.isEmpty {
                // Attempt to decode; if trailing bytes are incomplete, stash them
                if let string = String(data: combined, encoding: .utf8) {
                    if let buffer = PTYProcessRegistry.shared.buffer(for: runID) {
                        buffer.append(string)
                    }
                } else {
                    // Try stripping 1-3 trailing bytes until valid UTF-8
                    var truncated = combined
                    for drop in 1...min(3, truncated.count) {
                        let candidate = truncated.dropLast(drop)
                        if let str = String(data: Data(candidate), encoding: .utf8) {
                            let tail = truncated.suffix(drop)
                            carryCount = min(drop, 4)
                            tail.copyBytes(to: utf8Carry, count: carryCount)
                            if let buffer = PTYProcessRegistry.shared.buffer(for: runID) {
                                buffer.append(str)
                            }
                            break
                        }
                    }
                }
            }
            
            if shouldCancel {
                readSource.cancel()
                utf8Carry.deallocate()
            }
        }
        
        readSource.setCancelHandler {
            close(masterFd)
        }
        
        // Set termination handler
        process.terminationHandler = { _ in
            readSource.cancel()
            PTYProcessRegistry.shared.deregister(runID: runID)
            
            NotificationCenter.default.post(
                name: .ptyProcessTerminated,
                object: nil,
                userInfo: [
                    "runID": runID,
                    "exitCode": Int(process.terminationStatus)
                ]
            )
        }
        
        // Launch process
        do {
            try process.run()
            readSource.resume()
        } catch {
            readSource.cancel()
            close(slaveFd)
            PTYProcessRegistry.shared.deregister(runID: runID)
            throw error
        }
    }
}
