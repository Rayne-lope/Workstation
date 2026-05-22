import SwiftUI

// MARK: - Palette Item Model

enum CommandPaletteItem: Identifiable {
    case issue(BeadIssue)
    case action(CommandPaletteAction)
    case filter(CommandPaletteFilter)

    var id: String {
        switch self {
        case .issue(let issue): return "issue-\(issue.id)"
        case .action(let action): return action.id
        case .filter(let filter): return filter.id
        }
    }

    var displayTitle: String {
        switch self {
        case .issue(let issue): return issue.title
        case .action(let action): return action.title
        case .filter(let filter): return filter.title
        }
    }

    var displaySubtitle: String? {
        switch self {
        case .issue(let issue): return issue.id
        case .action: return nil
        case .filter(let filter): return filter.subtitle
        }
    }

    var icon: String {
        switch self {
        case .issue(let issue):
            switch issue.issueType?.lowercased() {
            case "bug": return "ladybug.fill"
            case "feature": return "sparkles"
            case "epic": return "flag.fill"
            case "chore": return "wrench.fill"
            default: return "circle.fill"
            }
        case .action(let action): return action.icon
        case .filter(let filter): return filter.icon
        }
    }

    var iconColor: Color {
        switch self {
        case .issue(let issue):
            switch issue.issueType?.lowercased() {
            case "bug": return WorkstationTheme.red
            case "feature": return WorkstationTheme.accent
            case "epic": return WorkstationTheme.purple
            case "chore": return WorkstationTheme.textMuted
            default: return WorkstationTheme.blue
            }
        case .action: return WorkstationTheme.accent
        case .filter(let filter): return filter.color
        }
    }

    var section: CommandPaletteSection {
        switch self {
        case .issue: return .issues
        case .action: return .actions
        case .filter: return .filters
        }
    }
}

extension CommandPaletteItem: Hashable {
    static func == (lhs: CommandPaletteItem, rhs: CommandPaletteItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum CommandPaletteSection: String, CaseIterable {
    case actions = "ACTIONS"
    case issues = "ISSUES"
    case filters = "FILTERS"

    var label: String { rawValue }
}

struct CommandPaletteAction: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let execute: () -> Void

    static func == (lhs: CommandPaletteAction, rhs: CommandPaletteAction) -> Bool {
        lhs.id == rhs.id
    }
}

struct CommandPaletteFilter: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let execute: () -> Void

    static func == (lhs: CommandPaletteFilter, rhs: CommandPaletteFilter) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Store

@MainActor
final class CommandPaletteStore: ObservableObject {
    let store: IssueStore
    let appVM: AppViewModel

    @Published var query: String = ""
    @Published var selectedIndex: Int = 0

    private var recentIssueIDs: [String] = []
    private(set) var results: [CommandPaletteItem] = []

    var groupedResults: [CommandPaletteSection: [CommandPaletteItem]] {
        Dictionary(grouping: results, by: \.section)
    }

    init(store: IssueStore, appVM: AppViewModel) {
        self.store = store
        self.appVM = appVM
        loadRecentIssues()
        rebuildResults()
    }

    private func loadRecentIssues() {
        recentIssueIDs = store.issues
            .sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
            .prefix(5)
            .map(\.id)
    }

    func rebuildResults() {
        var items: [CommandPaletteItem] = []
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let actions: [CommandPaletteAction] = [
            CommandPaletteAction(id: "reload", title: "Reload Issues", icon: "arrow.clockwise") { [weak self] in
                self?.appVM.reloadIssues()
                self?.dismiss()
            },
            CommandPaletteAction(id: "new-issue", title: "New Issue", icon: "plus.circle") { [weak self] in
                self?.appVM.presentCreateIssue()
                self?.dismiss()
            },
            CommandPaletteAction(id: "debug", title: "Open Debug Panel", icon: "ladybug") { [weak self] in
                self?.appVM.presentDebugPanel()
                self?.dismiss()
            },
        ]

        for action in actions {
            if q.isEmpty || action.title.lowercased().contains(q) {
                items.append(.action(action))
            }
        }

        let filters: [CommandPaletteFilter] = [
            CommandPaletteFilter(
                id: "show-review", title: "Show Human Review Only", subtitle: "Filter: human-review issues",
                icon: "eye", color: WorkstationTheme.blue
            ) { [weak self] in
                guard let self else { return }
                self.store.clearFilters()
                self.store.filterState.toggleLabel(KanbanStateMapper.humanReviewLabel)
                self.dismiss()
            },
            CommandPaletteFilter(
                id: "show-blocked", title: "Show Blocked Only", subtitle: "Filter: blocked issues",
                icon: "exclamationmark.triangle", color: WorkstationTheme.red
            ) { [weak self] in
                guard let self else { return }
                self.store.clearFilters()
                self.store.filterState.toggleAssignee(.other)
                self.dismiss()
            },
            CommandPaletteFilter(
                id: "clear-filters", title: "Clear All Filters", subtitle: "Reset to show all issues",
                icon: "xmark.circle", color: WorkstationTheme.textMuted
            ) { [weak self] in
                self?.store.clearFilters()
                self?.dismiss()
            },
        ]

        for filter in filters {
            if q.isEmpty || filter.title.lowercased().contains(q) {
                items.append(.filter(filter))
            }
        }

        let filteredIssues: [BeadIssue]
        if q.isEmpty {
            filteredIssues = store.issues.filter { recentIssueIDs.contains($0.id) }
        } else {
            filteredIssues = store.issues.filter {
                $0.title.lowercased().contains(q) || $0.id.lowercased().contains(q)
            }
        }

        for issue in filteredIssues.prefix(8) {
            items.append(.issue(issue))
        }

        results = items
        selectedIndex = 0
    }

