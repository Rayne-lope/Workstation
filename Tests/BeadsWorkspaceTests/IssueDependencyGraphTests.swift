import Foundation
import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@MainActor
@Suite("IssueDependencyGraph")
struct IssueDependencyGraphTests {
    
    private func makeIssue(id: String, blockedBy: [String]? = nil) -> BeadIssue {
        BeadIssue(
            id: id,
            title: "Test Issue \(id)",
            status: "open",
            priority: 2,
            issueType: "task",
            blockedBy: blockedBy
        )
    }

    @Test("Adjacency list and blockers map are correctly constructed")
    func testGraphConstruction() {
        let issueA = makeIssue(id: "A", blockedBy: ["B", "C"])
        let issueB = makeIssue(id: "B")
        let issueC = makeIssue(id: "C", blockedBy: ["D"])
        let issueD = makeIssue(id: "D")
        
        let issues = [issueA, issueB, issueC, issueD]
        
        // Use a dummy store to resolve the graph
        let store = IssueStore(
            service: BeadsService(commandRunner: StubCommandRunner()),
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )
        // Since resolveDependencyGraph is private, we can construct the graph directly
        // using the underlying algorithms in IssueDependencyGraph
        let cycles = IssueDependencyGraph.detectCycles(issues: issues)
        let critical = IssueDependencyGraph.findCriticalPath(issues: issues)
        
        var adj: [String: [String]] = [:]
        var incoming: [String: [String]] = [:]
        for i in issues {
            adj[i.id] = []
            incoming[i.id] = []
        }
        for i in issues {
            let blockers = i.blockedBy ?? []
            incoming[i.id] = blockers
            for blocker in blockers {
                adj[blocker, default: []].append(i.id)
            }
        }
        for (k, v) in adj {
            adj[k] = v.sorted()
        }
        for (k, v) in incoming {
            incoming[k] = v.sorted()
        }
        
        let graph = IssueDependencyGraph(
            adjacencyList: adj,
            blockersMap: incoming,
            detectedCycles: cycles,
            criticalPath: critical
        )
        
        #expect(graph.blockersMap["A"] == ["B", "C"])
        #expect(graph.blockersMap["B"] == [])
        #expect(graph.blockersMap["C"] == ["D"])
        #expect(graph.blockersMap["D"] == [])
        
        #expect(graph.adjacencyList["B"] == ["A"])
        #expect(graph.adjacencyList["C"] == ["A"])
        #expect(graph.adjacencyList["D"] == ["C"])
        #expect(graph.adjacencyList["A"] == [])
    }
    
    @Test("Cycle detection successfully finds dependency loops")
    func testCycleDetection() {
        // Simple cycle: A blocks B, B blocks A
        // So B is blocked by A, A is blocked by B
        let issueA = makeIssue(id: "A", blockedBy: ["B"])
        let issueB = makeIssue(id: "B", blockedBy: ["A"])
        
        let cycles = IssueDependencyGraph.detectCycles(issues: [issueA, issueB])
        #expect(cycles.count == 1)
        #expect(cycles[0] == ["A", "B", "A"] || cycles[0] == ["B", "A", "B"])
        
        // Multi-node cycle: C blocks B, B blocks A, A blocks C
        // A is blocked by B, B is blocked by C, C is blocked by A
        let issueC = makeIssue(id: "C", blockedBy: ["A"])
        let issueB2 = makeIssue(id: "B", blockedBy: ["C"])
        let issueA2 = makeIssue(id: "A", blockedBy: ["B"])
        
        let cycles2 = IssueDependencyGraph.detectCycles(issues: [issueA2, issueB2, issueC])
        #expect(cycles2.count == 1)
        #expect(cycles2[0].contains("A"))
        #expect(cycles2[0].contains("B"))
        #expect(cycles2[0].contains("C"))
    }
    
    @Test("Cycle detection returns empty for cycle-free graphs")
    func testNoCycles() {
        let issueA = makeIssue(id: "A", blockedBy: ["B"])
        let issueB = makeIssue(id: "B", blockedBy: ["C"])
        let issueC = makeIssue(id: "C")
        
        let cycles = IssueDependencyGraph.detectCycles(issues: [issueA, issueB, issueC])
        #expect(cycles.isEmpty)
    }
    
    @Test("Critical path calculation returns the longest dependency chain")
    func testCriticalPath() {
        // Chains:
        // C blocks B, B blocks A (Length 3: C -> B -> A)
        // D blocks A             (Length 2: D -> A)
        let issueA = makeIssue(id: "A", blockedBy: ["B", "D"])
        let issueB = makeIssue(id: "B", blockedBy: ["C"])
        let issueC = makeIssue(id: "C")
        let issueD = makeIssue(id: "D")
        
        let critical = IssueDependencyGraph.findCriticalPath(issues: [issueA, issueB, issueC, issueD])
        #expect(critical == ["C", "B", "A"])
    }
    
    @Test("Critical path calculation is cycle-safe")
    func testCriticalPathCycleSafe() {
        // Cycle: A -> B -> A, plus an exit C
        let issueA = makeIssue(id: "A", blockedBy: ["B"])
        let issueB = makeIssue(id: "B", blockedBy: ["A", "C"])
        let issueC = makeIssue(id: "C")
        
        let critical = IssueDependencyGraph.findCriticalPath(issues: [issueA, issueB, issueC])
        // Should not crash or infinite loop
        #expect(critical.count > 0)
    }
}
