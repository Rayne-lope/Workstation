import SwiftUI
import WidgetKit
#if canImport(BeadsContract)
import BeadsContract
#endif

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Theme Definition
struct Theme {
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F4F4F4")
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "111111") : Color(hex: "FFFFFF")
    }
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "141414") : Color(hex: "FFFFFF")
    }
    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "E5E5E5")
    }
    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "ECC864") : Color(hex: "111111")
    }
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "F0ECE4") : Color(hex: "111111")
    }
    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "888888") : Color(hex: "555555")
    }
    static func textMuted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "555555") : Color(hex: "999999")
    }
    static func blue(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "7DD3FC") : Color(hex: "3B82F6")
    }
    static func green(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "86EFAC") : Color(hex: "4CAF74")
    }
    static func red(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "F87171") : Color(hex: "EF4444")
    }
    static func orange(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FB923C") : Color(hex: "F97316")
    }
    static func difficultyColor(_ priority: Int, _ scheme: ColorScheme) -> Color {
        switch priority {
        case 0, 1: return accent(scheme)
        case 2: return blue(scheme)
        case 3: return textSecondary(scheme)
        case 4: return textMuted(scheme)
        default: return textMuted(scheme)
        }
    }
    static func difficultyLabel(_ priority: Int) -> String {
        switch priority {
        case 0: return "P0"
        case 1: return "P1"
        case 2: return "P2"
        case 3: return "P3"
        case 4: return "P4"
        default: return "P2"
        }
    }
}

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

// MARK: - Widget Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            state: WidgetState(
                lastUpdated: Date(),
                workspaceName: "Demo Workspace",
                workspacePath: "/path/to/demo",
                stats: WidgetState.ColumnStats(backlog: 3, ready: 5, inProgress: 2, review: 1, blocked: 0, done: 12),
                activeRun: WidgetState.ActiveRun(
                    issueID: "Workstation-piy",
                    issueTitle: "Implement Widget Extension",
                    assignee: "gemini",
                    status: "running",
                    startedAt: Date().addingTimeInterval(-180)
                ),
                needsReviewIssues: [
                    WidgetState.NeedsReviewIssue(id: "Workstation-tb4", title: "Unsafe Force-unwrap NSTextView", priority: 2, updatedAt: "2026-05-28T16:00:00Z")
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let state = loadState()
        let entry = SimpleEntry(date: Date(), state: state)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let state = loadState()
        let entry = SimpleEntry(date: Date(), state: state)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func loadState() -> WidgetState {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let fileURL = appSupport
            .appendingPathComponent("local.beads.workstation")
            .appendingPathComponent("widget_state.json")

        guard let data = try? Data(contentsOf: fileURL) else {
            return WidgetState(
                lastUpdated: Date(),
                workspaceName: "No Workspace Loaded",
                workspacePath: "",
                stats: WidgetState.ColumnStats(),
                activeRun: nil,
                needsReviewIssues: []
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(WidgetState.self, from: data)
        } catch {
            return WidgetState(
                lastUpdated: Date(),
                workspaceName: "Parse Error",
                workspacePath: "",
                stats: WidgetState.ColumnStats(),
                activeRun: nil,
                needsReviewIssues: []
            )
        }
    }
}

// MARK: - Views: Small Widget
struct SmallWidgetView: View {
    let state: WidgetState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(state.workspaceName ?? "Workstation")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.accent(colorScheme))
            }

            Spacer(minLength: 0)

            if let active = state.activeRun {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(active.issueID)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accent(colorScheme))
                        
                        // Assignee badge
                        Text(active.assignee.uppercased())
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.surface(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Theme.border(colorScheme), lineWidth: 0.5)
                            )
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }

                    Text(active.issueTitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer(minLength: 0)

                    // Status
                    if active.status == "waiting_approval" {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.orange(colorScheme))
                            Text("APPROVAL NEEDED")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.orange(colorScheme))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.orange(colorScheme).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                                .tint(Theme.accent(colorScheme))
                            Text("RUNNING...")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Active Run")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary(colorScheme))
                    
                    Text("Beads Kanban is idle")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textMuted(colorScheme))
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.green(colorScheme))
                        Text("\(state.stats.done) COMPLETED")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card(colorScheme))
    }
}

