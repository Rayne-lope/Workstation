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
        scheme == .dark ? Color(hex: "08080A") : Color(hex: "F8F9FA")
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "121216") : Color(hex: "FFFFFF")
    }
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "16161C") : Color(hex: "FFFFFF")
    }
    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "22222B") : Color(hex: "E9ECEF")
    }
    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "ECC864") : Color(hex: "D4AF37")
    }
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "F1ECE4") : Color(hex: "212529")
    }
    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "9A9A9F") : Color(hex: "495057")
    }
    static func textMuted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "5E5E64") : Color(hex: "868E96")
    }
    static func blue(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "64B5F6") : Color(hex: "1E88E5")
    }
    static func green(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "81C784") : Color(hex: "43A047")
    }
    static func red(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "E57373") : Color(hex: "E53935")
    }
    static func orange(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FFB74D") : Color(hex: "FB8C00")
    }
    static func difficultyColor(_ priority: Int, _ scheme: ColorScheme) -> Color {
        switch priority {
        case 0, 1: return red(scheme)
        case 2: return orange(scheme)
        case 3: return blue(scheme)
        case 4: return textMuted(scheme)
        default: return textSecondary(scheme)
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

// MARK: - WidgetState Extensions
extension WidgetState {
    var totalTasks: Int {
        stats.backlog + stats.ready + stats.inProgress + stats.review + stats.blocked + stats.done
    }
    
    var doneFraction: Double {
        let total = totalTasks
        guard total > 0 else { return 0.0 }
        return Double(stats.done) / Double(total)
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
        let groupID = "group.local.beads.workstation"
        let baseDir: URL
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            baseDir = containerURL
        } else {
            let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library")
            baseDir = libraryDir.appendingPathComponent("Group Containers").appendingPathComponent(groupID)
        }
        let fileURL = baseDir.appendingPathComponent("widget_state.json")

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

// MARK: - Views: Circular Progress Ring
struct CircularProgressRing: View {
    let fraction: Double
    let label: String?
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.border(colorScheme), lineWidth: 3.5)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(max(fraction, 0.0), 1.0)))
                .stroke(
                    LinearGradient(
                        colors: [Theme.accent(colorScheme), Theme.accent(colorScheme).opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accent(colorScheme).opacity(0.3), radius: 1.5)
            
            if let label = label {
                Text(label)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary(colorScheme))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Views: Premium Widget Background
struct PremiumWidgetBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            if colorScheme == .dark {
                // Pitch dark elegant gradient base
                LinearGradient(
                    colors: [Color(hex: "0B0B0D"), Color(hex: "050506")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Soft gold ambient light in the top-right corner
                RadialGradient(
                    colors: [Color(hex: "ECC864").opacity(0.04), Color.clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 130
                )
                // Soft blue ambient light in the bottom-left corner to add depth
                RadialGradient(
                    colors: [Color(hex: "64B5F6").opacity(0.02), Color.clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 100
                )
            } else {
                // Soft light gradient base
                LinearGradient(
                    colors: [Color(hex: "FAFAFC"), Color(hex: "F1F3F5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Soft amber ambient light in the top-right
                RadialGradient(
                    colors: [Color(hex: "ECC864").opacity(0.08), Color.clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 130
                )
            }
        }
    }
}

// MARK: - Views: Small Widget
struct SmallWidgetView: View {
    let state: WidgetState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Workspace Header Row
            HStack {
                Text(state.workspaceName ?? "Workstation")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "cpu")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent(colorScheme))
            }
            .padding(.bottom, 8)

            if let active = state.activeRun {
                // Active Run State
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 4) {
                        Text(active.issueID)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accent(colorScheme))
                        
                        Text(active.assignee.uppercased())
                            .font(.system(size: 7, weight: .black, design: .rounded))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.surface(colorScheme).opacity(0.6))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Theme.border(colorScheme), lineWidth: 0.5)
                            )
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }
                    
                    Text(active.issueTitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .multilineTextAlignment(.leading)
                    
                    Spacer(minLength: 0)
                    
                    // Status Badge
                    HStack {
                        if active.status == "waiting_approval" {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Theme.orange(colorScheme))
                                    .frame(width: 5, height: 5)
                                Text("AWAITING APPROVAL")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.orange(colorScheme))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.orange(colorScheme).opacity(0.12))
                            .clipShape(Capsule())
                        } else {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Theme.green(colorScheme))
                                    .frame(width: 5, height: 5)
                                Text("RUNNING")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.green(colorScheme))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.green(colorScheme).opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            } else {
                // Idle State - Beautiful Ring layout
                HStack(spacing: 10) {
                    CircularProgressRing(
                        fraction: state.doneFraction,
                        label: "\(Int(state.doneFraction * 100))%",
                        colorScheme: colorScheme
                    )
                    .frame(width: 44, height: 44)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kanban Idle")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                        
                        Text("\(state.stats.done) / \(state.totalTasks) Tasks")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textMuted(colorScheme))
                        
                        Text("Done")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.green(colorScheme))
                            .tracking(0.5)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Views: Medium Widget
