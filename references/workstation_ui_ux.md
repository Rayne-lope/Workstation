import SwiftUI

// MARK: - Craftboard Style Guide
// Source visual system: dark productivity/Kanban dashboard with warm gold accent.
// Core principles:
// 1. Dark, low-contrast surfaces with clear border separation.
// 2. Gold accent only for focus, progress, active state, and primary actions.
// 3. Soft motion: 150-350 ms, ease-out, small translate/scale changes.
// 4. Compact density: small labels, tight cards, rounded 6-12 pt corners.
// 5. Typography pairing in original code: Syne for display/title, DM Sans for UI/body.
//    In SwiftUI, use system rounded fonts by default. Replace with custom fonts if bundled.

// MARK: - Design Tokens

enum CraftboardTheme {
    enum ColorToken {
        static let background = Color(hex: "0F0F0F")
        static let surface = Color(hex: "111111")
        static let card = Color(hex: "141414")
        static let cardAlt = Color(hex: "151515")
        static let border = Color(hex: "1E1E1E")
        static let borderSoft = Color(hex: "1A1A1A")
        static let borderStrong = Color(hex: "2A2A2A")

        static let textPrimary = Color(hex: "F0ECE4")
        static let textSecondary = Color(hex: "888888")
        static let textMuted = Color(hex: "555555")
        static let textDisabled = Color(hex: "333333")

        static let accent = Color(hex: "ECC864")
        static let accentHover = Color(hex: "F5D980")
        static let blue = Color(hex: "7DD3FC")
        static let green = Color(hex: "86EFAC")
        static let purple = Color(hex: "D8B4FE")
        static let red = Color(hex: "F87171")
        static let orange = Color(hex: "FB923C")
    }

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 10
        static let panel: CGFloat = 12
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 28
    }

    enum Typography {
        static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
    }

    enum Shadow {
        static let card = Color.black.opacity(0.40)
        static let accent = ColorToken.accent.opacity(0.18)
    }
}

// MARK: - Models

struct Project: Identifiable {
    let id: Int
    let name: String
    let isActive: Bool
    let color: Color
}

struct TaskItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let tags: [String]
    let comments: Int
    let attachments: Int
    let users: [String]
    let progress: Int
    let dueDate: String
    var isActive: Bool = false
}

struct KanbanColumn: Identifiable {
    let id: String
    let label: String
    let dot: Color
    var tasks: [TaskItem]
}

struct Subtask: Identifiable {
    let id: Int
    var done: Bool
    let text: String
    var note: String? = nil
}

struct CommentItem: Identifiable {
    let id: Int
    let user: String
    let text: String
    let time: String
}

// MARK: - Demo Data

enum DemoData {
    static let projects: [Project] = [
        .init(id: 1, name: "Craftboard Project", isActive: true, color: CraftboardTheme.ColorToken.accent),
        .init(id: 2, name: "Nimbus Dashboard", isActive: false, color: CraftboardTheme.ColorToken.blue),
        .init(id: 3, name: "Orion API Gateway", isActive: false, color: CraftboardTheme.ColorToken.green),
        .init(id: 4, name: "Helio Task System", isActive: false, color: Color(hex: "F9A8D4"))
    ]

