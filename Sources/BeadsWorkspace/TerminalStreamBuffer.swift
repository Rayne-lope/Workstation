import Foundation

public final class TerminalStreamBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let runID: UUID
    private let cleanMode: Bool
    
    private var sequenceCounter: Int64 = 0
    private var byteCarry = Data()
    private var lineBuffer = ""
    private var pendingCarriageReturn = false
    private var ansiState: ANSIState = .normal
    private var lines: [TerminalLine] = []
    
    private enum ANSIState: Sendable {
        case normal
        case esc
        case csi
    }
    
    public init(runID: UUID, cleanMode: Bool = true) {
        self.runID = runID
        self.cleanMode = cleanMode
    }
    
    /// Append raw bytes to the stream buffer.
    public func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        
        var combined = Data()
        if !byteCarry.isEmpty {
            combined.append(byteCarry)
            byteCarry.removeAll(keepingCapacity: true)
        }
        combined.append(data)
        
        guard !combined.isEmpty else { return }
        
        // Decode UTF-8 safely, stashing trailing incomplete bytes
        let (decodedString, carry) = safeDecodeUTF8(combined)
        self.byteCarry = carry
        
        guard !decodedString.isEmpty else { return }
        
        processCharacters(decodedString)
    }
    
    /// Retrieve and clear all currently emitted complete lines.
    public func takeLines() -> [TerminalLine] {
        lock.lock()
        defer { lock.unlock() }
        let current = lines
        lines.removeAll(keepingCapacity: true)
        return current
    }
    
    /// Flush any remaining partial line as a final TerminalLine.
    public func flush() {
        lock.lock()
        defer { lock.unlock() }
        
        if pendingCarriageReturn {
            // Standalone carriage return folds/clears current line
            lineBuffer = ""
            pendingCarriageReturn = false
        }
        
        if !lineBuffer.isEmpty {
            sequenceCounter += 1
            let terminalLine = TerminalLine(
                runID: runID,
                sequence: sequenceCounter,
                text: lineBuffer,
                timestamp: Date()
            )
            lines.append(terminalLine)
            lineBuffer = ""
        }
    }
    
    private func safeDecodeUTF8(_ data: Data) -> (String, Data) {
        if let str = String(data: data, encoding: .utf8) {
            return (str, Data())
        }
        
        // Try dropping up to 3 bytes from the end to find a valid UTF-8 boundary
        let truncated = data
        for drop in 1...min(3, truncated.count) {
            let candidate = truncated.dropLast(drop)
            if let str = String(data: candidate, encoding: .utf8) {
                let carry = truncated.suffix(drop)
                return (str, carry)
            }
        }
        
        // If it's completely undecodable, just return empty and keep the bytes
        return ("", data)
    }
    
    private func processCharacters(_ text: String) {
        let chars = Array(text)
        var idx = 0
        
        while idx < chars.count {
            let char = chars[idx]
            idx += 1
            
            // ANSI Stripping in Clean Mode
            if cleanMode {
                switch ansiState {
                case .normal:
                    if char == "\u{1B}" {
                        ansiState = .esc
                        continue
                    }
                case .esc:
                    if char == "[" {
                        ansiState = .csi
                    } else {
                        ansiState = .normal
                    }
                    continue
                case .csi:
                    if let ascii = char.asciiValue, ascii >= 0x40 && ascii <= 0x7E {
                        ansiState = .normal
                    }
                    continue
                }
            }
            
            // Carriage return and line feed handling
            if pendingCarriageReturn {
                if char == "\n" {
                    // It was a \r\n, skip the carriage return effect
                    pendingCarriageReturn = false
                } else {
                    // It was a standalone carriage return, fold/overwrite the line
                    lineBuffer = ""
                    pendingCarriageReturn = false
                }
            }
            
            if char == "\r" {
                pendingCarriageReturn = true
            } else if char == "\n" {
                // Emit current line
                sequenceCounter += 1
                let terminalLine = TerminalLine(
                    runID: runID,
                    sequence: sequenceCounter,
                    text: lineBuffer,
                    timestamp: Date()
                )
                lines.append(terminalLine)
                lineBuffer = ""
            } else {
                lineBuffer.append(char)
            }
        }
    }
}