struct MediumWidgetView: View {
    let state: WidgetState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            // Left Column: Active Run Info or Project Progress Ring
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(state.workspaceName ?? "Workstation")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textMuted(colorScheme))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "cpu")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.accent(colorScheme))
                }
                .padding(.bottom, 8)

                if let active = state.activeRun {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(active.issueID)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.accent(colorScheme))
                            
                            Text(active.assignee.uppercased())
                                .font(.system(size: 7, weight: .black, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Theme.surface(colorScheme).opacity(0.6))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
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

                        if active.status == "waiting_approval" {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Theme.orange(colorScheme))
                                    .frame(width: 5, height: 5)
                                Text("AWAITING APPROVAL")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.orange(colorScheme))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.orange(colorScheme).opacity(0.12))
                            .clipShape(Capsule())
                        } else {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Theme.green(colorScheme))
                                    .frame(width: 5, height: 5)
                                Text("AGENT RUNNING")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.green(colorScheme))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.green(colorScheme).opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                } else {
                    // Project Progress Ring for Idle State
                    HStack(spacing: 10) {
                        CircularProgressRing(
                            fraction: state.doneFraction,
                            label: "\(Int(state.doneFraction * 100))%",
                            colorScheme: colorScheme
                        )
                        .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Beads Idle")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary(colorScheme))
                            
                            Text("Ready for task")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textMuted(colorScheme))
                            
                            Text("\(state.stats.done) / \(state.totalTasks) Done")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.green(colorScheme))
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right Column: Column Stats Grid (2x3 Grid)
            VStack(alignment: .leading, spacing: 6) {
                Text("KANBAN BOARD")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                    .tracking(0.8)

                let gridItems = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: gridItems, alignment: .leading, spacing: 6) {
                    statCell(label: "BACKLOG", count: state.stats.backlog, color: Theme.textMuted(colorScheme), colorScheme: colorScheme)
                    statCell(label: "READY", count: state.stats.ready, color: Theme.accent(colorScheme), colorScheme: colorScheme)
                    statCell(label: "IN PROGRESS", count: state.stats.inProgress, color: Theme.accent(colorScheme), colorScheme: colorScheme)
                    statCell(label: "REVIEW", count: state.stats.review, color: Theme.blue(colorScheme), colorScheme: colorScheme)
                    statCell(label: "BLOCKED", count: state.stats.blocked, color: Theme.red(colorScheme), colorScheme: colorScheme)
                    statCell(label: "DONE", count: state.stats.done, color: Theme.green(colorScheme), colorScheme: colorScheme)
                }
            }
            .frame(width: 154)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statCell(label: String, count: Int, color: Color, colorScheme: ColorScheme) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                Text(label)
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                    .lineLimit(1)
            }
            
            Text("\(count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary(colorScheme))
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface(colorScheme).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.border(colorScheme), lineWidth: 0.5)
        )
    }
}