    static let columns: [KanbanColumn] = [
        .init(id: "todo", label: "To Do", dot: Color(hex: "555555"), tasks: [
            .init(id: 1, title: "Employee Details Page", description: "Create a page with employee info, role, and performance metrics.", tags: ["Dashboard", "Medium"], comments: 3, attachments: 12, users: ["CT"], progress: 0, dueDate: "Mar 12"),
            .init(id: 2, title: "Dark Mode Version", description: "Dark mode for all mobile screens and components.", tags: ["Mobile", "Low"], comments: 2, attachments: 10, users: ["DT"], progress: 15, dueDate: "Mar 20"),
            .init(id: 3, title: "Super Admin Role", description: "", tags: ["Dashboard", "Medium"], comments: 1, attachments: 4, users: ["CT", "DT"], progress: 0, dueDate: "Apr 1")
        ]),
        .init(id: "progress", label: "In Progress", dot: CraftboardTheme.ColorToken.accent, tasks: [
            .init(id: 4, title: "Super Admin Dashboard", description: "", tags: ["Dashboard", "High"], comments: 2, attachments: 8, users: ["DT"], progress: 60, dueDate: "Mar 8"),
            .init(id: 5, title: "Settings Page", description: "Account, notifications, and billing settings.", tags: ["Mobile", "Medium"], comments: 1, attachments: 45, users: ["CT", "DT"], progress: 40, dueDate: "Mar 10"),
            .init(id: 6, title: "KPI & Employee Statistics", description: "Create a design that displays KPIs, charts, and real-time stats.", tags: ["Dashboard", "Medium"], comments: 3, attachments: 3, users: ["DT"], progress: 50, dueDate: "Mar 5", isActive: true)
        ]),
        .init(id: "review", label: "In Review", dot: CraftboardTheme.ColorToken.blue, tasks: [
            .init(id: 7, title: "Onboarding Flow", description: "3-step onboarding with guided setup.", tags: ["Mobile", "High"], comments: 4, attachments: 6, users: ["CT"], progress: 90, dueDate: "Mar 3")
        ]),
        .init(id: "done", label: "Done", dot: CraftboardTheme.ColorToken.green, tasks: [
            .init(id: 8, title: "Login & Auth Screens", description: "", tags: ["Mobile", "Low"], comments: 2, attachments: 3, users: ["CT", "DT"], progress: 100, dueDate: "Feb 28")
        ])
    ]
}

// MARK: - Root App View

struct CraftboardAppView: View {
    @State private var sidebarOpen = true
    @State private var projectsOpen = true
    @State private var detailOpen = true
    @State private var activeView = "Kanban"
    @State private var search = ""
    @State private var columns = DemoData.columns
    @State private var activeTask: TaskItem? = DemoData.columns[1].tasks[2]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                SidebarView(
                    sidebarOpen: $sidebarOpen,
                    projectsOpen: $projectsOpen,
                    search: $search
                )
                .frame(width: sidebarOpen ? 240 : 64)
                .animation(.spring(response: 0.30, dampingFraction: 0.92), value: sidebarOpen)