    func executeSelected() {
        guard selectedIndex >= 0 && selectedIndex < results.count else { return }
        execute(item: results[selectedIndex])
    }

    func execute(item: CommandPaletteItem) {
        switch item {
        case .issue(let issue):
            store.selectIssue(id: issue.id)
            dismiss()
        case .action(let action):
            action.execute()
        case .filter(let filter):
            filter.execute()
        }
    }

    func moveSelectionUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }

    func moveSelectionDown() {
        if selectedIndex < results.count - 1 { selectedIndex += 1 }
    }

    func dismiss() {
        appVM.dismissCommandPalette()
    }

    var selectedItem: CommandPaletteItem? {
        guard selectedIndex >= 0 && selectedIndex < results.count else { return nil }
        return results[selectedIndex]
    }
}

// MARK: - Sheet Wrapper

struct CommandPaletteSheet: View {
    @StateObject var store: CommandPaletteStore

    var body: some View {
        CommandPaletteSheetContent(store: store)
    }
}

// MARK: - View

struct CommandPaletteSheetContent: View {
    @ObservedObject var store: CommandPaletteStore
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textMuted)

                TextField("Search issues, actions, or filters…", text: $store.query)
                    .font(WorkstationTheme.Fonts.body(14, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { store.executeSelected() }

                Button { store.dismiss() } label: {
                    Text("ESC")
                        .font(WorkstationTheme.Fonts.body(9, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(WorkstationTheme.borderStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(WorkstationTheme.cardAlt)

            Divider().overlay(WorkstationTheme.borderSoft)

            // Results
            if store.results.isEmpty {
                VStack(spacing: 8) {
                    Text("No results")
                        .font(WorkstationTheme.Fonts.body(13))
                        .foregroundStyle(WorkstationTheme.textMuted)
                    Text("Try a different search term")
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textDisabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(CommandPaletteSection.allCases, id: \.self) { section in
                                let sectionItems = store.groupedResults[section] ?? []
                                if !sectionItems.isEmpty {
                                    sectionHeader(section)
                                    ForEach(sectionItems, id: \.id) { item in
                                        let globalIdx = store.results.firstIndex(of: item) ?? 0
                                        paletteRow(item: item, index: globalIdx)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 380)
                    .onChange(of: store.selectedIndex) { _, newValue in
                        guard store.results.indices.contains(newValue) else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(store.results[newValue].id, anchor: .center)
                        }
                    }
                }
            }

            // Footer hint
            HStack(spacing: 16) {
                hintChip(key: "↑↓", label: "Navigate")
                hintChip(key: "↵", label: "Select")
                hintChip(key: "ESC", label: "Dismiss")
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(WorkstationTheme.cardAlt)
        }
        .frame(width: 580)
        .background(WorkstationTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous))
        .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 8)
        .onAppear { isSearchFocused = true }
        .onChange(of: store.query) { _, _ in store.rebuildResults() }
        .onKeyPress { event in
            switch event.key {
            case .upArrow:
                store.moveSelectionUp()
                return .handled
            case .downArrow:
                store.moveSelectionDown()
                return .handled
            case .return, .tab:
                store.executeSelected()
                return .handled
            case .escape:
                store.dismiss()
                return .handled
            default:
                return .ignored
            }
        }
    }

    private func sectionHeader(_ section: CommandPaletteSection) -> some View {
        Text(section.label)
            .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
            .foregroundStyle(WorkstationTheme.textSubtle)
            .tracking(0.8)
            .textCase(.uppercase)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private func paletteRow(item: CommandPaletteItem, index: Int) -> some View {
        let isSelected = store.selectedIndex == index
        return HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(item.iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayTitle)
                    .font(WorkstationTheme.Fonts.body(13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(1)

                if let subtitle = item.displaySubtitle {
                    Text(subtitle)
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? WorkstationTheme.cardAlt : Color.clear)
        .contentShape(Rectangle())
        .id(item.id)
        .onTapGesture { store.execute(item: item) }
    }

    private func hintChip(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(WorkstationTheme.Fonts.body(9, weight: .bold))
                .foregroundStyle(WorkstationTheme.textSubtle)
            Text(label)
                .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                .foregroundStyle(WorkstationTheme.textSubtle)
        }
    }
}