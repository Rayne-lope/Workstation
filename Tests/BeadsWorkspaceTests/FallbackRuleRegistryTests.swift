import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("FallbackRuleRegistryTests")
struct FallbackRuleRegistryTests {
    
    @Test("Default fallback matches when command is nil or empty")
    func testDefaultFallback() {
        let generic1 = FallbackRuleRegistry.instruction(for: nil)
        #expect(generic1 == FallbackRuleRegistry.defaultInstruction)
        
        let generic2 = FallbackRuleRegistry.instruction(for: "   ")
        #expect(generic2 == FallbackRuleRegistry.defaultInstruction)
    }
    
    @Test("git push origin --delete matching")
    func testGitPushDeleteMatching() {
        let instr = FallbackRuleRegistry.instruction(for: "git push origin --delete test-branch")
        #expect(instr.contains("Remote branch deletion was rejected"))
    }
    
    @Test("git push matching")
    func testGitPushMatching() {
        let instr = FallbackRuleRegistry.instruction(for: "git push origin master")
        #expect(instr.contains("Remote push was rejected"))
    }
    
    @Test("destructive delete matching")
    func testDestructiveDeleteMatching() {
        let instr = FallbackRuleRegistry.instruction(for: "rm -rf build/")
        #expect(instr.contains("Delete was rejected"))
    }
    
    @Test("sudo / secrets / critical command matching")
    func testSudoCriticalMatching() {
        let instr = FallbackRuleRegistry.instruction(for: "sudo apt-get install curl")
        #expect(instr.contains("Critical command rejected"))
    }
    
    @Test("Fallback matches unknown command to default")
    func testUnknownCommandFallback() {
        let instr = FallbackRuleRegistry.instruction(for: "swift test")
        #expect(instr == FallbackRuleRegistry.defaultInstruction)
    }
    
    @Test("sendFallbackInstruction writes successfully to running PTY process")
    func testSendFallbackInstructionPTY() throws {
        let runID = UUID()
        let projectURL = URL(fileURLWithPath: NSTemporaryDirectory())
        
        try PTYRunner.shared.startSession(runID: runID, projectURL: projectURL, command: "cat")
        
        // Wait briefly for launch
        usleep(100000)
        
        let msg = "Hello from fallback instruction"
        let success = PTYProcessRegistry.shared.sendFallbackInstruction(for: runID, message: msg)
        #expect(success)
        
        // Wait a moment for output
        usleep(150000)
        
        if let buffer = PTYProcessRegistry.shared.buffer(for: runID) {
            let output = buffer.take()
            #expect(output.contains("Hello from fallback instruction"))
        } else {
            Issue.record("Expected terminal buffer to exist")
        }
        
        PTYProcessRegistry.shared.killProcess(for: runID)
    }
}