// MARK: - Views: Medium Widget
struct MediumWidgetView: View {
    let state: WidgetState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Left: Active Run / Idle Status
            VStack(alignment: .leading, spacing: 8) {
                Text(state.workspaceName ?? "Workstation")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                    .lineLimit(1)
                
                Spacer()

                if let active = state.activeRun {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(active.issueID)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.accent(colorScheme))
                            
                            Text(active.assignee.uppercased())
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Theme.surface(colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Theme.border(colorScheme), lineWidth: 0.5)
                                )
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                        }

                        Text(active.issueTitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textPrimary(colorScheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer(minLength: 4)

                        if active.status == "waiting_approval" {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.orange(colorScheme))
                                Text("AWAITING APPROVAL")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.orange(colorScheme))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.orange(colorScheme).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.6)
                                    .tint(Theme.accent(colorScheme))
                                Text("AGENT RUNNING")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary(colorScheme))
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Active Run")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                        Text("Ready for next assignment")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textMuted(colorScheme))
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Column Stats Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("KANBAN COLUMNS")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                    .tracking(0.5)

                let gridItems = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: gridItems, alignment: .leading, spacing: 8) {
                    statCell(label: "BACKLOG", count: state.stats.backlog, color: Theme.textMuted(colorScheme))
                    statCell(label: "READY", count: state.stats.ready, color: Theme.accent(colorScheme))
                    statCell(label: "IN PROGRESS", count: state.stats.inProgress, color: Theme.accent(colorScheme))
                    statCell(label: "REVIEW", count: state.stats.review, color: Theme.blue(colorScheme))
                    statCell(label: "BLOCKED", count: state.stats.blocked, color: Theme.red(colorScheme))
                    statCell(label: "DONE", count: state.stats.done, color: Theme.green(colorScheme))
                }
            }
            .frame(width: 160)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card(colorScheme))
    }

    private func statCell(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary(colorScheme))
            }
        }
    }
}

// MARK: - Views: Large Widget
struct LargeWidgetView: View {
    let state: WidgetState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Workspace Name & Kanban Stats Summary
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.workspaceName ?? "Workstation")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                    Text("CURRENT WORKSPACE")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textMuted(colorScheme))
                        .tracking(0.5)
                }

                Spacer()

                // Compact Kanban Row
                HStack(spacing: 12) {
                    miniStat(label: "RDY", count: state.stats.ready, color: Theme.accent(colorScheme))
                    miniStat(label: "WIP", count: state.stats.inProgress, color: Theme.accent(colorScheme))
                    miniStat(label: "REV", count: state.stats.review, color: Theme.blue(colorScheme))
                    miniStat(label: "DON", count: state.stats.done, color: Theme.green(colorScheme))
                }
            }

            Divider().background(Theme.border(colorScheme))

            // Active Agent Section
            if let active = state.activeRun {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(active.issueID)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.accent(colorScheme))
                            
                            Text(active.assignee.uppercased())
                                .font(.system(size: 7, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 0.5)
                                .background(Theme.surface(colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                        }

                        Text(active.issueTitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textPrimary(colorScheme))
                            .lineLimit(1)
                    }

                    Spacer()

                    if active.status == "waiting_approval" {
                        Text("AWAITING APPROVAL")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.orange(colorScheme))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.orange(colorScheme).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.5)
                                .tint(Theme.accent(colorScheme))
                            Text("RUNNING")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                        }
                    }
                }
                .padding(8)
                .background(Theme.surface(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.border(colorScheme), lineWidth: 1)
                )
            }

            // Needs Review List
            VStack(alignment: .leading, spacing: 6) {
                Text("NEEDS REVIEW (\(state.needsReviewIssues.count))")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                    .tracking(0.5)

                if state.needsReviewIssues.isEmpty {
                    VStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.green(colorScheme).opacity(0.8))
                        Text("All reviews cleared!")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 5) {
                        ForEach(state.needsReviewIssues.prefix(4), id: \.id) { issue in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.blue(colorScheme))
                                    .frame(width: 5, height: 5)

                                Text(issue.id)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary(colorScheme))

                                Text(issue.title)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary(colorScheme))
                                    .lineLimit(1)

                                Spacer()

                                Text(Theme.difficultyLabel(issue.priority))
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Theme.difficultyColor(issue.priority, colorScheme).opacity(0.12))
                                    .foregroundStyle(Theme.difficultyColor(issue.priority, colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(Theme.surface(colorScheme).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card(colorScheme))
    }

    private func miniStat(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 6, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textMuted(colorScheme))
        }
    }
}

// MARK: - Widget Entry View
struct WorkstationWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(state: entry.state)
        case .systemMedium:
            MediumWidgetView(state: entry.state)
        case .systemLarge:
            LargeWidgetView(state: entry.state)
        default:
            SmallWidgetView(state: entry.state)
        }
    }
}

// MARK: - Widget Configuration
@main
struct WorkstationWidget: Widget {
    let kind: String = "WorkstationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WorkstationWidgetEntryView(entry: entry)
                .containerBackground(Theme.card(.dark), for: .widget)
        }
        .configurationDisplayName("Workstation Monitor")
        .description("Monitor active agent runs and Kanban status on your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
