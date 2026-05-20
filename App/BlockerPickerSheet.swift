import SwiftUI

struct BlockerPickerSheet: View {
    let store: IssueStore
    let issueID: String
    let existingBlockerIDs: Set<String>
    let onPick: (String) -> Void
    let onCancel: () -> Void

    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    private var eligibleIssues: [BeadIssue] {
        store.issues.filter { issue in
            guard issue.id != issueID else { return false }
            guard !existingBlockerIDs.contains(issue.id) else { return false }
            if issue.status == "closed" { return false }
            let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !needle.isEmpty else { return true }
            return issue.id.lowercased().contains(needle)
                || issue.title.lowercased().contains(needle)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider().overlay(WorkstationTheme.borderSoft)

            VStack(alignment: .leading, spacing: 14) {
                searchField

                if eligibleIssues.isEmpty {
                    emptyState
                } else {
                    HStack(spacing: 6) {
                        Text("\(eligibleIssues.count) AVAILABLE")
                            .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(WorkstationTheme.textSubtle)
                        Spacer()
                    }
                    .padding(.top, 2)

                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(eligibleIssues) { item in
                                Button { onPick(item.id) } label: { row(for: item) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 340)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(WorkstationTheme.background)

            Divider().overlay(WorkstationTheme.borderSoft)

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .buttonStyle(WorkstationGhostButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 560)
        .background(WorkstationTheme.surface)
        .preferredColorScheme(.dark)
        .onAppear { searchFocused = true }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("CRAFTBOARD /")
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Text(issueID)
                        .foregroundStyle(WorkstationTheme.accent)
                }
                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                .tracking(0.9)

                Text("Add Blocker")
                    .font(WorkstationTheme.Fonts.display(22, weight: .heavy))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(searchFocused ? WorkstationTheme.accent : WorkstationTheme.textSubtle)

            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("Search by id or title…")
                        .font(WorkstationTheme.Fonts.body(13))
                        .foregroundStyle(WorkstationTheme.textSubtle)
                }
                TextField("", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .focused($searchFocused)
            }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(searchFocused ? WorkstationTheme.accent : WorkstationTheme.borderStrong,
                        lineWidth: searchFocused ? 1.2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: searchFocused)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(WorkstationTheme.textDisabled)
            Text("No matching issues")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
            Text("Try a different keyword or clear the search.")
                .font(WorkstationTheme.Fonts.body(11))
                .foregroundStyle(WorkstationTheme.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private func row(for item: BeadIssue) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(WorkstationTheme.difficultyColor(item.priority ?? 4))
                .frame(width: 7, height: 7)

            Text(item.id)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(minWidth: 120, alignment: .leading)
                .foregroundStyle(WorkstationTheme.textSecondary)

            Text(item.title)
                .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if let status = item.status {
                statusBadge(status)
            }

            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(WorkstationTheme.textMuted)
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                        .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .fill(WorkstationTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let tint = statusTint(status)
        Text(status.uppercased())
            .font(WorkstationTheme.Fonts.body(9.5, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tint.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                    .stroke(tint.opacity(0.30), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small))
    }

    private func statusTint(_ status: String) -> Color {
        switch status.lowercased() {
        case "in_progress": return WorkstationTheme.accent
        case "review": return WorkstationTheme.blue
        case "blocked": return WorkstationTheme.red
        case "ready", "open": return WorkstationTheme.green
        default: return WorkstationTheme.textMuted
        }
    }
}
