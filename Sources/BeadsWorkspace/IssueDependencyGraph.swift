#if canImport(BeadsContract)
import BeadsContract
#endif
import Foundation

public struct IssueDependencyGraph: Sendable, Hashable {
    /// Maps an issue ID to the list of issue IDs that it blocks (outgoing edges: u -> [v] where u blocks v)
    public let adjacencyList: [String: [String]]
    
    /// Maps an issue ID to the list of issue IDs that block it (incoming edges: v -> [u] where u blocks v)
    public let blockersMap: [String: [String]]
    
    /// Lists all unique cycles detected in the graph. Each cycle is represented as a sequence of node IDs.
    public let detectedCycles: [[String]]
    
    /// The critical path (longest blocker chain) in the dependency graph.
    public let criticalPath: [String]
    
    public init(
        adjacencyList: [String: [String]],
        blockersMap: [String: [String]],
        detectedCycles: [[String]],
        criticalPath: [String]
    ) {
        self.adjacencyList = adjacencyList
        self.blockersMap = blockersMap
        self.detectedCycles = detectedCycles
        self.criticalPath = criticalPath
    }
    
    /// Cycle detection using DFS with visited/visiting states.
    public static func detectCycles(issues: [BeadIssue]) -> [[String]] {
        var adj: [String: Set<String>] = [:]
        for issue in issues {
            adj[issue.id] = []
        }
        for issue in issues {
            let blockers = issue.blockedBy ?? []
            for blocker in blockers {
                adj[blocker, default: []].insert(issue.id)
            }
        }
        
        var cycles: [[String]] = []
        var state: [String: Int] = [:] // 0: unvisited, 1: visiting, 2: visited
        var path: [String] = []
        var visitedCycles = Set<Set<String>>()
        
        func dfs(_ u: String) {
            state[u] = 1
            path.append(u)
            
            if let neighbors = adj[u] {
                for v in neighbors {
                    if state[v] == 1 {
                        if let index = path.firstIndex(of: v) {
                            let cyclePath = Array(path[index...]) + [v]
                            let cycleSet = Set(cyclePath)
                            if !visitedCycles.contains(cycleSet) {
                                visitedCycles.insert(cycleSet)
                                cycles.append(cyclePath)
                            }
                        }
                    } else if state[v] ?? 0 == 0 {
                        dfs(v)
                    }
                }
            }
            
            path.removeLast()
            state[u] = 2
        }
        
        for issue in issues {
            if state[issue.id] ?? 0 == 0 {
                dfs(issue.id)
            }
        }
        return cycles.sorted { $0.joined() < $1.joined() }
    }
    
    /// Longest path calculation using memoized cycle-safe DFS.
    public static func findCriticalPath(issues: [BeadIssue]) -> [String] {
        var adj: [String: Set<String>] = [:]
        for issue in issues {
            adj[issue.id] = []
        }
        for issue in issues {
            let blockers = issue.blockedBy ?? []
            for blocker in blockers {
                adj[blocker, default: []].insert(issue.id)
            }
        }
        
        var memo: [String: [String]] = [:]
        var visiting = Set<String>()
        
        func longestPath(from u: String) -> [String] {
            if let cached = memo[u] {
                return cached
            }
            if visiting.contains(u) {
                return [u]
            }
            
            visiting.insert(u)
            var maxSubpath: [String] = []
            if let neighbors = adj[u] {
                for v in neighbors {
                    let subpath = longestPath(from: v)
                    if subpath.count > maxSubpath.count {
                        maxSubpath = subpath
                    }
                }
            }
            visiting.remove(u)
            
            let result = [u] + maxSubpath
            memo[u] = result
            return result
        }
        
        var critical: [String] = []
        for issue in issues {
            let path = longestPath(from: issue.id)
            if path.count > critical.count {
                critical = path
            }
        }
        return critical
    }
}
