import SwiftUI

struct IssueDependencyGraphCanvasView: View {
    let appVM: AppViewModel
    let store: IssueStore

    @State private var zoom: CGFloat = 1.0
    @GestureState private var magnifyScale: CGFloat = 1.0

    private let nodeSize = CGSize(width: 228, height: 96)
    private let canvasPadding: CGFloat = 120

    private var effectiveZoom: CGFloat {
        min(2.0, max(0.4, zoom * magnifyScale))
    }

    private var graph: IssueDependencyGraph {
        store.dependencyGraph ?? IssueDependencyGraph(
            adjacencyList: [:],
            blockersMap: [:],
            detectedCycles: [],
            criticalPath: []
        )
    }

    private var issues: [BeadIssue] {
        store.filteredIssues
    }

    private var issueByID: [String: BeadIssue] {
        Dictionary(uniqueKeysWithValues: issues.map { ($0.id, $0) })
    }

    private var nodes: [IssueDependencyGraphLayout.Node] {
        IssueDependencyGraphLayout.compute(
            issues: issues,
            graph: graph,
            columnSpacing: 292,
            rowSpacing: 138
        )
    }

    private var nodeByID: [String: IssueDependencyGraphLayout.Node] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }

    private var edges: [(from: String, to: String)] {
        let visibleIDs = Set(issues.map(\.id))
        let allEdges: [(from: String, to: String)] = graph.adjacencyList.flatMap { source, targets in
            targets.map { target in (from: source, to: target) }
        }
        let visible = allEdges.filter { visibleIDs.contains($0.from) && visibleIDs.contains($0.to) }
        return visible.sorted { lhs, rhs in
            if lhs.from != rhs.from { return lhs.from < rhs.from }
            return lhs.to < rhs.to
        }
    }

    private var canvasSize: CGSize {
        let maxX = nodes.map { CGFloat($0.x) }.max() ?? 0
        let maxY = nodes.map { CGFloat($0.y) }.max() ?? 0
        return CGSize(
            width:  max(900,  maxX + nodeSize.width  + canvasPadding),
            height: max(560,  maxY + nodeSize.height + canvasPadding)
        )
    }

    private var criticalEdgePairs: Set<String> {
        guard graph.criticalPath.count >= 2 else { return [] }
        var pairs = Set<String>()
        for i in 0..<(graph.criticalPath.count - 1) {
            pairs.insert("\(graph.criticalPath[i])->\(graph.criticalPath[i + 1])")
        }
        return pairs
    }

    private var cycleNodeIDs: Set<String> {
        Set(graph.detectedCycles.flatMap { $0 })
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            graphInfoBar

            if issues.isEmpty {
                emptyState(icon: "point.3.connected.trianglepath.dotted",
                           title: "No visible issues",
                           message: "Clear filters or reload the workspace to populate the graph.")
            } else if edges.isEmpty {
                emptyState(icon: "link.badge.plus",
                           title: "No dependency edges",
                           message: "Add blockers from issue details to see connected paths here.")
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        DotsBackground()

                        Canvas { context, _ in
                            drawEdges(in: context)
                        }

                        ForEach(nodes) { node in
                            if let issue = issueByID[node.id] {
                                GraphNodeView(
                                    issue: issue,
                                    node: node,
                                    store: store,
                                    appVM: appVM,
                                    isCycleNode: cycleNodeIDs.contains(node.id)
                                )
                                .frame(width: nodeSize.width, height: nodeSize.height)
                                .position(
                                    x: CGFloat(node.x) + nodeSize.width / 2,
                                    y: CGFloat(node.y) + nodeSize.height / 2
                                )
                            }
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .scaleEffect(effectiveZoom, anchor: .topLeading)
                    .frame(
                        width:  canvasSize.width  * effectiveZoom,
                        height: canvasSize.height * effectiveZoom,
                        alignment: .topLeading
                    )
                    .padding(24)
                    .gesture(
                        MagnificationGesture()
                            .updating($magnifyScale) { value, state, _ in state = value }
                            .onEnded { value in
                                zoom = min(2.0, max(0.4, zoom * value))
                            }
                    )
                }
                .background(WorkstationTheme.background)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkstationTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dependency graph")
    }

    // MARK: - Info Bar

    private var graphInfoBar: some View {
        HStack(spacing: 8) {
            graphChip(value: "\(issues.count)", label: "issues",     icon: "square.stack.3d.up")
            graphChip(value: "\(edges.count)",  label: "edges",      icon: "arrow.right")

            if !graph.criticalPath.isEmpty {
                graphChip(
                    value: "\(graph.criticalPath.count)",
                    label: "critical path",
                    icon: "bolt.fill",
                    tint: WorkstationTheme.accent
                )
            }

            if !graph.detectedCycles.isEmpty {
                graphChip(
                    value: "\(graph.detectedCycles.count)",
                    label: graph.detectedCycles.count == 1 ? "cycle" : "cycles",
                    icon: "exclamationmark.triangle.fill",
                    tint: WorkstationTheme.orange
                )
            }

            // Legend
            Divider().frame(height: 14).padding(.horizontal, 4)

            legendDot(color: WorkstationTheme.accent, label: "Critical")
            if !cycleNodeIDs.isEmpty {
                legendDot(color: WorkstationTheme.orange, label: "Cycle")
            }

            Spacer()

            // Zoom controls
            HStack(spacing: 2) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        zoom = min(2.0, max(0.4, zoom - 0.1))
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom out")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        zoom = 1.0
                    }
                } label: {
                    Text("\(Int(effectiveZoom * 100))%")
                        .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: 46)
                }
                .help("Reset zoom")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        zoom = min(2.0, max(0.4, zoom + 0.1))
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom in")
            }
            .buttonStyle(WorkstationGhostButtonStyle(compact: true))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(WorkstationTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WorkstationTheme.borderSoft).frame(height: 1)
        }
    }

    private func graphChip(value: String, label: String, icon: String, tint: Color = WorkstationTheme.textSecondary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(WorkstationTheme.accent)
                .frame(width: 54, height: 54)
                .background(WorkstationTheme.card)
                .clipShape(Circle())
            Text(title)
                .font(WorkstationTheme.Fonts.display(16, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Text(message)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DotsBackground())
    }

    // MARK: - Edge Drawing

    private func drawEdges(in context: GraphicsContext) {
        let nodeMap    = nodeByID
        let critPairs  = criticalEdgePairs
        let cycleIDs   = cycleNodeIDs

        for edge in edges {
            guard let source = nodeMap[edge.from],
                  let target = nodeMap[edge.to] else { continue }

            let start = CGPoint(
                x: CGFloat(source.x) + nodeSize.width,
                y: CGFloat(source.y) + nodeSize.height / 2
            )
            let end = CGPoint(
                x: CGFloat(target.x),
                y: CGFloat(target.y) + nodeSize.height / 2
            )

            let dx       = max(60, abs(end.x - start.x) * 0.42)
            let c1       = CGPoint(x: start.x + dx, y: start.y)
            let c2       = CGPoint(x: end.x   - dx, y: end.y)

            let isCritical = critPairs.contains("\(edge.from)->\(edge.to)")
            let isCycle    = !cycleIDs.isEmpty
                && cycleIDs.contains(edge.from)
                && cycleIDs.contains(edge.to)

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end, control1: c1, control2: c2)

            if isCritical {
                // Layered glow for critical-path edges
                context.stroke(path, with: .color(WorkstationTheme.accent.opacity(0.07)),
                               style: StrokeStyle(lineWidth: 14, lineCap: .round))
                context.stroke(path, with: .color(WorkstationTheme.accent.opacity(0.14)),
                               style: StrokeStyle(lineWidth: 7, lineCap: .round))
                context.stroke(path, with: .color(WorkstationTheme.accent.opacity(0.88)),
                               style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
            } else if isCycle {
                context.stroke(path, with: .color(WorkstationTheme.orange.opacity(0.78)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round,
                                                  dash: [6, 4]))
            } else {
                context.stroke(path, with: .color(WorkstationTheme.borderStrong.opacity(0.65)),
                               style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
            }

            // Filled arrowhead
            let angle: CGFloat = atan2(end.y - c2.y, end.x - c2.x)
            let arrowColor: Color = isCritical
                ? WorkstationTheme.accent.opacity(0.92)
                : (isCycle ? WorkstationTheme.orange.opacity(0.82) : WorkstationTheme.borderStrong.opacity(0.80))
            drawFilledArrow(in: context, tip: end, angle: angle,
                            size: isCritical ? 9 : 7, color: arrowColor)
        }
    }

    private func drawFilledArrow(in context: GraphicsContext, tip: CGPoint,
                                 angle: CGFloat, size: CGFloat, color: Color) {
        let spread: CGFloat = .pi / 5.5   // ~32.7° half-angle
        let p1 = CGPoint(x: tip.x - cos(angle - spread) * size,
                         y: tip.y - sin(angle - spread) * size)
        let p2 = CGPoint(x: tip.x - cos(angle + spread) * size,
                         y: tip.y - sin(angle + spread) * size)
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: p1)
        arrow.addLine(to: p2)
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }
}

