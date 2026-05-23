import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("AgentTimelineStoreTests")
struct AgentTimelineStoreTests {
    
    @Test("Initial store is empty")
    func initialStoreEmpty() {
        let store = AgentTimelineStore()
        
        let runID = UUID()
        #expect(store.events(forRunID: runID).isEmpty)
        #expect(store.compactEvents(forRunID: runID).isEmpty)
        #expect(store.activeApproval(forRunID: runID) == nil)
        #expect(store.problems(forRunID: runID).isEmpty)
        #expect(store.commands(forRunID: runID).isEmpty)
    }
    
    @Test("apply insert deltas and prevent duplicates")
    func applyInsertDeltas() {
        let store = AgentTimelineStore()
        let runID = UUID()
        
        let event1 = AgentTimelineEvent(
            stableKey: "event-1",
            runID: runID,
            sequence: 1,
            type: .started,
            title: "Started agent",
            status: .success,
            source: .commandLifecycle,
            confidence: .high
        )
        
        let event2 = AgentTimelineEvent(
            stableKey: "event-1", // duplicate key
            runID: runID,
            sequence: 2,
            type: .started,
            title: "Duplicate started",
            status: .success,
            source: .commandLifecycle,
            confidence: .high
        )
        
        let event3 = AgentTimelineEvent(
            stableKey: "event-2",
            runID: runID,
            sequence: 3,
            type: .command,
            title: "Running swift test",
            status: .working,
            source: .terminalRegex,
            confidence: .medium
        )
        
        store.apply(delta: .insert(event1), forRunID: runID)
        store.apply(delta: .insert(event2), forRunID: runID)
        store.apply(delta: .insert(event3), forRunID: runID)
        
        let list = store.events(forRunID: runID)
        #expect(list.count == 2)
        #expect(list.first?.title == "Started agent")
        #expect(list.last?.title == "Running swift test")
    }
    
    @Test("apply update deltas")
    func applyUpdateDeltas() {
        let store = AgentTimelineStore()
        let runID = UUID()
        
        let event = AgentTimelineEvent(
            stableKey: "event-1",
            runID: runID,
            sequence: 1,
            type: .command,
            title: "xcodebuild",
            status: .working,
            source: .terminalRegex,
            confidence: .medium
        )
        
        store.apply(delta: .insert(event), forRunID: runID)
        
        let updatedEvent = AgentTimelineEvent(
            stableKey: "event-1",
            runID: runID,
            sequence: 2,
            type: .command,
            title: "xcodebuild completed",
            status: .success,
            source: .terminalRegex,
            confidence: .high
        )
        
        store.apply(delta: .update(stableKey: "event-1", updatedEvent), forRunID: runID)
        
        let list = store.events(forRunID: runID)
        #expect(list.count == 1)
        #expect(list.first?.title == "xcodebuild completed")
        #expect(list.first?.status == .success)
    }
    
    @Test("apply problem deltas")
    func applyProblemDeltas() {
        let store = AgentTimelineStore()
        let runID = UUID()
        
        let problem = AgentRunProblem(
            stableKey: "prob-1",
            runID: runID,
            severity: .error,
            message: "Compiler error",
            source: .workstationMarker,
            confidence: .high
        )
        
        store.apply(delta: .appendProblem(problem), forRunID: runID)
        store.apply(delta: .appendProblem(problem), forRunID: runID) // duplicate should be ignored
        
        let list = store.problems(forRunID: runID)
        #expect(list.count == 1)
        #expect(list.first?.message == "Compiler error")
    }
    
    @Test("apply active approval deltas")
    func applyApprovalDeltas() {
        let store = AgentTimelineStore()
        let runID = UUID()
        
        let request = AgentApprovalRequest(
            stableKey: "app-1",
            runID: runID,
            promptHash: "abc",
            prompt: "Confirm changes?",
            proposedInput: "y\n",
            rejectInput: "n\n",
            riskLevel: .medium
        )
        
        store.apply(delta: .updateApproval(request), forRunID: runID)
        #expect(store.activeApproval(forRunID: runID)?.prompt == "Confirm changes?")
        
        store.apply(delta: .updateApproval(nil), forRunID: runID)
        #expect(store.activeApproval(forRunID: runID) == nil)
    }
    
    @Test("register command starts and ends")
    func commandRegistration() {
        let store = AgentTimelineStore()
        let runID = UUID()
        
        let cmd = TimelineCommandRun(
            stableKey: "cmd-1",
            runID: runID,
            command: "swift test"
        )
        
        store.registerCommandStart(runID: runID, command: cmd)
        #expect(store.commands(forRunID: runID).count == 1)
        #expect(store.commands(forRunID: runID).first?.status == .queued)
        
        store.registerCommandEnd(runID: runID, stableKey: "cmd-1", exitCode: 0, status: .success)
        #expect(store.commands(forRunID: runID).count == 1)
        #expect(store.commands(forRunID: runID).first?.exitCode == 0)
        #expect(store.commands(forRunID: runID).first?.status == .success)
    }
    
