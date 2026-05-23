import SwiftUI

/// Full timeline view with dashboard panels for the Run Console.
/// Contains tabs: Timeline, Problems, Files, Raw Log.
struct AgentRunTimelineFullView: View {
    @Bindable var appVM: AppViewModel
    let runID: UUID
    let issueID: String

    @State private var selectedTab: TimelineDetailTab = .timeline
    @State private var searchText: String = ""
    @State private var selectedFilter: TimelineEventFilter = .all

    private var events: [AgentTimelineEvent] {
        AgentTimelineStore.shared.events(forRunID: runID)
    }

    private var filteredEvents: [AgentTimelineEvent] {
        var result = events

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { event in
                event.title.lowercased().contains(query) ||
                (event.subtitle?.lowercased().contains(query) ?? false)
            }
        }

        // Apply type filter
        result = result.filter { event in
            switch selectedFilter {
            case .all: return true
            case .commands: return event.type == .command
            case .builds: return event.type == .build
            case .tests: return event.type == .test
            case .problems: return event.type == .problem
            case .approvals: return event.type == .needsApproval || event.type == .approvalResolved
            }
        }

        return result
    }

    private var problems: [AgentRunProblem] {
        AgentTimelineStore.shared.problems(forRunID: runID)
    }

    private var fileChangeEvents: [AgentTimelineEvent] {
        events.filter { $0.type == .fileChange }
    }

    private var commands: [TimelineCommandRun] {
        AgentTimelineStore.shared.commands(forRunID: runID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tab bar
            timelineTabBar

            // Search bar (only for Timeline tab)
            if selectedTab == .timeline {
                searchBar
                filterChips
            }

            // Tab content
            tabContent
        }
    }

    // MARK: - Tab Bar

    private var timelineTabBar: some View {
        HStack(spacing: 6) {
            ForEach(TimelineDetailTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        selectedTab = tab
                    }
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? WorkstationTheme.textPrimary : WorkstationTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(selectedTab == tab ? WorkstationTheme.card : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))

                if tab != TimelineDetailTab.allCases.last {
                    Spacer()
                }
            }
        }
        .padding(4)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textMuted)

            TextField("Search events...", text: $searchText)
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(WorkstationTheme.inputBg)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimelineEventFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
        }
    }

    private func filterChip(_ filter: TimelineEventFilter) -> some View {
        let isActive = selectedFilter == filter
        let count = countForFilter(filter)

        return Button {
            withAnimation(.easeOut(duration: 0.12)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                Text(filter.title)
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(isActive ? filterActiveColor(filter) : WorkstationTheme.textMuted)
                }
            }
            .foregroundStyle(isActive ? filterActiveColor(filter) : WorkstationTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? filterActiveColor(filter).opacity(0.15) : WorkstationTheme.cardAlt)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(isActive ? filterActiveColor(filter).opacity(0.5) : WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func countForFilter(_ filter: TimelineEventFilter) -> Int {
        switch filter {
        case .all: return events.count
        case .commands: return events.filter { $0.type == .command }.count
        case .builds: return events.filter { $0.type == .build }.count
        case .tests: return events.filter { $0.type == .test }.count
        case .problems: return events.filter { $0.type == .problem }.count
        case .approvals: return events.filter { $0.type == .needsApproval || $0.type == .approvalResolved }.count
        }
    }

    private func filterActiveColor(_ filter: TimelineEventFilter) -> Color {
        switch filter {
        case .all: return WorkstationTheme.accent
        case .commands: return WorkstationTheme.accent
        case .builds: return WorkstationTheme.orange
        case .tests: return WorkstationTheme.blue
        case .problems: return WorkstationTheme.red
        case .approvals: return WorkstationTheme.purple
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .timeline:
            timelineContent
        case .problems:
            problemsContent
        case .files:
            filesContent
        case .rawLog:
            rawLogContent
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if filteredEvents.isEmpty {
                    emptyStateMessage("No events match your search", systemImage: "waveform.path.ecg")
                } else {
                    ForEach(Array(filteredEvents.enumerated()), id: \.element.stableKey) { index, event in
                        timelineEventRow(event, isLast: index == filteredEvents.count - 1)
                    }
                }
            }
        }
        .frame(maxHeight: 500)
    }

    private func timelineEventRow(_ event: AgentTimelineEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Connector line + status indicator
            VStack(spacing: 0) {
                if indexOf(event) > 0 {
                    Rectangle()
                        .fill(WorkstationTheme.borderSoft)
                        .frame(width: 1.5, height: 8)
                } else {
                    Spacer().frame(height: 8)
                }

                statusDot(for: event)
                    .frame(width: 14, height: 14)

                if !isLast {
                    Rectangle()
                        .fill(WorkstationTheme.borderSoft)
                        .frame(width: 1.5, height: 8)
                }
            }
            .frame(width: 14)

            // Event content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textPrimary)

                    Text(eventTimestamp(event))
                        .font(WorkstationTheme.Fonts.body(9))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }

                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(WorkstationTheme.Fonts.body(10))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Event type badge
            Text(event.type.rawValue)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textMuted)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(WorkstationTheme.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .padding(.vertical, 4)
    }

    private func indexOf(_ event: AgentTimelineEvent) -> Int {
        filteredEvents.firstIndex(where: { $0.stableKey == event.stableKey }) ?? 0
    }

    private func eventTimestamp(_ event: AgentTimelineEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.timestamp)
    }

    @ViewBuilder
    private func statusDot(for event: AgentTimelineEvent) -> some View {
        switch event.status {
        case .working:
            ZStack {
                Circle()
                    .fill(WorkstationTheme.accent.opacity(0.2))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(WorkstationTheme.accent)
                    .frame(width: 8, height: 8)
            }
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(WorkstationTheme.green)
                .frame(width: 14, height: 14)
                .background(WorkstationTheme.greenBg)
                .clipShape(Circle())
        case .failure:
            Image(systemName: "xmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(WorkstationTheme.red)
                .frame(width: 14, height: 14)
                .background(WorkstationTheme.redBg)
                .clipShape(Circle())
        case .warning:
            Image(systemName: "exclamationmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(WorkstationTheme.orange)
                .frame(width: 14, height: 14)
                .background(WorkstationTheme.orangeBg)
                .clipShape(Circle())
        case .info:
            Circle()
                .fill(WorkstationTheme.blue)
                .frame(width: 8, height: 8)
        default:
            Circle()
                .fill(WorkstationTheme.textMuted)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Problems Content

    private var problemsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if problems.isEmpty {
                    emptyStateMessage("No problems detected", systemImage: "checkmark.circle")
                } else {
                    sectionHeader("Problems Detected", systemImage: "exclamationmark.triangle", color: WorkstationTheme.red)

                    ForEach(Array(problems.enumerated()), id: \.element.stableKey) { index, problem in
                        problemRow(index: index + 1, problem: problem)
                    }
                }
            }
        }
        .frame(maxHeight: 500)
    }

    private func problemRow(index: Int, problem: AgentRunProblem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // Severity indicator
                Circle()
                    .fill(problem.severity == .error ? WorkstationTheme.red : WorkstationTheme.orange)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    // File location
                    if let filePath = problem.filePath {
                        HStack(spacing: 4) {
                            Text("\(index). \(filePath)")
                                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                                .foregroundStyle(WorkstationTheme.textPrimary)
                                .textSelection(.enabled)

                            if let line = problem.line {
                                Text(":\(line)")
                                    .font(WorkstationTheme.Fonts.body(11).monospaced())
                                    .foregroundStyle(WorkstationTheme.textSecondary)

                                if let column = problem.column {
                                    Text(":\(column)")
                                        .font(WorkstationTheme.Fonts.body(11).monospaced())
                                        .foregroundStyle(WorkstationTheme.textSecondary)
                                }
                            }
                        }
                    }

                    // Message
                    Text(problem.message)
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(3)
                }

                Spacer()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(problem.severity == .error ? WorkstationTheme.redBorder : WorkstationTheme.orangeBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    // MARK: - Files Content

    private var filesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if fileChangeEvents.isEmpty {
                    emptyStateMessage("No file changes detected", systemImage: "doc")
                } else {
                    sectionHeader("Changed Files", systemImage: "doc.on.doc", color: WorkstationTheme.accent)

                    ForEach(fileChangeEvents) { event in
                        fileChangeRow(event)
                    }
                }
            }
        }
        .frame(maxHeight: 500)
    }

    private func fileChangeRow(_ event: AgentTimelineEvent) -> some View {
        HStack(spacing: 10) {
            // Change type badge
            fileChangeBadge(event)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                if let relatedFile = event.relatedFile {
                    let url = URL(fileURLWithPath: relatedFile)
                    let fileName = url.lastPathComponent
                    let folderPath = url.deletingLastPathComponent().path

                    Text(fileName)
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textPrimary)

                    Text(folderPath)
                        .font(WorkstationTheme.Fonts.body(10))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(event.subtitle ?? "Unknown file")
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                }
            }

            Spacer()

            // Event type
            Text(event.type.rawValue)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func fileChangeBadge(_ event: AgentTimelineEvent) -> some View {
        let (label, color) = fileChangeInfo(event)

        return Text(label)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(color.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    private func fileChangeInfo(_ event: AgentTimelineEvent) -> (String, Color) {
        // Try to detect git-style status from subtitle
        if let subtitle = event.subtitle?.uppercased() {
            if subtitle.contains("CREATED") || subtitle.contains("ADDED") || subtitle.contains("A ") {
                return ("A", WorkstationTheme.green)
            } else if subtitle.contains("DELETED") || subtitle.contains("D ") {
                return ("D", WorkstationTheme.red)
            } else if subtitle.contains("RENAMED") || subtitle.contains("R ") {
                return ("R", WorkstationTheme.blue)
            }
        }
        // Default to modified
        return ("M", WorkstationTheme.orange)
    }

    // MARK: - Raw Log Content

    private var rawLogContent: some View {
        LiveTerminalDrawer(
            runID: runID,
            messages: appVM.transcriptMessages(for: runID),
            isActive: appVM.activeConsoleRunID == runID,
            onKillAgent: { appVM.killActiveAgent(runID: runID) },
            onClearLogs: { appVM.clearLiveLogs(runID: runID) }
        )
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)

            Text(title.uppercased())
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textMuted)
                .textCase(.uppercase)
                .tracking(0.7)

            Spacer()

            Text("\(problems.count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private func emptyStateMessage(_ message: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textMuted)

            Text(message)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Supporting Types

enum TimelineDetailTab: String, CaseIterable, Identifiable {
    case timeline
    case problems
    case files
    case rawLog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .problems: return "Problems"
        case .files: return "Files"
        case .rawLog: return "Raw Log"
        }
    }

    var systemImage: String {
        switch self {
        case .timeline: return "waveform.path.ecg"
        case .problems: return "exclamationmark.triangle"
        case .files: return "doc.on.doc"
        case .rawLog: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum TimelineEventFilter: String, CaseIterable {
    case all
    case commands
    case builds
    case tests
    case problems
    case approvals

    var title: String {
        switch self {
        case .all: return "All"
        case .commands: return "Commands"
        case .builds: return "Builds"
        case .tests: return "Tests"
        case .problems: return "Problems"
        case .approvals: return "Approvals"
        }
    }
}