                VStack(spacing: 0) {
                    HeaderView(activeView: $activeView)

                    HStack(spacing: 0) {
                        BoardView(columns: columns, activeTask: activeTask, detailOpen: detailOpen) { task in
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) {
                                activeTask = task
                                detailOpen = true
                            }
                        }

                        if detailOpen, let activeTask {
                            DetailPanelView(task: activeTask) {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    detailOpen = false
                                }
                            }
                            .frame(width: min(460, proxy.size.width * 0.42))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(CraftboardTheme.ColorToken.background)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var sidebarOpen: Bool
    @Binding var projectsOpen: Bool
    @Binding var search: String

    var body: some View {
        VStack(spacing: 0) {
            logoSection
            searchSection
            navigationSection
            collapseButton
        }
        .padding(.vertical, 20)
        .background(CraftboardTheme.ColorToken.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(CraftboardTheme.ColorToken.borderSoft)
                .frame(width: 1)
        }
    }

    private var logoSection: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium)
                    .fill(Color(hex: "1A1A08"))
                    .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium).stroke(Color(hex: "2A2508"), lineWidth: 1))
                Text("C")
                    .font(CraftboardTheme.Typography.display(14, weight: .heavy))
                    .foregroundStyle(CraftboardTheme.ColorToken.accent)
            }
            .frame(width: 34, height: 34)

            if sidebarOpen {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Craftboard")
                        .font(CraftboardTheme.Typography.display(14, weight: .bold))
                        .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
                    Text("Workspace")
                        .font(CraftboardTheme.Typography.body(11))
                        .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
                }
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: sidebarOpen ? .leading : .center)
        .padding(.horizontal, sidebarOpen ? 26 : 12)
        .padding(.bottom, 24)
    }

    private var searchSection: some View {
        Group {
            if sidebarOpen {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
                    TextField("Search tasks…", text: $search)
                        .textFieldStyle(.plain)
                        .font(CraftboardTheme.Typography.body(12))
                        .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
                    Text("⌘F")
                        .font(CraftboardTheme.Typography.body(10, weight: .medium))
                        .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(CraftboardTheme.ColorToken.borderSoft)
                        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.small))
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(CraftboardTheme.ColorToken.cardAlt)
                .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium).stroke(Color(hex: "222222"), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium))
                .padding(.horizontal, 16)
            } else {
                IconButton(systemName: "magnifyingglass")
                    .padding(.horizontal, 10)
            }
        }
        .padding(.bottom, 24)
    }

    private var navigationSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                if sidebarOpen {
                    SectionLabel("Essentials")
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                }

                NavRow(label: "Home", systemName: "house", sidebarOpen: sidebarOpen)
                NavRow(label: "Tasks", systemName: "checkmark.square", sidebarOpen: sidebarOpen)
                NavRow(label: "Calendar", systemName: "calendar", sidebarOpen: sidebarOpen)
                NavRow(label: "Docs", systemName: "doc.text", sidebarOpen: sidebarOpen)

                DividerLine()

                if sidebarOpen {
                    Button {
                        withAnimation(.easeOut(duration: 0.20)) { projectsOpen.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                            Text("Projects")
                                .font(CraftboardTheme.Typography.body(13, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .rotationEffect(projectsOpen ? .degrees(0) : .degrees(-90))
                        }
                        .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(CraftboardTheme.ColorToken.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.xs))
                    }
                    .buttonStyle(.plain)

                    if projectsOpen {
                        VStack(spacing: 2) {
                            ForEach(DemoData.projects) { project in
                                ProjectRow(project: project)
                            }
                        }
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(CraftboardTheme.ColorToken.border)
                                .frame(width: 1)
                        }
                        .padding(.leading, 20)
                        .padding(.vertical, 4)
                    }
                }

                DividerLine()

                if sidebarOpen {
                    SectionLabel("Quick Stats")
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)

                    QuickStatRow(label: "Total Tasks", value: "14", color: CraftboardTheme.ColorToken.blue)
                    QuickStatRow(label: "In Progress", value: "3", color: CraftboardTheme.ColorToken.accent)
                    QuickStatRow(label: "Completed", value: "8", color: CraftboardTheme.ColorToken.green)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var collapseButton: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(CraftboardTheme.ColorToken.borderSoft)
                .frame(height: 1)
                .padding(.bottom, 16)

            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.92)) { sidebarOpen.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: sidebarOpen ? "sidebar.leading" : "sidebar.right")
                    if sidebarOpen {
                        Text("Collapse")
                            .font(CraftboardTheme.Typography.body(12, weight: .medium))
                    }
                }
                .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                .frame(maxWidth: sidebarOpen ? .infinity : 40, minHeight: 36)
                .background(Color.clear)
                .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium).stroke(Color(hex: "222222"), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, sidebarOpen ? 16 : 10)
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    @Binding var activeView: String
    private let tabs = ["Kanban", "Table", "List", "Timeline"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("My Pages / Craftboard Project")
                .font(CraftboardTheme.Typography.body(11, weight: .medium))
                .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
                .padding(.bottom, 8)

            HStack(alignment: .center) {
                Text("Craftboard Project")
                    .font(CraftboardTheme.Typography.display(26, weight: .heavy))
                    .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)

                Spacer()

                AvatarStack(users: ["CT", "DT", "AR"], size: 30)
                GhostButton(title: "Share")
                PrimaryButton(title: "New Task", systemName: "plus")
            }
            .padding(.bottom, 20)

            HStack(spacing: 4) {
                ForEach(tabs, id: \.self) { tab in
                    TabButton(title: tab, isActive: activeView == tab) {
                        activeView = tab
                    }
                }
                Spacer()
                GhostButton(title: "Filter", systemName: "line.3.horizontal.decrease.circle", compact: true)
                GhostButton(title: "Sort", compact: true)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 28)
        .background(CraftboardTheme.ColorToken.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CraftboardTheme.ColorToken.borderSoft)
                .frame(height: 1)
        }
    }
}

// MARK: - Board

struct BoardView: View {
    let columns: [KanbanColumn]
    let activeTask: TaskItem?
    let detailOpen: Bool
    let onTaskTap: (TaskItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns) { column in
                    KanbanColumnView(
                        column: column,
                        activeTask: activeTask,
                        detailOpen: detailOpen,
                        onTaskTap: onTaskTap
                    )
                    .frame(width: 300)
                }

                Button {
                } label: {
                    Label("Add Section", systemImage: "plus")
                        .font(CraftboardTheme.Typography.body(12, weight: .medium))
                        .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                        .frame(width: 200)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: CraftboardTheme.Radius.large)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                .foregroundStyle(Color(hex: "222222"))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .background(DotsBackground())
    }
}

