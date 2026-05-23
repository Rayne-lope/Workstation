import SwiftUI
#if canImport(BeadsContract)
import BeadsContract
#endif
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

struct ArchiveHistoryView: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore

    @State private var searchText: String = ""
    @State private var selectedQuarter: String = "All Quarters"
    @State private var selectedPriority: String = "All Priorities"
    @State private var selectedType: String = "All Types"
    @State private var selectedIssue: BeadIssue? = nil
    @State private var isSweeping: Bool = false

    var body: some View {
        let archive = appVM.archiveStore
        let archivedList = archive?.archivedIssues ?? []

        HStack(spacing: 0) {
            // Main Content Area (Left side)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Stats Overview Cards
                        statsSection(archivedIssues: archivedList)

                        // Sweep Pending Banner
                        sweepBannerSection()

                        // Filter and Search Controls
                        filterControlsSection(archivedIssues: archivedList)

                        // Archived Issues Table/List
                        archivedListSection(archivedIssues: archivedList)
                    }
                    .padding(28)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DotsBackground())

            // Split Inspector Panel (Right side Drawer)
            if let issue = selectedIssue {
                Divider()
                    .overlay(WorkstationTheme.border)

                archivedIssueInspector(issue: issue)
                    .frame(width: 420)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedIssue?.id)
    }

    // MARK: - Stats Section

    @ViewBuilder
    private func statsSection(archivedIssues: [BeadIssue]) -> some View {
        let quarters = Set(archivedIssues.map { ArchiveStore.partitionName(for: $0.closedAt) })

        HStack(spacing: 16) {
            // Card 1: Total Archived
            statCard(
                title: "Total Archived",
                value: "\(archivedIssues.count)",
                icon: "archivebox.fill",
                gradient: Gradient(colors: [WorkstationTheme.accent, WorkstationTheme.accent.opacity(0.65)])
            )

            // Card 2: Quarters Covered
            statCard(
                title: "Quarters Partitioned",
                value: "\(quarters.count)",
                icon: "calendar",
                gradient: Gradient(colors: [WorkstationTheme.blue, WorkstationTheme.blue.opacity(0.65)])
            )

            // Card 3: Snappy Workspace Save
            statCard(
                title: "Database Relief",
                value: archivedIssues.isEmpty ? "0%" : "95%+",
                icon: "gauge.with.needle.fill",
                gradient: Gradient(colors: [WorkstationTheme.green, WorkstationTheme.green.opacity(0.65)])
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, gradient: Gradient) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                Text(value)
                    .font(WorkstationTheme.Fonts.display(26, weight: .heavy))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.12))
                    .frame(width: 44, height: 44)
                
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(WorkstationTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Sweep Banner Section

    @ViewBuilder
    private func sweepBannerSection() -> some View {
        let activeClosedCount = store.issues.filter { $0.status == "closed" }.count
        if activeClosedCount > 0 {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(WorkstationTheme.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(WorkstationTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Database Optimization Available")
                        .font(WorkstationTheme.Fonts.body(14, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)

                    Text("There are \(activeClosedCount) closed issues remaining in your active workspace database. Moving them to the historical archive will keep your Kanban Board running at peak performance.")
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                }

                Spacer()

                Button {
                    isSweeping = true
                    Task {
                        await appVM.archiveClosedIssues()
                        isSweeping = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSweeping {
                            ProgressView()
                                .controlSize(.small)
                                .tint(WorkstationTheme.background)
                        } else {
                            Image(systemName: "archivebox.fill")
                        }
                        Text(isSweeping ? "Archiving..." : "Archive Closed Now")
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(isSweeping)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(WorkstationTheme.accentBg.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(WorkstationTheme.accentBorder, lineWidth: 1.2)
            )
            .shadow(color: WorkstationTheme.accent.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    // MARK: - Filter Section

    @ViewBuilder
    private func filterControlsSection(archivedIssues: [BeadIssue]) -> some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                
                TextField("Search archived issues...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(WorkstationTheme.Fonts.body(13, weight: .regular))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(WorkstationTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(WorkstationTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )

            // Pickers Stack
            HStack(spacing: 10) {
                let quarters = ["All Quarters"] + Set(archivedIssues.map { ArchiveStore.partitionName(for: $0.closedAt) }).sorted(by: >)
                customPicker(selection: $selectedQuarter, options: quarters)

                let priorities = ["All Priorities", "P0 - Critical", "P1 - High", "P2 - Medium", "P3 - Low", "P4 - Backlog"]
                customPicker(selection: $selectedPriority, options: priorities)

                let types = ["All Types", "Feature", "Bug", "Task", "Chore", "Epic"]
                customPicker(selection: $selectedType, options: types)
            }
        }
    }

    @ViewBuilder
    private func customPicker(selection: Binding<String>, options: [String]) -> some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.self) { opt in
                Text(opt).tag(opt)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 140)
        .controlSize(.small)
    }

    // MARK: - List Section

    @ViewBuilder
    private func archivedListSection(archivedIssues: [BeadIssue]) -> some View {
        let filtered = archivedIssues.filter { issue in
            // Search filter
            if !searchText.isEmpty {
                let term = searchText.lowercased()
                let matchId = issue.id.lowercased().contains(term)
                let matchTitle = issue.title.lowercased().contains(term)
                let matchDesc = (issue.description ?? "").lowercased().contains(term)
                let matchNotes = (issue.notes ?? "").lowercased().contains(term)
                if !matchId && !matchTitle && !matchDesc && !matchNotes {
                    return false
                }
            }

            // Quarter filter
            if selectedQuarter != "All Quarters" {
                let q = ArchiveStore.partitionName(for: issue.closedAt)
                if q != selectedQuarter {
                    return false
                }
            }

            // Priority filter
            if selectedPriority != "All Priorities" {
                let p = issue.priority ?? 2
                let filterVal = Int(selectedPriority.prefix(2).dropFirst()) ?? 2
                if p != filterVal {
                    return false
                }
            }

            // Type filter
            if selectedType != "All Types" {
                let type = (issue.issueType ?? "task").lowercased()
                let filterVal = selectedType.lowercased()
                if type != filterVal {
                    return false
                }
            }

            return true
        }

        VStack(alignment: .leading, spacing: 0) {
            // Table Header
            HStack(spacing: 0) {
                Text("ISSUE ID")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .tracking(0.8)
                    .frame(width: 130, alignment: .leading)
                
                Text("TITLE")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("TYPE")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .tracking(0.8)
                    .frame(width: 90, alignment: .center)
                
                Text("PRIORITY")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .tracking(0.8)
                    .frame(width: 110, alignment: .center)
                
                Text("ARCHIVED AT")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .tracking(0.8)
                    .frame(width: 130, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(WorkstationTheme.cardAlt)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(WorkstationTheme.border)
                    .frame(height: 1)
            }

            if filtered.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 32))
                        .foregroundStyle(WorkstationTheme.textDisabled)
                        .padding(.top, 48)
                    
                    Text("No archived issues found matching filters.")
                        .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .padding(.bottom, 48)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { issue in
                        let isSelected = selectedIssue?.id == issue.id

                        Button {
                            selectedIssue = isSelected ? nil : issue
                        } label: {
                            HStack(spacing: 0) {
                                // Monospaced bold ID
                                Text(issue.id)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isSelected ? WorkstationTheme.accent : WorkstationTheme.textPrimary)
                                    .frame(width: 130, alignment: .leading)

                                Text(issue.title)
                                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                                    .foregroundStyle(isSelected ? WorkstationTheme.textPrimary : WorkstationTheme.textPrimary.opacity(0.85))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Type tag
                                Text(issue.issueType?.capitalized ?? "Task")
                                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                    .foregroundStyle(WorkstationTheme.textSecondary)
                                    .frame(width: 90, alignment: .center)

                                // Priority badge
                                priorityBadge(prio: issue.priority ?? 2)
                                    .frame(width: 110, alignment: .center)

                                // Closed At
                                Text(formatDate(issue.closedAt ?? issue.updatedAt))
                                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                    .foregroundStyle(WorkstationTheme.textMuted)
                                    .frame(width: 130, alignment: .trailing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(isSelected ? WorkstationTheme.accentBg : (issueRowIndex(issue, in: filtered) % 2 == 0 ? WorkstationTheme.surface : WorkstationTheme.card))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(WorkstationTheme.borderSoft)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .background(WorkstationTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private func issueRowIndex(_ issue: BeadIssue, in list: [BeadIssue]) -> Int {
        list.firstIndex(where: { $0.id == issue.id }) ?? 0
    }

    private func priorityBadge(prio: Int) -> some View {
        let label: String
        let fg: Color
        let bg: Color
        let border: Color

        switch prio {
        case 0:
            label = "P0 Critical"
            fg = WorkstationTheme.red
            bg = WorkstationTheme.redBg
            border = WorkstationTheme.redBorder
        case 1:
            label = "P1 High"
            fg = WorkstationTheme.red
            bg = WorkstationTheme.redBg
            border = WorkstationTheme.redBorder
        case 2:
            label = "P2 Medium"
            fg = WorkstationTheme.accent
            bg = WorkstationTheme.accentBg
            border = WorkstationTheme.accentBorder
        case 3:
            label = "P3 Low"
            fg = WorkstationTheme.blue
            bg = WorkstationTheme.blueBg
            border = WorkstationTheme.blueBorder
        default:
            label = "P4 Backlog"
            fg = WorkstationTheme.textSecondary
            bg = WorkstationTheme.borderSoft
            border = WorkstationTheme.border
        }

        return Text(label)
            .font(WorkstationTheme.Fonts.body(10, weight: .bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 2.5)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private func formatDate(_ dateStr: String?) -> String {
        guard let dateStr, dateStr.count >= 10 else { return "Unknown" }
        return String(dateStr.prefix(10))
    }

    // MARK: - Inspector Panel (collapsible side drawer)

    @ViewBuilder
    private func archivedIssueInspector(issue: BeadIssue) -> some View {
        VStack(spacing: 0) {
            // Inspector Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(issue.id)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(WorkstationTheme.accent)
                        
                        Text("•")
                            .font(WorkstationTheme.Fonts.body(11))
                            .foregroundStyle(WorkstationTheme.textMuted)
                            
                        Text(issue.issueType?.uppercased() ?? "TASK")
                            .font(WorkstationTheme.Fonts.label)
                            .foregroundStyle(WorkstationTheme.textMuted)
                    }
                    
                    Text("Archived Record")
                        .font(WorkstationTheme.Fonts.display(18, weight: .heavy))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                }

                Spacer()

                Button {
                    selectedIssue = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .padding(6)
                        .background(WorkstationTheme.hover)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(WorkstationTheme.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(WorkstationTheme.border)
                    .frame(height: 1)
            }

            // Details scroll view
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TITLE")
                            .font(WorkstationTheme.Fonts.label)
                            .foregroundStyle(WorkstationTheme.textDisabled)
                            .tracking(0.8)
                        
                        Text(issue.title)
                            .font(WorkstationTheme.Fonts.body(14, weight: .bold))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }

                    // Properties Grid (Style Guide section 8.5)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 1) {
                            metadataItemCard(label: "PRIORITY", view: priorityBadge(prio: issue.priority ?? 2))
                            metadataItemCard(label: "ASSIGNEE", val: issue.assignee ?? "Unassigned")
                        }
                        HStack(spacing: 1) {
                            metadataItemCard(label: "PARTITION", val: ArchiveStore.partitionName(for: issue.closedAt))
                            metadataItemCard(label: "TYPE", val: issue.issueType?.capitalized ?? "Task")
                        }
                    }
                    .background(WorkstationTheme.border)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                            .stroke(WorkstationTheme.border, lineWidth: 1)
                    )

                    Divider()
                        .overlay(WorkstationTheme.borderSoft)

                    // Description
                    inspectorMarkdownSection(label: "DESCRIPTION", text: issue.description)

                    // Acceptance Criteria
                    inspectorMarkdownSection(label: "ACCEPTANCE CRITERIA", text: issue.acceptanceCriteria)

                    // Close Reason / Notes
                    inspectorMarkdownSection(label: "CLOSE REASON & RUN NOTES", text: issue.notes ?? "Closed")

                    Divider()
                        .overlay(WorkstationTheme.borderSoft)

                    // Timestamps list
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TIMESTAMPS")
                            .font(WorkstationTheme.Fonts.label)
                            .foregroundStyle(WorkstationTheme.textDisabled)
                            .tracking(0.8)
                            .padding(.bottom, 2)
                        
                        timestampItem(label: "Created", date: formatDate(issue.createdAt))
                        timestampItem(label: "Closed", date: formatDate(issue.closedAt ?? issue.updatedAt))
                    }
                }
                .padding(20)
            }
        }
        .frame(maxHeight: .infinity)
        .background(WorkstationTheme.surface)
    }

    private func metadataItemCard(label: String, val: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .tracking(0.5)
            
            Text(val)
                .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
    }

    private func metadataItemCard(label: String, view: some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .tracking(0.5)
            
            view
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
    }

    private func inspectorMarkdownSection(label: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
                .tracking(0.8)
            
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(text)
                    .font(WorkstationTheme.Fonts.body(12, weight: .regular))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            } else {
                Text("None provided.")
                    .font(WorkstationTheme.Fonts.body(12, weight: .regular))
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .italic()
            }
        }
    }

    private func timestampItem(label: String, date: String?) -> some View {
        HStack {
            Text(label)
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textDisabled)
            Spacer()
            Text(date ?? "N/A")
                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
    }
}
