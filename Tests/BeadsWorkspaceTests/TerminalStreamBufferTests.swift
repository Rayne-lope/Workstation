import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("TerminalStreamBufferTests")
struct TerminalStreamBufferTests {
    
    @Test("Slicing complete lines across chunk splits")
    func splitLineChunks() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: true)
        
        buffer.append("Hello ".data(using: .utf8)!)
        #expect(buffer.takeLines().isEmpty)
        
        buffer.append("World!\n".data(using: .utf8)!)
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "Hello World!")
        #expect(lines.first?.sequence == 1)
    }
    
    @Test("Handling partial UTF-8 multi-byte characters split across boundaries")
    func utf8MultibyteBoundaries() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: true)
        
        // 🚀 emoji is F0 9F 9A 80 in UTF-8
        let rocketBytes: [UInt8] = [0xF0, 0x9F, 0x9A, 0x80]
        
        // Append first 2 bytes
        buffer.append(Data(rocketBytes[0..<2]))
        #expect(buffer.takeLines().isEmpty)
        
        // Append remaining 2 bytes plus a newline
        buffer.append(Data(rocketBytes[2..<4] + [0x0A]))
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "🚀")
    }
    
    @Test("Folding carriage-return progress lines in clean mode")
    func carriageReturnFolding() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: true)
        
        buffer.append("Downloading 10%\r".data(using: .utf8)!)
        #expect(buffer.takeLines().isEmpty)
        
        buffer.append("Downloading 50%\r".data(using: .utf8)!)
        #expect(buffer.takeLines().isEmpty)
        
        buffer.append("Downloading 100%\n".data(using: .utf8)!)
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "Downloading 100%")
    }
    
    @Test("Carriage-return and newline splits across chunks (\\r\\n boundary)")
    func carriageReturnNewlineSplit() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: true)
        
        buffer.append("Hello\r".data(using: .utf8)!)
        #expect(buffer.takeLines().isEmpty)
        
        buffer.append("\n".data(using: .utf8)!)
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "Hello")
    }
    
    @Test("Standalone carriage-return split across chunks (folding boundary)")
    func carriageReturnStandardSplit() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: true)
        
        buffer.append("Hello\r".data(using: .utf8)!)
        #expect(buffer.takeLines().isEmpty)
        
        buffer.append("World\n".data(using: .utf8)!)
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "World")
    }
    
    @Test("Stripping ANSI escape sequences in clean mode")
    func ansiEscapeStripping() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: true)
        
        let ansiText = "\u{1B}[1mBold\u{1B}[0m and \u{1B}[31;42mColored\u{1B}[m Text\n"
        buffer.append(ansiText.data(using: .utf8)!)
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "Bold and Colored Text")
    }
    
    @Test("Stripping ANSI sequences split across chunk boundaries")
    func ansiSplitAcrossChunks() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: true)
        
        buffer.append("Hello \u{1B}[3".data(using: .utf8)!)
        #expect(buffer.takeLines().isEmpty)
        
        buffer.append("1;42mWorld\u{1B}[0".data(using: .utf8)!)
        #expect(buffer.takeLines().isEmpty)
        
        buffer.append("m!\n".data(using: .utf8)!)
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "Hello World!")
    }
    
    @Test("Preserving ANSI escape sequences in raw mode")
    func rawModeKeepANSI() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: false)
        
        let ansiText = "\u{1B}[1mBold\u{1B}[0m\n"
        buffer.append(ansiText.data(using: .utf8)!)
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "\u{1B}[1mBold\u{1B}[0m")
    }
    
    @Test("Flushing trailing partial lines without newline")
    func flushTrailingPartialLine() {
        let runID = UUID()
        let buffer = TerminalStreamBuffer(runID: runID, cleanMode: true)
        
        buffer.append("Hello World".data(using: .utf8)!)
        #expect(buffer.takeLines().isEmpty)
        
        buffer.flush()
        
        let lines = buffer.takeLines()
        #expect(lines.count == 1)
        #expect(lines.first?.text == "Hello World")
    }
}