struct KanbanColumnView: View {
    let column: KanbanColumn
    let activeTask: TaskItem?
    let detailOpen: Bool
    let onTaskTap: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(column.dot)
                    .frame(width: 8, height: 8)
                Text(column.label)
                    .font(CraftboardTheme.Typography.display(13, weight: .semibold))
                    .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
                Text("\(column.tasks.count)")
                    .font(CraftboardTheme.Typography.body(10, weight: .bold))
                    .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(CraftboardTheme.ColorToken.borderSoft)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "222222"), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
            }
            .padding(.horizontal, 2)

            ForEach(column.tasks) { task in
                KanbanCardView(
                    task: task,
                    isActive: activeTask?.id == task.id && detailOpen
                ) {
                    onTaskTap(task)
                }
            }

            Button {
            } label: {
                Label("Add Task", systemImage: "plus")
                    .font(CraftboardTheme.Typography.body(12, weight: .medium))
                    .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(Color(hex: "222222"))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

struct KanbanCardView: View {
    let task: TaskItem
    let isActive: Bool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if isActive {
                    LinearGradient(
                        colors: [CraftboardTheme.ColorToken.accent, CraftboardTheme.ColorToken.accentHover],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 2)
                    .padding(.horizontal, -16)
                    .padding(.top, -14)
                    .padding(.bottom, 12)
                }

                FlowTagRow(tags: task.tags)
                    .padding(.bottom, 10)

                Text(task.title)
                    .font(CraftboardTheme.Typography.display(13, weight: .semibold))
                    .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
                    .lineSpacing(2)
                    .padding(.bottom, task.description.isEmpty ? 0 : 6)

                if !task.description.isEmpty {
                    Text(task.description)
                        .font(CraftboardTheme.Typography.body(12))
                        .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                        .lineLimit(2)
                        .lineSpacing(4)
                }

                if task.progress > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressBar(value: Double(task.progress) / 100)
                        Text("\(task.progress)% complete")
                            .font(CraftboardTheme.Typography.body(10, weight: .medium))
                            .foregroundStyle(Color(hex: "444444"))
                    }
                    .padding(.top, 12)
                }

                HStack(alignment: .center) {
                    AvatarStack(users: task.users, size: 24)
                    Spacer()
                    MetadataLabel(systemName: "paperclip", value: task.attachments)
                    MetadataLabel(systemName: "message", value: task.comments)
                    Text(task.dueDate)
                        .font(CraftboardTheme.Typography.body(10, weight: .medium))
                        .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(CraftboardTheme.ColorToken.borderSoft)
                        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.small))
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(CraftboardTheme.ColorToken.card)
            .overlay(
                RoundedRectangle(cornerRadius: CraftboardTheme.Radius.large)
                    .stroke(isActive ? CraftboardTheme.ColorToken.accent : CraftboardTheme.ColorToken.border, lineWidth: isActive ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.large))
            .shadow(color: isActive ? CraftboardTheme.Shadow.accent : (hovering ? CraftboardTheme.Shadow.card : .clear), radius: hovering || isActive ? 16 : 0, x: 0, y: 8)
            .scaleEffect(hovering ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering = $0 }
        #endif
        .animation(.easeOut(duration: 0.18), value: hovering)
        .animation(.easeOut(duration: 0.18), value: isActive)
    }
}

// MARK: - Detail Panel

struct DetailPanelView: View {
    let task: TaskItem
    let onClose: () -> Void

    @State private var activeTab = "Subtasks"
    @State private var subtasks: [Subtask] = [
        .init(id: 1, done: true, text: "Understanding client design brief", note: "Brief from client was unclear initially 🤔"),
        .init(id: 2, done: true, text: "Collect moodboards about KPI programs"),
        .init(id: 3, done: false, text: "Create Low-fidelity wireframes"),
        .init(id: 4, done: false, text: "Convert to High-fidelity design")
    ]
    @State private var comment = ""
    @State private var comments: [CommentItem] = [
        .init(id: 1, user: "CT", text: "Added the initial wireframe sketches, please review!", time: "2h ago"),
        .init(id: 2, user: "DT", text: "Looks good! Let's finalize the color tokens.", time: "1h ago"),
        .init(id: 3, user: "CT", text: "Updated brief with new KPI requirements.", time: "30m ago")
    ]

