import SwiftUI

struct IssueDependencyGraphCanvasView: View {
    let appVM: AppViewModel
    let store: IssueStore

    @State private var zoom: CGFloat = 1

    private let nodeSize = CGSize(width: 210, height: 82)
    private let canvasPadding: CGFloat = 120

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
        IssueDependencyGraphLayout.compute(issues: issues, graph: graph)
    }

    private var nodeByID: [String: IssueDependencyGraphLayout.Node] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }

    private var edges: [(from: String, to: String)] {
        let visibleIDs = Set(issues.map(\.id))
        return graph.adjacencyList
            .flatMap { source, targets in
                targets.map { target in (from: source, to: target) }
            }
            .filter { visibleIDs.contains($0.from) && visibleIDs.contains($0.to) }
            .sorted { lhs, rhs in
                if lhs.from != rhs.from {
                    return lhs.from < rhs.from
                }
                return lhs.to < rhs.to
            }
    }

    private var canvasSize: CGSize {
        let maxX = nodes.map { CGFloat($0.x) }.max() ?? 0
        let maxY = nodes.map { CGFloat($0.y) }.max() ?? 0
        return CGSize(
            width: max(900, maxX + nodeSize.width + canvasPadding),
            height: max(560, maxY + nodeSize.height + canvasPadding)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            graphInfoBar

            if issues.isEmpty {
                emptyState(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: "No visible issues",
                    message: "Clear filters or reload the workspace to populate the graph."
                )
            } else if edges.isEmpty {
                emptyState(
                    icon: "link.badge.plus",
                    title: "No dependency edges",
                    message: "Add blockers from issue details to see connected paths here."
                )
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        DotsBackground()

                        Canvas { context, _ in
                            drawEdges(in: context)
                        }

                        ForEach(nodes) { node in
                            if let issue = issueByID[node.id] {
                                nodeButton(issue: issue, node: node)
                                    .frame(width: nodeSize.width, height: nodeSize.height)
                                    .position(
                                        x: CGFloat(node.x) + nodeSize.width / 2,
                                        y: CGFloat(node.y) + nodeSize.height / 2
                                    )
                            }
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .scaleEffect(zoom, anchor: .topLeading)
                    .frame(
                        width: canvasSize.width * zoom,
                        height: canvasSize.height * zoom,
                        alignment: .topLeading
                    )
                    .padding(24)
                }
                .background(WorkstationTheme.background)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkstationTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dependency graph")
    }

    private var graphInfoBar: some View {
        HStack(spacing: 12) {
            graphStat("\(issues.count)", label: "issues")
            graphStat("\(edges.count)", label: "edges")

            if !graph.criticalPath.isEmpty {
                graphStat("\(graph.criticalPath.count)", label: "critical path")
            }

            if !graph.detectedCycles.isEmpty {
                Label("\(graph.detectedCycles.count) cycles", systemImage: "exclamationmark.triangle.fill")
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.orange)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    zoom = max(0.65, zoom - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom out")

                Button {
                    zoom = 1
                } label: {
                    Text("\(Int(zoom * 100))%")
                        .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                        .frame(width: 48)
                }
                .help("Reset zoom")

                Button {
                    zoom = min(1.45, zoom + 0.1)
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
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    private func graphStat(_ value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Text(label)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
    }

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

    private func nodeButton(issue: BeadIssue, node: IssueDependencyGraphLayout.Node) -> some View {
        let isSelected = store.selectedIssueIDs.contains(issue.id)
        let column = KanbanStateMapper.column(
            for: issue,
            readyIDs: store.readyIssueIDs,
            blockedIDs: store.blockedByDependencyIDs
        )
        let tone = WorkstationTheme.accent(for: column)

        return Button {
            store.selectIssue(id: issue.id)
            if appVM.detailPaneMode == .bulkAction {
                appVM.resetDetailPaneToIssue()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(issue.id)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(tone)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 6)

                    if node.isCriticalPath {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(WorkstationTheme.accent)
                            .help("Critical path")
                    }

                    Text(column.rawValue)
                        .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                        .foregroundStyle(tone)
                        .lineLimit(1)
                }

                Text(issue.title)
                    .font(WorkstationTheme.Fonts.display(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Label("\(node.incomingCount)", systemImage: "arrow.down.left")
                        .help("Blockers")
                    Label("\(node.outgoingCount)", systemImage: "arrow.up.right")
                        .help("Issues blocked by this issue")
                    if let priority = issue.priority {
                        Text("P\(priority)")
                    }
                    Spacer(minLength: 0)
                }
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(node.isIsolated ? WorkstationTheme.cardAlt : WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(isSelected ? WorkstationTheme.accent : tone.opacity(node.isCriticalPath ? 0.65 : 0.35), lineWidth: isSelected ? 1.8 : 1)
            )
            .shadow(color: isSelected ? WorkstationTheme.accent.opacity(0.12) : .clear, radius: 18, x: 0, y: 8)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Issue \(issue.id), \(issue.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .help("\(issue.id): \(issue.title)")
    }

    private func drawEdges(in context: GraphicsContext) {
        let nodes = nodeByID
        let criticalPairs = criticalEdgePairs()

        for edge in edges {
            guard let source = nodes[edge.from], let target = nodes[edge.to] else {
                continue
            }

            let start = CGPoint(
                x: CGFloat(source.x) + nodeSize.width,
                y: CGFloat(source.y) + nodeSize.height / 2
            )
            let end = CGPoint(
                x: CGFloat(target.x),
                y: CGFloat(target.y) + nodeSize.height / 2
            )
            let distance = max(70, abs(end.x - start.x) * 0.45)
            let c1 = CGPoint(x: start.x + distance, y: start.y)
            let c2 = CGPoint(x: end.x - distance, y: end.y)
            let isCritical = criticalPairs.contains("\(edge.from)->\(edge.to)")

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end, control1: c1, control2: c2)

            context.stroke(
                path,
                with: .color(isCritical ? WorkstationTheme.accent.opacity(0.86) : WorkstationTheme.borderStrong.opacity(0.9)),
                style: StrokeStyle(lineWidth: isCritical ? 2.2 : 1.4, lineCap: .round, lineJoin: .round)
            )

            drawArrowHead(in: context, at: end, from: c2, isCritical: isCritical)
        }
    }

    private func drawArrowHead(in context: GraphicsContext, at end: CGPoint, from control: CGPoint, isCritical: Bool) {
        let angle = atan2(end.y - control.y, end.x - control.x)
        let length: CGFloat = isCritical ? 10 : 8
        let spread: CGFloat = .pi / 7
        let p1 = CGPoint(
            x: end.x - cos(angle - spread) * length,
            y: end.y - sin(angle - spread) * length
        )
        let p2 = CGPoint(
            x: end.x - cos(angle + spread) * length,
            y: end.y - sin(angle + spread) * length
        )

        var arrow = Path()
        arrow.move(to: end)
        arrow.addLine(to: p1)
        arrow.move(to: end)
        arrow.addLine(to: p2)
        context.stroke(
            arrow,
            with: .color(isCritical ? WorkstationTheme.accent.opacity(0.9) : WorkstationTheme.borderStrong),
            style: StrokeStyle(lineWidth: isCritical ? 2.2 : 1.4, lineCap: .round, lineJoin: .round)
        )
    }

    private func criticalEdgePairs() -> Set<String> {
        guard graph.criticalPath.count >= 2 else {
            return []
        }

        var pairs = Set<String>()
        for index in 0..<(graph.criticalPath.count - 1) {
            pairs.insert("\(graph.criticalPath[index])->\(graph.criticalPath[index + 1])")
        }
        return pairs
    }
}
