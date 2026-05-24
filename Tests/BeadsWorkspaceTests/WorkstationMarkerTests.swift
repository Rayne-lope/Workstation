import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("WorkstationMarkerTests")
struct WorkstationMarkerTests {
    
    @Test("Phase groups (group and endgroup) parse correctly")
    func phaseGroupsParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        let startLine = TerminalLine(runID: runID, sequence: 2, text: "::workstation-json::{\"type\":\"group\",\"title\":\"Kompilasi Proyek\"}")
        let deltas1 = ingestor.ingest(line: startLine)
        #expect(deltas1.count == 1)
        
        if case .insert(let event) = deltas1[0] {
            #expect(event.type == .phase)
            #expect(event.title == "Kompilasi Proyek")
            #expect(event.status == .working)
            #expect(event.source == .workstationMarker)
            #expect(event.confidence == .high)
        } else {
            Issue.record("Expected .insert of phase event")
        }
        
        let endLine = TerminalLine(runID: runID, sequence: 3, text: "::workstation-json::{\"type\":\"endgroup\",\"title\":\"Kompilasi Proyek\"}")
        let deltas2 = ingestor.ingest(line: endLine)
        #expect(deltas2.count == 1)
        
        if case .update(_, let event) = deltas2[0] {
            #expect(event.type == .phase)
            #expect(event.title == "Kompilasi Proyek")
            #expect(event.status == .success)
        } else {
            Issue.record("Expected .update of phase event to success")
        }
    }
    
    @Test("Commands and command exits parse correctly")
    func commandsParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        let cmdLine = TerminalLine(runID: runID, sequence: 2, text: "::workstation-json::{\"type\":\"command\",\"command\":\"swift test\",\"cwd\":\"/project\"}")
        let deltas1 = ingestor.ingest(line: cmdLine)
        #expect(deltas1.count == 1)
        
        if case .insert(let event) = deltas1[0] {
            #expect(event.type == .command)
            #expect(event.subtitle == "swift test")
            #expect(event.status == .working)
        } else {
            Issue.record("Expected .insert of command event")
        }
        
        let endLine = TerminalLine(runID: runID, sequence: 3, text: "::workstation-json::{\"type\":\"commandEnd\",\"exitCode\":0}")
        let deltas2 = ingestor.ingest(line: endLine)
        #expect(deltas2.count == 1)
        
        if case .update(_, let event) = deltas2[0] {
            #expect(event.type == .command)
            #expect(event.title == "Command succeeded")
            #expect(event.status == .success)
        } else {
            Issue.record("Expected .update of command event to success")
        }
    }
    
    @Test("File changes and compiler problems parse correctly")
    func problemsAndFilesParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        // 1. File change
        let fileLine = TerminalLine(runID: runID, sequence: 2, text: "::workstation-json::{\"type\":\"fileChanged\",\"file\":\"Sources/App.swift\"}")
        let deltas1 = ingestor.ingest(line: fileLine)
        #expect(deltas1.count == 1)
        
        if case .insert(let event) = deltas1[0] {
            #expect(event.type == .fileChange)
            #expect(event.subtitle == "Sources/App.swift")
        } else {
            Issue.record("Expected .insert of file change event")
        }
        
        // 2. Problem error
        let probLine = TerminalLine(runID: runID, sequence: 3, text: "::workstation-json::{\"type\":\"problem\",\"severity\":\"error\",\"message\":\"Missing import\",\"file\":\"Sources/App.swift\",\"line\":12,\"column\":5}")
        let deltas2 = ingestor.ingest(line: probLine)
        #expect(deltas2.count == 2) // Emits .appendProblem and .insert(AgentTimelineEvent)
        
        var foundProblem = false
        var foundEvent = false
        
        for delta in deltas2 {
            switch delta {
            case .appendProblem(let problem):
                #expect(problem.severity == .error)
                #expect(problem.message == "Missing import")
                #expect(problem.filePath == "Sources/App.swift")
                #expect(problem.line == 12)
                #expect(problem.column == 5)
                foundProblem = true
            case .insert(let event):
                #expect(event.type == .problem)
                #expect(event.title == "Error detected")
                #expect(event.status == .failure)
                foundEvent = true
            default:
                break
            }
        }
        
        #expect(foundProblem)
        #expect(foundEvent)
    }
    
    @Test("Interactive approvals parse risk levels correctly")
    func approvalsParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        let appLine = TerminalLine(runID: runID, sequence: 2, text: "::workstation-json::{\"type\":\"approval\",\"prompt\":\"Erase disk?\",\"proposedInput\":\"y\\n\",\"rejectInput\":\"n\\n\",\"riskLevel\":\"critical\"}")
        let deltas = ingestor.ingest(line: appLine)
        #expect(deltas.count == 2)
        
        var foundRequest = false
        var foundEvent = false
        
        for delta in deltas {
            switch delta {
            case .updateApproval(let request):
                #expect(request?.prompt == "Erase disk?")
                #expect(request?.proposedInput == "y\r")
                #expect(request?.rejectInput == "n\r")
                #expect(request?.riskLevel == .critical)
                foundRequest = true
            case .insert(let event):
                #expect(event.type == .needsApproval)
                #expect(event.title == "Approval required")
                #expect(event.status == .warning)
                foundEvent = true
            default:
                break
            }
        }
        
        #expect(foundRequest)
        #expect(foundEvent)
    }
    
    @Test("Done and test summaries parse correctly")
    func doneAndTestsParsing() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        // 1. Test Summary
        let testLine = TerminalLine(runID: runID, sequence: 2, text: "::workstation-json::{\"type\":\"testSummary\",\"message\":\"340 tests passed\",\"exitCode\":0}")
        let deltas1 = ingestor.ingest(line: testLine)
        #expect(deltas1.count == 1)
        
        if case .insert(let event) = deltas1[0] {
            #expect(event.type == .test)
            #expect(event.subtitle == "340 tests passed")
            #expect(event.status == .success)
        } else {
            Issue.record("Expected .insert of test event")
        }
        
        // 2. Done
        let doneLine = TerminalLine(runID: runID, sequence: 3, text: "::workstation-json::{\"type\":\"done\",\"message\":\"Issue resolved\"}")
        let deltas2 = ingestor.ingest(line: doneLine)
        #expect(deltas2.count == 1)
        
        if case .insert(let event) = deltas2[0] {
            #expect(event.type == .done)
            #expect(event.subtitle == "Issue resolved")
            #expect(event.status == .success)
        } else {
            Issue.record("Expected .insert of done event")
        }
    }
    
    @Test("Malformed or oversized marker JSON strings are gracefully ignored")
    func defensiveParsingChecks() {
        let runID = UUID()
        let ingestor = AgentTimelineIngestor(runID: runID)
        
        // 1. Malformed JSON
        let malformed = TerminalLine(runID: runID, sequence: 2, text: "::workstation-json::{\"type\":\"done\", malformed json payload")
        let deltas1 = ingestor.ingest(line: malformed)
        #expect(deltas1.isEmpty)
        
        // 2. Size limits (>8KB)
        let hugePayload = String(repeating: "A", count: 9000)
        let oversized = TerminalLine(runID: runID, sequence: 3, text: "::workstation-json::{\"type\":\"done\",\"message\":\"\(hugePayload)\"}")
        let deltas2 = ingestor.ingest(line: oversized)
        #expect(deltas2.isEmpty)
    }
}