    private var doneCount: Int { subtasks.filter(\.done).count }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    titleSection
                    progressSection
                    propertiesSection
                    descriptionSection
                    attachmentsSection
                    tabsSection
                    tabContent
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
        .background(CraftboardTheme.ColorToken.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(CraftboardTheme.ColorToken.border)
                .frame(width: 1)
        }
    }

    private var panelHeader: some View {
        HStack {
            Text("Craftboard / ")
                .font(CraftboardTheme.Typography.body(11, weight: .medium))
                .foregroundStyle(Color(hex: "444444"))
            + Text("In Progress")
                .font(CraftboardTheme.Typography.body(11, weight: .medium))
                .foregroundStyle(CraftboardTheme.ColorToken.accent)

            Spacer()

            IconButton(systemName: "arrow.up.left.and.arrow.down.right")
            IconButton(systemName: "square.and.arrow.up")
            IconButton(systemName: "ellipsis")

            Rectangle()
                .fill(CraftboardTheme.ColorToken.border)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 4)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                    .frame(width: 30, height: 30)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "222222"), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CraftboardTheme.ColorToken.borderSoft)
                .frame(height: 1)
        }
    }

    private var titleSection: some View {
        Text("KPI & Employee Statistics Page")
            .font(CraftboardTheme.Typography.display(22, weight: .bold))
            .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
            .lineSpacing(4)
            .padding(.bottom, 20)
    }

    private var progressSection: some View {
        HStack(spacing: 16) {
            ProgressRingView(value: Double(task.progress) / 100, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text("Overall Progress")
                    .font(CraftboardTheme.Typography.body(12))
                    .foregroundStyle(CraftboardTheme.ColorToken.textSecondary)
                ProgressBar(value: Double(task.progress) / 100)
            }
            Text("\(task.progress)%")
                .font(CraftboardTheme.Typography.display(20, weight: .bold))
                .foregroundStyle(CraftboardTheme.ColorToken.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CraftboardTheme.ColorToken.card)
        .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.large).stroke(CraftboardTheme.ColorToken.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.large))
        .padding(.bottom, 24)
    }

    private var propertiesSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
            GridRow {
                PropertyLabel("Status")
                HStack(spacing: 6) {
                    Circle().fill(CraftboardTheme.ColorToken.accent).frame(width: 7, height: 7)
                    Text("In Progress")
                        .font(CraftboardTheme.Typography.body(13, weight: .medium))
                        .foregroundStyle(CraftboardTheme.ColorToken.accent)
                }
            }
            GridRow {
                PropertyLabel("Due Date")
                Text("5 March 2024")
                    .font(CraftboardTheme.Typography.body(13, weight: .medium))
                    .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
            }
            GridRow {
                PropertyLabel("Assignee")
                HStack(spacing: 6) {
                    AssigneePill(user: "CT", name: "Calum Tyler")
                    AssigneePill(user: "DT", name: "Dawson T.")
                    GhostButton(title: "Invite", systemName: "plus", compact: true, pill: true)
                }
            }
            GridRow {
                PropertyLabel("Tags")
                FlowTagRow(tags: ["Dashboard", "Medium"])
            }
        }
        .padding(.bottom, 24)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            UppercaseLabel("Description")
            Text("This page provides real-time insights into employee performance metrics and key business indicators, helping managers track team health at a glance.")
                .font(CraftboardTheme.Typography.body(13))
                .foregroundStyle(Color(hex: "777777"))
                .lineSpacing(5)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CraftboardTheme.ColorToken.card)
                .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium).stroke(CraftboardTheme.ColorToken.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium))
        }
        .padding(.bottom, 24)
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                UppercaseLabel("Attachments (2)")
                Spacer()
                Button("Download All") {}
                    .buttonStyle(.plain)
                    .font(CraftboardTheme.Typography.body(11, weight: .medium))
                    .foregroundStyle(CraftboardTheme.ColorToken.accent)
            }

            HStack(spacing: 8) {
                AttachmentCard(ext: "PDF", name: "Design brief.pdf", size: "1.5 MB", bg: Color(hex: "1A0F0F"), fg: CraftboardTheme.ColorToken.red)
                AttachmentCard(ext: "Ai", name: "Craftboard logo.ai", size: "2.5 MB", bg: Color(hex: "1A1008"), fg: CraftboardTheme.ColorToken.orange)
                IconButton(systemName: "plus", width: 44, height: 54)
            }
        }
        .padding(.bottom, 24)
    }

    private var tabsSection: some View {
        HStack(spacing: 24) {
            ForEach(["Subtasks", "Comments", "Activity"], id: \.self) { tab in
                Button {
                    activeTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Text(tab)
                        if tab == "Comments" {
                            Text("\(comments.count)")
                                .font(CraftboardTheme.Typography.body(10, weight: .medium))
                                .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(CraftboardTheme.ColorToken.border)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .font(CraftboardTheme.Typography.body(13, weight: .semibold))
                    .foregroundStyle(activeTab == tab ? CraftboardTheme.ColorToken.textPrimary : Color(hex: "444444"))
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(activeTab == tab ? CraftboardTheme.ColorToken.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CraftboardTheme.ColorToken.borderSoft)
                .frame(height: 1)
        }
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var tabContent: some View {
        if activeTab == "Subtasks" {
            subtasksContent
        } else if activeTab == "Comments" {
            commentsContent
        } else {
            activityContent
        }
    }

    private var subtasksContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Design Process")
                    .font(CraftboardTheme.Typography.display(14, weight: .semibold))
                    .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
                Spacer()
                Text("\(doneCount)/\(subtasks.count) done")
                    .font(CraftboardTheme.Typography.body(12, weight: .medium))
                    .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                ProgressRingView(value: Double(doneCount) / Double(subtasks.count), size: 28)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach($subtasks) { $subtask in
                    SubtaskRow(subtask: $subtask)
                }

                GhostButton(title: "Add subtask", systemName: "plus", compact: true)
            }
        }
        .padding(.bottom, 32)
    }

    private var commentsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(comments) { item in
                CommentRow(item: item)
            }

            TextEditor(text: $comment)
                .scrollContentBackground(.hidden)
                .font(CraftboardTheme.Typography.body(13))
                .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
                .frame(minHeight: 72)
                .padding(8)
                .background(CraftboardTheme.ColorToken.cardAlt)
                .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium).stroke(Color(hex: "222222"), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium))
        }
        .padding(.bottom, 24)
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ActivityRow(user: "CT", name: "Calum", action: "moved this task to In Progress", time: "2h ago")
            ActivityRow(user: "DT", name: "Dawson", action: "added 2 attachments", time: "3h ago")
            ActivityRow(user: "CT", name: "Calum", action: "created this task", time: "Yesterday")
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Reusable Components

