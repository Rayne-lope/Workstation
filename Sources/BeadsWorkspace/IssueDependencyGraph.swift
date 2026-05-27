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

public struct IssueDependencyGraphLayout: Sendable, Hashable {
    public struct Node: Identifiable, Sendable, Hashable {
        public let id: String
        public let x: Double
        public let y: Double
        public let layer: Int
        public let incomingCount: Int
        public let outgoingCount: Int
        public let isCriticalPath: Bool
        public let isIsolated: Bool

        public init(
            id: String,
            x: Double,
            y: Double,
            layer: Int,
            incomingCount: Int,
            outgoingCount: Int,
            isCriticalPath: Bool,
            isIsolated: Bool
        ) {
            self.id = id
            self.x = x
            self.y = y
            self.layer = layer
            self.incomingCount = incomingCount
            self.outgoingCount = outgoingCount
            self.isCriticalPath = isCriticalPath
            self.isIsolated = isIsolated
        }
    }

    public static func compute(
        issues: [BeadIssue],
        graph: IssueDependencyGraph,
        columnSpacing: Double = 260,
        rowSpacing: Double = 126,
        originX: Double = 80,
        originY: Double = 70
    ) -> [Node] {
        let issueIDs = Set(issues.map(\.id))
        let sortedIDs = issues.map(\.id).sorted()
        let criticalIDs = Set(graph.criticalPath)

        var layerMemo: [String: Int] = [:]

        func knownBlockers(for id: String) -> [String] {
            (graph.blockersMap[id] ?? []).filter { issueIDs.contains($0) }.sorted()
        }

        func layer(for id: String, visiting: Set<String> = []) -> Int {
            if let cached = layerMemo[id] {
                return cached
            }
            if visiting.contains(id) {
                return 0
            }

            let blockers = knownBlockers(for: id)
            let resolvedLayer: Int
            if blockers.isEmpty {
                resolvedLayer = 0
            } else {
                let nextVisiting = visiting.union([id])
                resolvedLayer = (blockers.map { layer(for: $0, visiting: nextVisiting) }.max() ?? -1) + 1
            }
            layerMemo[id] = resolvedLayer
            return resolvedLayer
        }

        for id in sortedIDs {
            _ = layer(for: id)
        }

        let connectedIDs = sortedIDs.filter { id in
            let incoming = knownBlockers(for: id).count
            let outgoing = (graph.adjacencyList[id] ?? []).filter { issueIDs.contains($0) }.count
            return incoming > 0 || outgoing > 0
        }
        let isolatedIDs = sortedIDs.filter { !connectedIDs.contains($0) }
        let maxConnectedLayer = connectedIDs.map { layerMemo[$0] ?? 0 }.max() ?? 0

        var rowsByLayer: [Int: [String]] = [:]
        for id in connectedIDs {
            rowsByLayer[layerMemo[id] ?? 0, default: []].append(id)
        }

        var nodes: [Node] = []
        for layerIndex in rowsByLayer.keys.sorted() {
            let ids = (rowsByLayer[layerIndex] ?? []).sorted { lhs, rhs in
                let lhsCritical = criticalIDs.contains(lhs)
                let rhsCritical = criticalIDs.contains(rhs)
                if lhsCritical != rhsCritical {
                    return lhsCritical && !rhsCritical
                }
                let lhsDegree = knownBlockers(for: lhs).count + (graph.adjacencyList[lhs] ?? []).filter { issueIDs.contains($0) }.count
                let rhsDegree = knownBlockers(for: rhs).count + (graph.adjacencyList[rhs] ?? []).filter { issueIDs.contains($0) }.count
                if lhsDegree != rhsDegree {
                    return lhsDegree > rhsDegree
                }
                return lhs < rhs
            }

            for (rowIndex, id) in ids.enumerated() {
                let outgoingCount = (graph.adjacencyList[id] ?? []).filter { issueIDs.contains($0) }.count
                let incomingCount = knownBlockers(for: id).count
                nodes.append(Node(
                    id: id,
                    x: originX + Double(layerIndex) * columnSpacing,
                    y: originY + Double(rowIndex) * rowSpacing,
                    layer: layerIndex,
                    incomingCount: incomingCount,
                    outgoingCount: outgoingCount,
                    isCriticalPath: criticalIDs.contains(id),
                    isIsolated: false
                ))
            }
        }

        let isolatedLayer = maxConnectedLayer + 1
        for (rowIndex, id) in isolatedIDs.enumerated() {
            nodes.append(Node(
                id: id,
                x: originX + Double(isolatedLayer) * columnSpacing,
                y: originY + Double(rowIndex) * rowSpacing,
                layer: isolatedLayer,
                incomingCount: 0,
                outgoingCount: 0,
                isCriticalPath: criticalIDs.contains(id),
                isIsolated: true
            ))
        }

        return nodes.sorted { lhs, rhs in
            if lhs.layer != rhs.layer {
                return lhs.layer < rhs.layer
            }
            if lhs.y != rhs.y {
                return lhs.y < rhs.y
            }
            return lhs.id < rhs.id
        }
    }
}
