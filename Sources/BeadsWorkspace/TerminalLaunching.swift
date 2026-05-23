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

public final class PTYProcessRegistry: @unchecked Sendable {
    public static let shared = PTYProcessRegistry()
    
    private struct ActiveSession {
        let process: Process
        let masterFd: Int32
        let slaveFd: Int32
    }
    
    private let lock = NSLock()
    private var activeSessions: [UUID: ActiveSession] = [:]
    
    private init() {}
    
    public func register(runID: UUID, process: Process, masterFd: Int32, slaveFd: Int32) {
        lock.lock()
        defer { lock.unlock() }
        activeSessions[runID] = ActiveSession(process: process, masterFd: masterFd, slaveFd: slaveFd)
    }
    
    public func deregister(runID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if let session = activeSessions.removeValue(forKey: runID) {
            close(session.slaveFd)
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
        
        // 5. Configure Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = projectURL
        
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["CLAUDE_COLOR"] = "1"
        process.environment = env
        
        // Connect FDs using FileHandle
        let slaveHandle = FileHandle(fileDescriptor: slaveFd, closeOnDealloc: true)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle
        
        // Register in active processes registry
        PTYProcessRegistry.shared.register(runID: runID, process: process, masterFd: masterFd, slaveFd: slaveFd)
        
        // 6. Asynchronous reading loop
        let readSource = DispatchSource.makeReadSource(fileDescriptor: masterFd, queue: DispatchQueue.global(qos: .userInteractive))
        
        readSource.setEventHandler {
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            
            let bytesRead = read(masterFd, buffer, bufferSize)
            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                if let string = String(data: data, encoding: .utf8) {
                    NotificationCenter.default.post(
                        name: .ptyOutputReceived,
                        object: nil,
                        userInfo: [
                            "runID": runID,
                            "text": string
                        ]
                    )
                }
            } else {
                readSource.cancel()
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