struct TagChip: View {
    let label: String

    private var style: (bg: Color, fg: Color, border: Color) {
        switch label {
        case "High": return (Color(hex: "1A1108"), CraftboardTheme.ColorToken.accent, Color(hex: "3A2F0A"))
        case "Medium": return (Color(hex: "141414"), Color(hex: "AAAAAA"), CraftboardTheme.ColorToken.borderStrong)
        case "Low": return (Color(hex: "111111"), CraftboardTheme.ColorToken.textMuted, CraftboardTheme.ColorToken.border)
        case "Dashboard": return (Color(hex: "0F1A1F"), CraftboardTheme.ColorToken.blue, Color(hex: "0F2535"))
        case "Mobile": return (Color(hex: "1A0F1A"), CraftboardTheme.ColorToken.purple, Color(hex: "2E1A40"))
        default: return (Color(hex: "141414"), Color(hex: "AAAAAA"), CraftboardTheme.ColorToken.borderStrong)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if label == "High" {
                Circle()
                    .fill(CraftboardTheme.ColorToken.accent)
                    .frame(width: 5, height: 5)
            }
            Text(label)
        }
        .font(CraftboardTheme.Typography.body(10, weight: .semibold))
        .foregroundStyle(style.fg)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(style.bg)
        .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.small).stroke(style.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.small))
    }
}

struct FlowTagRow: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                TagChip(label: tag)
            }
        }
    }
}

struct AvatarView: View {
    let user: String
    var size: CGFloat = 24

    private var colors: (bg: Color, fg: Color) {
        switch user {
        case "CT": return (Color(hex: "1A2535"), CraftboardTheme.ColorToken.blue)
        case "DT": return (Color(hex: "1A1108"), CraftboardTheme.ColorToken.accent)
        case "AR": return (Color(hex: "1A0F1A"), CraftboardTheme.ColorToken.purple)
        default: return (Color(hex: "222222"), CraftboardTheme.ColorToken.textSecondary)
        }
    }