    @Test("clear and clearAll purges state")
    func clearAndClearAll() {
        let store = AgentTimelineStore()
        let runID1 = UUID()
        let runID2 = UUID()
        
        let event1 = AgentTimelineEvent(
            stableKey: "e-1",
            runID: runID1,
            sequence: 1,
            type: .started,
            title: "Started run 1",
            status: .success,
            source: .heuristic,
            confidence: .low
        )
        
        let event2 = AgentTimelineEvent(
            stableKey: "e-2",
            runID: runID2,
            sequence: 1,
            type: .started,
            title: "Started run 2",
            status: .success,
            source: .heuristic,
            confidence: .low
        )
        
        store.apply(delta: .insert(event1), forRunID: runID1)
        store.apply(delta: .insert(event2), forRunID: runID2)
        
        #expect(store.events(forRunID: runID1).count == 1)
        #expect(store.events(forRunID: runID2).count == 1)
        
        store.clear(forRunID: runID1)
        #expect(store.events(forRunID: runID1).isEmpty)
        #expect(store.events(forRunID: runID2).count == 1)
        
        store.clearAll()
        #expect(store.events(forRunID: runID2).isEmpty)
    }
    
    @Test("consecutive file changes collapse into a single group event")
    func consecutiveFileChangesGrouping() {
        let store = AgentTimelineStore()
        let runID = UUID()
        
        let startEvent = AgentTimelineEvent(
            stableKey: "start",
            runID: runID,
            sequence: 1,
            type: .started,
            title: "Started agent",
            status: .success,
            source: .commandLifecycle,
            confidence: .high
        )
        
        let fileEvent1 = AgentTimelineEvent(
            stableKey: "file-1",
            runID: runID,
            sequence: 2,
            type: .fileChange,
            title: "File modified",
            subtitle: "App/AppViewModel.swift",
            status: .info,
            source: .terminalRegex,
            confidence: .low
        )
        
        let fileEvent2 = AgentTimelineEvent(
            stableKey: "file-2",
            runID: runID,
            sequence: 3,
            type: .fileChange,
            title: "File modified",
            subtitle: "Sources/BeadsWorkspace/AgentTimelineIngestor.swift",
            status: .info,
            source: .gitStatus,
            confidence: .high
        )
        
        let cmdEvent = AgentTimelineEvent(
            stableKey: "cmd",
            runID: runID,
            sequence: 4,
            type: .command,
            title: "Running swift test",
            status: .working,
            source: .terminalRegex,
            confidence: .medium
        )
        
        let fileEvent3 = AgentTimelineEvent(
            stableKey: "file-3",
            runID: runID,
            sequence: 5,
            type: .fileChange,
            title: "File modified",
            subtitle: "Tests/BeadsWorkspaceTests/AgentTimelineIngestorTests.swift",
            status: .info,
            source: .fileWatcher,
            confidence: .high
        )
        
        store.apply(delta: .insert(startEvent), forRunID: runID)
        store.apply(delta: .insert(fileEvent1), forRunID: runID)
        store.apply(delta: .insert(fileEvent2), forRunID: runID)
        store.apply(delta: .insert(cmdEvent), forRunID: runID)
        store.apply(delta: .insert(fileEvent3), forRunID: runID)
        
        let grouped = store.groupedEvents(forRunID: runID)
        
        // Total should be:
        // 1. Started agent
        // 2. Modified files (2) [collapsed from file-1 and file-2]
        // 3. Running swift test
        // 4. File modified (1) [not collapsed because cmdEvent separates it]
        #expect(grouped.count == 4)
        
        #expect(grouped[0].type == .started)
        
        #expect(grouped[1].type == .fileChange)
        #expect(grouped[1].title == "Modified files (2)")
        #expect(grouped[1].subtitle == "App/AppViewModel.swift, Sources/BeadsWorkspace/AgentTimelineIngestor.swift")
        #expect(grouped[1].confidence == .high) // combines low and high -> high
        #expect(grouped[1].source == .gitStatus) // gitStatus has higher priority than terminalRegex
        
        #expect(grouped[2].type == .command)
        
        #expect(grouped[3].type == .fileChange)
        #expect(grouped[3].title == "File modified")
        #expect(grouped[3].subtitle == "Tests/BeadsWorkspaceTests/AgentTimelineIngestorTests.swift")
        #expect(grouped[3].confidence == .high)
        #expect(grouped[3].source == .fileWatcher)
    }
    
    @Test("compactEvents uses grouped events and returns the latest 5")
    func compactEventsUsesGroupedEvents() {
        let store = AgentTimelineStore()
        let runID = UUID()
        
        // Add 8 consecutive file change events
        for i in 1...8 {
            let fileEvent = AgentTimelineEvent(
                stableKey: "file-\(i)",
                runID: runID,
                sequence: Int64(i),
                type: .fileChange,
                title: "File modified",
                subtitle: "file-\(i).swift",
                status: .info,
                source: .fileWatcher,
                confidence: .high
            )
            store.apply(delta: .insert(fileEvent), forRunID: runID)
        }
        
        // All 8 consecutive file changes should collapse into 1 virtual event
        let compact = store.compactEvents(forRunID: runID)
        #expect(compact.count == 1)
        #expect(compact[0].title == "Modified files (8)")
    }
}
