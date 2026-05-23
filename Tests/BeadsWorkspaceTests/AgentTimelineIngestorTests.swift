import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("AgentTimelineIngestorTests")
struct AgentTimelineIngestorTests {
    
    @Test("Ingesting sequential lines tracks sequence correctly")
    func sequentialLineTracking() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        let line1 = TerminalLine(runID: runID, sequence: 1, text: "Initial line")
        let deltas1 = ingestor.ingest(line: line1)
        #expect(!deltas1.isEmpty) // Initial start event emitted
        
        // Out of order/older sequence should be ignored
        let lineOld = TerminalLine(runID: runID, sequence: 1, text: "Old line")
        let deltasOld = ingestor.ingest(line: lineOld)
        #expect(deltasOld.isEmpty)
        
        let line2 = TerminalLine(runID: runID, sequence: 2, text: "$ swift test")
        let deltas2 = ingestor.ingest(line: line2)
        #expect(deltas2.count == 1) // Command event emitted
    }
    
    @Test("Command execution extraction and command exit updates")
    func commandAndExitParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        // Match standard zsh/bash style command
        let line1 = TerminalLine(runID: runID, sequence: 2, text: "$ swift test")
        let deltas1 = ingestor.ingest(line: line1)
        #expect(deltas1.count == 1)
        
        if case .insert(let event) = deltas1[0] {
            #expect(event.type == .command)
            #expect(event.title == "Running command")
            #expect(event.subtitle == "swift test")
            #expect(event.status == .working)
        } else {
            Issue.record("Expected .insert of command event")
        }
        
        // Exit 0 matches successful completion of active command
        let line2 = TerminalLine(runID: runID, sequence: 3, text: "completed swift test, exit 0")
        let deltas2 = ingestor.ingest(line: line2)
        #expect(deltas2.count == 1)
        
        if case .update(_, let event) = deltas2[0] {
            #expect(event.type == .command)
            #expect(event.title == "Command succeeded")
            #expect(event.status == .success)
        } else {
            Issue.record("Expected .update of active command to success")
        }
    }
    
    @Test("Swift Compiler problem extraction")
    func compilerProblemParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        // Test standard Xcode compiler error format
        let line1 = TerminalLine(runID: runID, sequence: 2, text: "Sources/BeadsWorkspace/TerminalStreamBuffer.swift:88:13: error: variable 'truncated' was never mutated")
        let deltas1 = ingestor.ingest(line: line1)
        
        // Emits .appendProblem and .insert(AgentTimelineEvent)
        #expect(deltas1.count == 2)
        
        var foundProblem = false
        var foundEvent = false
        
        for delta in deltas1 {
            switch delta {
            case .appendProblem(let problem):
                #expect(problem.severity == .error)
                #expect(problem.message == "variable 'truncated' was never mutated")
                #expect(problem.filePath == "Sources/BeadsWorkspace/TerminalStreamBuffer.swift")
                #expect(problem.line == 88)
                #expect(problem.column == 13)
                foundProblem = true
            case .insert(let event):
                #expect(event.type == .problem)
                #expect(event.status == .failure)
                #expect(event.title == "Error detected")
                foundEvent = true
            default:
                break
            }
        }
        
        #expect(foundProblem)
        #expect(foundEvent)
    }
    
    @Test("Swift test execution parsing")
    func swiftTestParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        let line = TerminalLine(runID: runID, sequence: 2, text: "Executed 340 tests, with 0 failures")
        let deltas = ingestor.ingest(line: line)
        #expect(deltas.count == 1)
        
        if case .insert(let event) = deltas[0] {
            #expect(event.type == .test)
            #expect(event.title == "Tests executed")
            #expect(event.status == .success)
        } else {
            Issue.record("Expected .insert of test event")
        }
    }
    
    @Test("Build compile step extraction")
    func buildCompileStage() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        let line = TerminalLine(runID: runID, sequence: 2, text: "CompileSwift normal arm64 Sources/App.swift")
        let deltas = ingestor.ingest(line: line)
        #expect(deltas.count == 1)
        
        if case .insert(let event) = deltas[0] {
            #expect(event.type == .build)
            #expect(event.title == "Building Workstation")
            #expect(event.subtitle == "Compiling Swift sources")
            #expect(event.status == .working)
        } else {
            Issue.record("Expected .insert of build stage event")
        }
    }
    
    @Test("Interactive approval prompt parsing and risk levels")
    func approvalPromptParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        let line = TerminalLine(runID: runID, sequence: 2, text: "Apply proposed critical changes? [y/N]")
        let deltas = ingestor.ingest(line: line)
        
        // Emits .updateApproval and .insert(AgentTimelineEvent)
        #expect(deltas.count == 2)
        
        var foundRequest = false
        var foundEvent = false
        
        for delta in deltas {
            switch delta {
            case .updateApproval(let request):
                #expect(request?.prompt == "Apply proposed critical changes? [y/N]")
                #expect(request?.riskLevel == .critical)
                #expect(request?.state == .active)
                foundRequest = true
            case .insert(let event):
                #expect(event.type == .needsApproval)
                #expect(event.status == .warning)
                #expect(event.title == "Approval required")
                foundEvent = true
            default:
                break
            }
        }
        
        #expect(foundRequest)
        #expect(foundEvent)
    }
    
    @Test("Done completion line parsing")
    func doneCompletionParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        let line = TerminalLine(runID: runID, sequence: 2, text: "Agent has completed the session.")
        let deltas = ingestor.ingest(line: line)
        #expect(deltas.count == 1)
        
        if case .insert(let event) = deltas[0] {
            #expect(event.type == .done)
            #expect(event.title == "Agent finished")
            #expect(event.status == .success)
        } else {
            Issue.record("Expected .insert of done event")
        }
    }
}
