import AppKit
import SwiftUI

struct KanbanBoardView: View {
    let appVM: AppViewModel
    let store: IssueStore
    let profiles: [AgentProfile]
    var onRequestClose: (BeadIssue) -> Void = { _ in }

    @State private var hoverTargetColumn: KanbanColumn?

    private var isCompact: Bool {
        appVM.preferencesStore.preferences.kanbanCompactMode
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(KanbanColumn.allCases) { column in
                    columnView(column: column)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DotsBackground())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kanban board")
    }

    private func columnView(column: KanbanColumn) -> some View {
        let items = store.issues(in: column)
        let isTargeted = hoverTargetColumn == column
        return VStack(alignment: .leading, spacing: 10) {
            columnHeader(column: column, count: items.count)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if items.isEmpty {
                        emptyState(column: column)
                    }
                    ForEach(items) { issue in
                        Button {
                            handleCardClick(issue: issue, column: column, items: items)
                        } label: {
                            IssueCardView(
                                issue: issue,
                                appVM: appVM,
                                profiles: profiles,
                                isSelected: store.selectedIssueIDs.contains(issue.id),
                                hasUnknownStatus: store.hasUnknownStatus(issue),
                                isBlockedByDependency: store.blockedByDependencyIDs.contains(issue.id),
                                isCompact: isCompact
                            )
                        }
                        .buttonStyle(.plain)
                        .issueContextMenu(issue: issue, store: store, appVM: appVM)
                        .draggable(issue.id) {
                            IssueCardView(
                                issue: issue,
                                appVM: appVM,
                                profiles: profiles,
                                isSelected: false,
                                hasUnknownStatus: false,
                                isBlockedByDependency: false,
                                isCompact: isCompact
                            )
                            .frame(width: 280)
                            .opacity(0.7)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 300, alignment: .topLeading)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.accent, lineWidth: 2)
                .opacity(isTargeted ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: isTargeted)
                .allowsHitTesting(false)
        )
        .dropDestination(for: String.self) { droppedIDs, _ in
            guard let id = droppedIDs.first else { return false }
            return handleDrop(issueID: id, into: column)
        } isTargeted: { hovering in
            if hovering {
                hoverTargetColumn = column
            } else if hoverTargetColumn == column {
                hoverTargetColumn = nil
            }
        }
    }

    private func handleCardClick(issue: BeadIssue, column: KanbanColumn, items: [BeadIssue]) {
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        let cmd = flags.contains(.command)
        let shift = flags.contains(.shift)
        if cmd {
            store.toggleSelection(id: issue.id)
        } else if shift {
            store.selectRange(to: issue.id, within: items.map(\.id))
        } else {
            if store.hasMultiSelection && store.selectedIssueIDs.contains(issue.id) {
                if appVM.detailPaneMode != .copilot {
                    appVM.showBulkActionPane()
                }
                return
            }
            store.selectIssue(id: issue.id)
        }
        if store.hasMultiSelection {
            if appVM.detailPaneMode != .copilot {
                appVM.showBulkActionPane()
            }
        } else if appVM.detailPaneMode == .bulkAction {
            appVM.resetDetailPaneToIssue()
        }
    }

    private func handleDrop(issueID: String, into target: KanbanColumn) -> Bool {
        guard let issue = store.issues.first(where: { $0.id == issueID }) else {
            return false
        }
        let source = KanbanStateMapper.column(
            for: issue,
            readyIDs: store.readyIssueIDs,
            blockedIDs: store.blockedByDependencyIDs
        )
        switch KanbanDropResolver.action(from: source, to: target) {
        case .noop:
            return false
        case .claim:
            Task { await store.claim(id: issueID) }
            return true
        case .requestHumanReview:
            Task { await store.requestHumanReview(id: issueID) }
            return true
        case .close:
            onRequestClose(issue)
            return true
        }
    }

    private func columnHeader(column: KanbanColumn, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(WorkstationTheme.accent(for: column))
                    .frame(width: 8, height: 8)

                Text(column.rawValue.uppercased())
                    .font(WorkstationTheme.Fonts.display(12, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(WorkstationTheme.textPrimary)

                Text("\(count)")
                    .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(WorkstationTheme.borderSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))

                Spacer()
            }

            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(column.rawValue) column, \(count) issues")
    }

    private func emptyState(column: KanbanColumn) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WorkstationTheme.accent(for: column))
                .frame(width: 30, height: 30)
                .background(WorkstationTheme.card)
                .clipShape(Circle())

            Text("No issues yet")
                .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSecondary)

            Text(column.rawValue)
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(WorkstationTheme.borderStrong)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .accessibilityLabel("No issues in \(column.rawValue)")
    }
}