// MARK: - Views: Large Widget
struct LargeWidgetView: View {
    let state: WidgetState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.workspaceName ?? "Workstation")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                    
                    if let path = state.workspacePath, !path.isEmpty {
                        Text(path)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Theme.textMuted(colorScheme))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Project Progress Percentage Pill
                HStack(spacing: 4) {
                    Text("\(Int(state.doneFraction * 100))% Done")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.green(colorScheme))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.green(colorScheme).opacity(0.12))
                .clipShape(Capsule())
            }

            // Kanban stats horizontal strip
            HStack(spacing: 6) {
                miniStatCard(label: "BACKLOG", count: state.stats.backlog, color: Theme.textMuted(colorScheme))
                miniStatCard(label: "READY", count: state.stats.ready, color: Theme.accent(colorScheme))
                miniStatCard(label: "IN_PROGRESS", count: state.stats.inProgress, color: Theme.accent(colorScheme))
                miniStatCard(label: "REVIEW", count: state.stats.review, color: Theme.blue(colorScheme))
                miniStatCard(label: "BLOCKED", count: state.stats.blocked, color: Theme.red(colorScheme))
                miniStatCard(label: "DONE", count: state.stats.done, color: Theme.green(colorScheme))
            }

            // Active Agent Section / Inner Card
            if let active = state.activeRun {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ACTIVE AGENT RUN")
                            .font(.system(size: 7.5, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.accent(colorScheme))
                            .tracking(0.5)
                        
                        Spacer()
                        
                        // Status Badge
                        if active.status == "waiting_approval" {
                            Text("AWAITING APPROVAL")
                                .font(.system(size: 7.5, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.orange(colorScheme))
                        } else {
                            Text("RUNNING")
                                .font(.system(size: 7.5, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.green(colorScheme))
                        }
                    }
                    
                    HStack(alignment: .center, spacing: 6) {
                        Text(active.issueID)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary(colorScheme))
                        
                        Text(active.assignee.uppercased())
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.surface(colorScheme))
                            .clipShape(Capsule())
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                            
                        Spacer()
                    }
                    
                    Text(active.issueTitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary(colorScheme))
                        .lineLimit(1)
                }
                .padding(8)
                .background(Theme.surface(colorScheme).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.border(colorScheme), lineWidth: 0.5)
                )
            }

            // Needs Review List
            VStack(alignment: .leading, spacing: 4) {
                Text("NEEDS REVIEW (\(state.needsReviewIssues.count))")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textMuted(colorScheme))
                    .tracking(0.8)
                    .padding(.bottom, 2)

                if state.needsReviewIssues.isEmpty {
                    VStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.green(colorScheme).opacity(0.8))
                        Text("All reviews cleared")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 4) {
                        ForEach(state.needsReviewIssues.prefix(4), id: \.id) { issue in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.blue(colorScheme))
                                    .frame(width: 4.5, height: 4.5)

                                Text(issue.id)
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.accent(colorScheme))

                                Text(issue.title)
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary(colorScheme))
                                    .lineLimit(1)

                                Spacer()

                                Text(Theme.difficultyLabel(issue.priority))
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Theme.difficultyColor(issue.priority, colorScheme).opacity(0.12))
                                    .foregroundStyle(Theme.difficultyColor(issue.priority, colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .padding(.vertical, 4.5)
                            .padding(.horizontal, 6)
                            .background(Theme.surface(colorScheme).opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Theme.border(colorScheme).opacity(0.5), lineWidth: 0.5)
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func miniStatCard(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label.prefix(3))
                .font(.system(size: 6, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textMuted(colorScheme))
            
            HStack(spacing: 2) {
                Circle()
                    .fill(color)
                    .frame(width: 3.5, height: 3.5)
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary(colorScheme))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Theme.surface(colorScheme).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Theme.border(colorScheme), lineWidth: 0.5)
        )
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
                .containerBackground(for: .widget) {
                    PremiumWidgetBackground()
                }
        }
        .configurationDisplayName("Workstation Monitor")
        .description("Monitor active agent runs and Kanban status on your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