    var body: some View {
        Text(user)
            .font(CraftboardTheme.Typography.body(size * 0.33, weight: .bold))
            .foregroundStyle(colors.fg)
            .frame(width: size, height: size)
            .background(colors.bg)
            .overlay(Circle().stroke(Color(hex: "181818"), lineWidth: 2))
            .clipShape(Circle())
    }
}

struct AvatarStack: View {
    let users: [String]
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: -6) {
            ForEach(users, id: \.self) { user in
                AvatarView(user: user, size: size)
            }
        }
    }
}

struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(CraftboardTheme.ColorToken.border)
                Capsule()
                    .fill(LinearGradient(colors: [CraftboardTheme.ColorToken.accent, CraftboardTheme.ColorToken.accentHover], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, proxy.size.width * value))
                    .animation(.spring(response: 0.60, dampingFraction: 0.90), value: value)
            }
        }
        .frame(height: 3)
    }
}

struct ProgressRingView: View {
    let value: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(CraftboardTheme.ColorToken.border, lineWidth: 3)
            Circle()
                .trim(from: 0, to: value)
                .stroke(CraftboardTheme.ColorToken.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.60, dampingFraction: 0.90), value: value)
        }
        .frame(width: size, height: size)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemName: String? = nil

    var body: some View {
        Button {} label: {
            HStack(spacing: 6) {
                if let systemName { Image(systemName: systemName).font(.system(size: 12, weight: .bold)) }
                Text(title)
            }
            .font(CraftboardTheme.Typography.body(13, weight: .semibold))
            .foregroundStyle(CraftboardTheme.ColorToken.background)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(CraftboardTheme.ColorToken.accent)
            .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium))
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var systemName: String? = nil
    var compact: Bool = false
    var pill: Bool = false

    var body: some View {
        Button {} label: {
            HStack(spacing: 5) {
                if let systemName { Image(systemName: systemName).font(.system(size: 11, weight: .bold)) }
                Text(title)
            }
            .font(CraftboardTheme.Typography.body(compact ? 12 : 13, weight: .medium))
            .foregroundStyle(CraftboardTheme.ColorToken.textSecondary)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 8)
            .overlay(RoundedRectangle(cornerRadius: pill ? 20 : CraftboardTheme.Radius.medium).stroke(Color(hex: "222222"), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct IconButton: View {
    let systemName: String
    var width: CGFloat = 30
    var height: CGFloat = 30

    var body: some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                .frame(width: width, height: height)
                .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.xs).stroke(Color(hex: "222222"), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct NavRow: View {
    let label: String
    let systemName: String
    let sidebarOpen: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .frame(width: 16)
            if sidebarOpen {
                Text(label)
                    .font(CraftboardTheme.Typography.body(13, weight: .medium))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
        .padding(.horizontal, sidebarOpen ? 12 : 8)
        .padding(.vertical, 8)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium))
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(project.isActive ? project.color : CraftboardTheme.ColorToken.borderStrong)
                .frame(width: 6, height: 6)
            Text(project.name)
                .font(CraftboardTheme.Typography.body(12, weight: project.isActive ? .semibold : .regular))
                .foregroundStyle(project.isActive ? CraftboardTheme.ColorToken.textPrimary : Color(hex: "444444"))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(project.isActive ? Color(hex: "161616") : .clear)
        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.xs))
    }
}