private struct DotsBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Pre-computed star positions for the twinkling effect.
    /// Each star has: grid position (col, row), phase offset, speed multiplier, and max radius.
    private struct Star {
        let col: Int
        let row: Int
        let phase: Double    // 0…2π offset so stars don't sync
        let speed: Double    // oscillation speed multiplier (0.3…1.2)
        let radius: CGFloat  // max glow radius (1.0…2.5)
        let isGold: Bool     // gold accent vs cool white
    }

    /// Deterministic star set — seeded from grid hash so layout is stable across redraws.
    private static let stars: [Star] = {
        var rng = SeededRNG(seed: 42)
        var result: [Star] = []
        // Generate ~24 twinkling stars scattered across a large virtual grid
        let maxCol = 120
        let maxRow = 80
        for _ in 0..<24 {
            let col = Int(rng.next() % UInt64(maxCol))
            let row = Int(rng.next() % UInt64(maxRow))
            let phase = Double(rng.next() % 10000) / 10000.0 * .pi * 2
            let speed = 0.3 + Double(rng.next() % 1000) / 1000.0 * 0.9
            let radius: CGFloat = 1.0 + CGFloat(rng.next() % 1000) / 1000.0 * 1.5
            let isGold = rng.next() % 3 == 0  // ~1/3 are gold, rest are white
            result.append(Star(col: col, row: row, phase: phase, speed: speed, radius: radius, isGold: isGold))
        }
        return result
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let spacing: CGFloat = 24.0
                let cols = Int(size.width / spacing) + 1
                let rows = Int(size.height / spacing) + 1

                // 1) Draw base dot grid — subtle, static
                let baseDot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 1.2, height: 1.2))
                for col in 0..<cols {
                    for row in 0..<rows {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        context.translateBy(x: x, y: y)
                        context.fill(baseDot, with: .color(WorkstationTheme.border))
                        context.translateBy(x: -x, y: -y)
                    }
                }

                // 2) Draw twinkling accent dots — gold in dark mode, soft green in light mode.
                for star in Self.stars {
                    guard star.col < cols, star.row < rows else { continue }
                    let x = CGFloat(star.col) * spacing
                    let y = CGFloat(star.row) * spacing

                    let brightness = (sin(now * star.speed * 1.8 + star.phase) + 1.0) / 2.0
                    guard brightness > 0.1 else { continue }

                    let glowRadius = star.radius * CGFloat(brightness)
                    let alpha = brightness * 0.75

                    // Outer soft glow
                    let glowSize = glowRadius * 4
                    let glowRect = CGRect(
                        x: x - glowSize / 2 + 0.6,
                        y: y - glowSize / 2 + 0.6,
                        width: glowSize,
                        height: glowSize
                    )

                    // Core bright dot
                    let coreSize = glowRadius * 1.5
                    let coreRect = CGRect(
                        x: x - coreSize / 2 + 0.6,
                        y: y - coreSize / 2 + 0.6,
                        width: coreSize,
                        height: coreSize
                    )

                    if colorScheme == .dark {
                        // Dark mode: gold accent stars + cool white stars (original behaviour)
                        let glowColor: Color = star.isGold
                            ? WorkstationTheme.accent.opacity(alpha * 0.3)
                            : WorkstationTheme.textPrimary.opacity(alpha * 0.15)
                        context.fill(Path(ellipseIn: glowRect), with: .color(glowColor))

                        let coreColor: Color = star.isGold
                            ? WorkstationTheme.accent.opacity(alpha * 0.8)
                            : WorkstationTheme.textPrimary.opacity(alpha * 0.6)
                        context.fill(Path(ellipseIn: coreRect), with: .color(coreColor))
                    } else {
                        // Light mode: green accent sparkles + muted gray sparkles
                        // Reduced opacity so they stay airy on the white/light canvas
                        let glowColor: Color = star.isGold
                            ? WorkstationTheme.green.opacity(alpha * 0.18)
                            : WorkstationTheme.textMuted.opacity(alpha * 0.08)
                        context.fill(Path(ellipseIn: glowRect), with: .color(glowColor))

                        let coreColor: Color = star.isGold
                            ? WorkstationTheme.green.opacity(alpha * 0.55)
                            : WorkstationTheme.textMuted.opacity(alpha * 0.30)
                        context.fill(Path(ellipseIn: coreRect), with: .color(coreColor))
                    }
                }
            }
        }
        .background(WorkstationTheme.background)
    }
}

/// Simple seeded RNG for deterministic star placement.
private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
