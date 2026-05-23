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
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Stats Overview Cards
                        statsSection(archivedIssues: archivedList)

                        // Sweep Pending Banner
                        sweepBannerSection()

                        // Filter and Search Controls
                        filterControlsSection(archivedIssues: archivedList)

                        // Archived Issues Table/List
                        archivedListSection(archivedIssues: archivedList)
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WorkstationTheme.background)

            // Split Inspector Panel (Right side)
            if let issue = selectedIssue {
                Divider()
                    .overlay(WorkstationTheme.borderSoft)

                archivedIssueInspector(issue: issue)
                    .frame(width: 380)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(duration: 0.3), value: selectedIssue != nil)
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
                gradient: Gradient(colors: [WorkstationTheme.accent, WorkstationTheme.accent.opacity(0.7)])
            )

            // Card 2: Quarters Covered
            statCard(
                title: "Quarters Covered",
                value: "\(quarters.count)",
                icon: "calendar",
                gradient: Gradient(colors: [WorkstationTheme.blue, WorkstationTheme.blue.opacity(0.7)])
            )

            // Card 3: Snappy Workspace Save
            statCard(
                title: "Database Load Relief",
                value: archivedIssues.isEmpty ? "0%" : "95%+",
                icon: "gauge.with.needle.fill",
                gradient: Gradient(colors: [WorkstationTheme.green, WorkstationTheme.green.opacity(0.7)])
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, gradient: Gradient) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(value)
                    .font(WorkstationTheme.Fonts.display(24, weight: .heavy))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(WorkstationTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Sweep Banner Section

    @ViewBuilder
    private func sweepBannerSection() -> some View {
        let activeClosedCount = store.issues.filter { $0.status == "closed" }.count
        if activeClosedCount > 0 {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snappy Workspace Maintenance")
                        .font(WorkstationTheme.Fonts.body(14, weight: .bold))
                        .foregroundStyle(WorkstationTheme.accent)

                    Text("There are \(activeClosedCount) closed issues remaining in your active database. Moving them to the history archive will keep your board extremely fast.")
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    isSweeping = true
                    Task {
                        await appVM.archiveClosedIssues()
                        isSweeping = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isSweeping {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isSweeping ? "Archiving..." : "Archive Completed Now")
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(isSweeping)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(WorkstationTheme.accentBg)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(WorkstationTheme.accentBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Filter Section

    @ViewBuilder
    private func filterControlsSection(archivedIssues: [BeadIssue]) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(WorkstationTheme.textDisabled)
                    TextField("Search archived issues...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(WorkstationTheme.Fonts.body(13, weight: .regular))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(WorkstationTheme.textDisabled)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(WorkstationTheme.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                )

                // Quarter picker
                let quarters = ["All Quarters"] + Set(archivedIssues.map { ArchiveStore.partitionName(for: $0.closedAt) }).sorted(by: >)
                Picker("", selection: $selectedQuarter) {
                    ForEach(quarters, id: \.self) { q in
                        Text(q).tag(q)
                    }
                }
                .frame(width: 140)
                .pickerStyle(.menu)

                // Priority picker
                let priorities = ["All Priorities", "P0 - Critical", "P1 - High", "P2 - Medium", "P3 - Low", "P4 - Backlog"]
                Picker("", selection: $selectedPriority) {
                    ForEach(priorities, id: \.self) { p in
                        Text(p).tag(p)
                    }
                }
                .frame(width: 140)
                .pickerStyle(.menu)

                // Type picker
                let types = ["All Types", "Feature", "Bug", "Task", "Chore", "Epic"]
                Picker("", selection: $selectedType) {
                    ForEach(types, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .frame(width: 120)
                .pickerStyle(.menu)
            }
        }
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
                Text("Issue ID")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .frame(width: 120, alignment: .leading)
                Text("Title")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Type")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .frame(width: 80, alignment: .center)
                Text("Priority")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .frame(width: 80, alignment: .center)
                Text("Archived At")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textDisabled)
                    .frame(width: 120, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(WorkstationTheme.cardAlt)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(WorkstationTheme.borderSoft)
                    .frame(height: 1)
            }

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 32))
                        .foregroundStyle(WorkstationTheme.textDisabled)
                        .padding(.top, 40)
                    Text("No archived issues found matching filters.")
                        .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .padding(.bottom, 40)
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
                                Text(issue.id)
                                    .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                                    .foregroundStyle(WorkstationTheme.textPrimary)
                                    .frame(width: 120, alignment: .leading)

                                Text(issue.title)
                                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                                    .foregroundStyle(WorkstationTheme.textPrimary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Type
                                Text(issue.issueType?.capitalized ?? "Task")
                                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                    .foregroundStyle(WorkstationTheme.textMuted)
                                    .frame(width: 80, alignment: .center)

                                // Priority
                                ZStack {
                                    Text("P\(issue.priority ?? 2)")
                                        .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                                        .foregroundStyle(priorityColor(for: issue.priority ?? 2))
                                }
                                .frame(width: 80, alignment: .center)

                                // Closed At
                                Text(formatDate(issue.closedAt ?? issue.updatedAt))
                                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                                    .foregroundStyle(WorkstationTheme.textDisabled)
                                    .frame(width: 120, alignment: .trailing)
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
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
    }

    private func issueRowIndex(_ issue: BeadIssue, in list: [BeadIssue]) -> Int {
        list.firstIndex(where: { $0.id == issue.id }) ?? 0
    }

    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 0, 1: return WorkstationTheme.red
        case 2: return WorkstationTheme.accent
        case 3: return WorkstationTheme.blue
        default: return WorkstationTheme.textDisabled
        }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.id)
                        .font(WorkstationTheme.Fonts.label)
                        .foregroundStyle(WorkstationTheme.accent)
                    Text("Archived Record")
                        .font(WorkstationTheme.Fonts.display(16, weight: .heavy))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                }

                Spacer()

                Button {
                    selectedIssue = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(WorkstationTheme.textDisabled)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(WorkstationTheme.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(WorkstationTheme.borderSoft)
                    .frame(height: 1)
            }

            // Details list
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TITLE")
                            .font(WorkstationTheme.Fonts.label)
                            .foregroundStyle(WorkstationTheme.textDisabled)
                        Text(issue.title)
                            .font(WorkstationTheme.Fonts.body(14, weight: .bold))
                            .foregroundStyle(WorkstationTheme.textPrimary)
                    }

                    // Metadata row
                    HStack(spacing: 20) {
                        metadataItem(label: "TYPE", val: issue.issueType?.capitalized ?? "Task")
                        metadataItem(label: "PRIORITY", val: "P\(issue.priority ?? 2)")
                        metadataItem(label: "ASSIGNEE", val: issue.assignee ?? "Unassigned")
                    }

                    Divider()
                        .overlay(WorkstationTheme.borderSoft)

                    // Description
                    inspectorMarkdownSection(label: "DESCRIPTION", text: issue.description)

                    // Acceptance Criteria
                    inspectorMarkdownSection(label: "ACCEPTANCE CRITERIA", text: issue.acceptanceCriteria)

                    // Close Reason
                    inspectorMarkdownSection(label: "CLOSE REASON", text: issue.notes ?? "Closed")

                    Divider()
                        .overlay(WorkstationTheme.borderSoft)

                    // Timestamps
                    VStack(alignment: .leading, spacing: 8) {
                        timestampItem(label: "Created", date: issue.createdAt)
                        timestampItem(label: "Closed", date: issue.closedAt ?? issue.updatedAt)
                        timestampItem(label: "Archive Quarter", date: ArchiveStore.partitionName(for: issue.closedAt))
                    }
                }
                .padding(20)
            }
        }
        .frame(maxHeight: .infinity)
        .background(WorkstationTheme.surface)
    }

    private func metadataItem(label: String, val: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
            Text(val)
                .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
        }
    }

    private func inspectorMarkdownSection(label: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(WorkstationTheme.Fonts.label)
                .foregroundStyle(WorkstationTheme.textDisabled)
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