struct QuickStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(CraftboardTheme.Typography.body(12))
                .foregroundStyle(Color(hex: "444444"))
            Spacer()
            Text(value)
                .font(CraftboardTheme.Typography.body(12, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

struct MetadataLabel: View {
    let systemName: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
            Text("\(value)")
                .font(CraftboardTheme.Typography.body(11, weight: .medium))
        }
        .foregroundStyle(Color(hex: "444444"))
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    private var icon: String {
        switch title {
        case "Kanban": return "rectangle.split.3x1"
        case "Table": return "tablecells"
        case "List": return "list.bullet"
        case "Timeline": return "timeline.selection"
        default: return "circle"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(CraftboardTheme.Typography.body(13, weight: .semibold))
            .foregroundStyle(isActive ? CraftboardTheme.ColorToken.textPrimary : Color(hex: "444444"))
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? CraftboardTheme.ColorToken.accent : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct AssigneePill: View {
    let user: String
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            AvatarView(user: user, size: 20)
            Text(name)
                .font(CraftboardTheme.Typography.body(12, weight: .medium))
                .foregroundStyle(CraftboardTheme.ColorToken.textSecondary)
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .background(CraftboardTheme.ColorToken.card)
        .overlay(Capsule().stroke(CraftboardTheme.ColorToken.border, lineWidth: 1))
        .clipShape(Capsule())
    }
}

struct AttachmentCard: View {
    let ext: String
    let name: String
    let size: String
    let bg: Color
    let fg: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(ext)
                .font(CraftboardTheme.Typography.display(9, weight: .heavy))
                .foregroundStyle(fg)
                .frame(width: 32, height: 32)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(CraftboardTheme.Typography.body(12, weight: .semibold))
                    .foregroundStyle(CraftboardTheme.ColorToken.textPrimary)
                    .lineLimit(1)
                Text(size)
                    .font(CraftboardTheme.Typography.body(11))
                    .foregroundStyle(Color(hex: "444444"))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(CraftboardTheme.ColorToken.card)
        .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium).stroke(CraftboardTheme.ColorToken.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium))
    }
}

struct SubtaskRow: View {
    @Binding var subtask: Subtask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    subtask.done.toggle()
                }
            } label: {
                Image(systemName: subtask.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(subtask.done ? CraftboardTheme.ColorToken.accent : CraftboardTheme.ColorToken.textDisabled)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(subtask.text)
                    .font(CraftboardTheme.Typography.body(13, weight: .medium))
                    .foregroundStyle(subtask.done ? Color(hex: "444444") : CraftboardTheme.ColorToken.textPrimary)
                    .strikethrough(subtask.done)

                if let note = subtask.note {
                    Text("Note: \(note)")
                        .font(CraftboardTheme.Typography.body(12))
                        .foregroundStyle(CraftboardTheme.ColorToken.textMuted)
                        .lineSpacing(4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(CraftboardTheme.ColorToken.card)
                        .overlay(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium).stroke(CraftboardTheme.ColorToken.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: CraftboardTheme.Radius.medium))
                }
            }
        }
    }
}

struct CommentRow: View {
    let item: CommentItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(user: item.user, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.user == "CT" ? "Calum Tyler" : "Dawson T.")
                        .font(CraftboardTheme.Typography.body(12, weight: .semibold))
                        .foregroundStyle(CraftboardTheme.ColorToken.textSecondary)
                    Text(item.time)
                        .font(CraftboardTheme.Typography.body(11))
                        .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
                }
                Text(item.text)
                    .font(CraftboardTheme.Typography.body(13))
                    .foregroundStyle(CraftboardTheme.ColorToken.textSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(CraftboardTheme.ColorToken.card)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(CraftboardTheme.ColorToken.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct ActivityRow: View {
    let user: String
    let name: String
    let action: String
    let time: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(user: user, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(CraftboardTheme.Typography.body(12, weight: .semibold))
                    .foregroundStyle(Color(hex: "666666"))
                + Text(" \(action)")
                    .font(CraftboardTheme.Typography.body(12))
                    .foregroundStyle(Color(hex: "444444"))
                Text(time)
                    .font(CraftboardTheme.Typography.body(11))
                    .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(CraftboardTheme.Typography.body(10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(CraftboardTheme.ColorToken.textDisabled)
    }
}

struct UppercaseLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(CraftboardTheme.Typography.body(11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Color(hex: "444444"))
    }
}

struct PropertyLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(CraftboardTheme.Typography.body(12, weight: .medium))
            .foregroundStyle(Color(hex: "444444"))
            .frame(width: 90, alignment: .leading)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(CraftboardTheme.ColorToken.borderSoft)
            .frame(height: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
    }
}

struct DotsBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 2, height: 2))
            for x in stride(from: CGFloat(0), through: size.width, by: spacing) {
                for y in stride(from: CGFloat(0), through: size.height, by: spacing) {
                    context.translateBy(x: x, y: y)
                    context.fill(dot, with: .color(CraftboardTheme.ColorToken.border))
                    context.translateBy(x: -x, y: -y)
                }
            }
        }
        .background(CraftboardTheme.ColorToken.background)
    }
}

// MARK: - Utilities

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch sanitized.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    CraftboardAppView()
        .preferredColorScheme(.dark)
}