// MARK: - Graph Node View

private struct GraphNodeView: View {
    let issue:      BeadIssue
    let node:       IssueDependencyGraphLayout.Node
    let store:      IssueStore
    let appVM:      AppViewModel
    let isCycleNode: Bool

    @State private var isHovering = false

    private var isSelected: Bool { store.selectedIssueIDs.contains(issue.id) }

    private var column: KanbanColumn {
        KanbanStateMapper.column(
            for: issue,
            readyIDs: store.readyIssueIDs,
            blockedIDs: store.blockedByDependencyIDs
        )
    }

    private var tone: Color {
        isCycleNode ? WorkstationTheme.orange : WorkstationTheme.accent(for: column)
    }

    var body: some View {
        Button {
            store.selectIssue(id: issue.id)
            if appVM.detailPaneMode == .bulkAction { appVM.resetDetailPaneToIssue() }
        } label: {
            HStack(spacing: 0) {
                // Colored left-edge accent bar
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(tone)
                    .frame(width: 3)

                // Card body
                VStack(alignment: .leading, spacing: 5) {
                    // Row 1: ID · status · critical bolt
                    HStack(spacing: 5) {
                        Text(issue.id)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(WorkstationTheme.textDisabled)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer(minLength: 4)

                        // Status chip
                        HStack(spacing: 3) {
                            Circle().fill(tone).frame(width: 4, height: 4)
                            Text(column.rawValue)
                                .font(WorkstationTheme.Fonts.body(9.5, weight: .semibold))
                                .foregroundStyle(tone)
                                .lineLimit(1)
                        }

                        if node.isCriticalPath {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(WorkstationTheme.accent)
                                .help("On the critical path")
                        }
                    }

                    // Row 2: Title
                    Text(issue.title)
                        .font(WorkstationTheme.Fonts.display(12.5, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(1.5)

                    Spacer(minLength: 0)

                    // Row 3: Edge stats + priority
                    HStack(spacing: 0) {
                        edgeStat(count: node.incomingCount, icon: "arrow.down.left",
                                 tooltip: "\(node.incomingCount) blocker\(node.incomingCount == 1 ? "" : "s")")
                        edgeStat(count: node.outgoingCount, icon: "arrow.up.right",
                                 tooltip: "blocks \(node.outgoingCount) issue\(node.outgoingCount == 1 ? "" : "s")")
                            .padding(.leading, 8)
                        Spacer(minLength: 0)
                        if let priority = issue.priority {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(WorkstationTheme.difficultyColor(priority))
                                    .frame(width: 4.5, height: 4.5)
                                Text("P\(priority)")
                                    .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
                                    .foregroundStyle(WorkstationTheme.textMuted)
                            }
                        }
                    }
                }
                .padding(.leading, 11)
                .padding(.trailing, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(node.isIsolated ? WorkstationTheme.cardAlt : WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(
                        isSelected
                            ? WorkstationTheme.accent
                            : (isHovering
                               ? tone.opacity(0.7)
                               : tone.opacity(node.isCriticalPath ? 0.55 : 0.28)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            // Dashed overlay for cycle members
            .overlay {
                if isCycleNode {
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                        .foregroundStyle(WorkstationTheme.orange.opacity(0.5))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
            .shadow(
                color: isSelected
                    ? WorkstationTheme.accent.opacity(0.14)
                    : (isHovering ? tone.opacity(0.12) : .clear),
                radius: isSelected ? 20 : 12,
                x: 0, y: 6
            )
        }
        .buttonStyle(.plain)
        .offset(y: isHovering ? -2 : 0)
        .accessibilityLabel("Issue \(issue.id), \(issue.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .help("\(issue.id): \(issue.title)")
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.spring(response: 0.22, dampingFraction: 0.55), value: isHovering)
        .animation(.spring(response: 0.28, dampingFraction: 0.60), value: isSelected)
    }

    private func edgeStat(count: Int, icon: String, tooltip: String) -> some View {
        Label("\(count)", systemImage: icon)
            .font(WorkstationTheme.Fonts.body(9.5, weight: .semibold))
            .foregroundStyle(count > 0 ? WorkstationTheme.textMuted : WorkstationTheme.textDisabled)
            .help(tooltip)
    }
}
