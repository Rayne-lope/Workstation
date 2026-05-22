import SwiftUI

struct IssueDetailRecurringSection: View {
    @Bindable var appVM: AppViewModel
    let issue: BeadIssue
    let isLoading: Bool
    var displayMode: IssueDetailRecurringDisplayMode = .full

    @State private var recurringNotesDraft: String = ""
    @State private var recurringActionFlash: String?

    @ViewBuilder
    var body: some View {
        let metadata = appVM.recurringMetadata(for: issue.id)
        let isRecurring = metadata?.isRecurring == true
        switch displayMode {
        case .full:
            recurringFull(metadata: metadata, isRecurring: isRecurring)
        case .controls:
            recurringControls(metadata: metadata, isRecurring: isRecurring)
        case .history:
            if isRecurring, let metadata {
                recurringHistorySummary(metadata: metadata)
            }
        }
    }

    private func recurringFull(metadata: RecurringMetadata?, isRecurring: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            recurringControls(metadata: metadata, isRecurring: isRecurring)
            if isRecurring, let metadata, !metadata.history.isEmpty {
                recurringHistorySummary(metadata: metadata)
            }
        }
    }

    private func recurringControls(metadata: RecurringMetadata?, isRecurring: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(metadata: metadata, isRecurring: isRecurring)

            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { isRecurring },
                    set: { _ in appVM.toggleRecurring(for: issue.id) }
                )) {
                    Label(isRecurring ? "Recurring enabled" : "Mark as recurring", systemImage: "arrow.triangle.2.circlepath")
                        .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                        .foregroundStyle(isRecurring ? WorkstationTheme.textPrimary : WorkstationTheme.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(WorkstationTheme.accent)
                .help("When on, completing a run resets the issue to Ready instead of closing it")
                Spacer()
            }

            if isRecurring, let metadata {
                cadencePickerView(currentDays: metadata.cadenceDays)
                runCompletionInput()
            }

            if let flash = recurringActionFlash {
                Label(flash, systemImage: "checkmark.circle.fill")
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.green)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    @ViewBuilder
    private func recurringHistorySummary(metadata: RecurringMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(metadata: metadata, isRecurring: true)
            if metadata.history.isEmpty {
                Text("No recurring runs logged yet")
                    .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textMuted)
            } else {
                runHistoryView(metadata: metadata)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private func sectionHeader(metadata: RecurringMetadata?, isRecurring: Bool) -> some View {
        HStack(spacing: 8) {
            uppercaseLabel("Recurring")
            Spacer()
            if isRecurring, let metadata {
                recurringCounterPill(metadata)
            }
        }
    }

    private func uppercaseLabel(_ label: String) -> some View {
        Text(label)
            .font(WorkstationTheme.Fonts.label)
            .foregroundStyle(WorkstationTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.7)
    }

    private func recurringCounterPill(_ metadata: RecurringMetadata) -> some View {
        let overdue = metadata.overdueDays(now: Date())
        let label: String
        if overdue > 0 {
            label = "Overdue \(overdue)d"
        } else if metadata.completionCount > 0 {
            label = "Run #\(metadata.completionCount)"
        } else {
            label = "No runs yet"
        }
        return BadgeView(style: .recurring(isOverdue: overdue > 0), verticalPadding: 3) {
            Text(label)
                .font(WorkstationTheme.Fonts.body(10, weight: .bold))
        }
    }

    @ViewBuilder
    private func cadencePickerView(currentDays: Int?) -> some View {
        let current = CadenceTarget.from(days: currentDays)
        HStack(spacing: 6) {
            Text("Cadence")
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.6)
            ForEach(CadenceTarget.allCases, id: \.self) { option in
                cadenceChip(option: option, isSelected: option == current)
            }
            Spacer()
        }
    }

    private func cadenceChip(option: CadenceTarget, isSelected: Bool) -> some View {
        Button {
            appVM.setCadence(for: issue.id, days: option.days)
        } label: {
            BadgeView(style: isSelected ? .accent : .surface, horizontalPadding: 10, verticalPadding: 5) {
                Text(cadenceShortLabel(option))
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
    }

    private func cadenceShortLabel(_ option: CadenceTarget) -> String {
        switch option {
        case .none: return "None"
        case .weekly: return "7d"
        case .monthly: return "30d"
        case .quarterly: return "90d"
        }
    }

    private func runCompletionInput() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Optional notes for this run (what was done, what to remember next time)", text: $recurringNotesDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .lineLimit(2...4)
                .padding(10)
                .background(WorkstationTheme.cardAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

            Button {
                let notes = recurringNotesDraft
                Task { @MainActor in
                    let ok = await appVM.completeRecurringRun(for: issue.id, notes: notes)
                    if ok {
                        recurringNotesDraft = ""
                        flashRecurringAction("Run logged — issue reset to Ready")
                    }
                }
            } label: {
                Label("Mark Run Complete", systemImage: "checkmark.arrow.trianglehead.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationPrimaryButtonStyle())
            .disabled(issue.status == "closed" || isLoading)
            .help("Append a history entry and reset this issue back to Ready (does not close)")
        }
    }

    private func flashRecurringAction(_ message: String) {
        withAnimation(.easeOut(duration: 0.15)) { recurringActionFlash = message }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeOut(duration: 0.15)) { recurringActionFlash = nil }
        }
    }

    @ViewBuilder
    private func runHistoryView(metadata: RecurringMetadata) -> some View {
        let entries = metadata.history.sorted(by: { $0.completedAt > $1.completedAt })
        VStack(alignment: .leading, spacing: 8) {
            Text("Run history")
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
                .tracking(0.6)
            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    runHistoryRow(entry: entry, isFirst: index == 0)
                }
                if entries.count > 5 {
                    Text("+ \(entries.count - 5) older runs")
                        .font(WorkstationTheme.Fonts.body(11))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        }
    }

    private func runHistoryRow(entry: RecurringHistoryEntry, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.green)
                Text(entry.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                if let by = entry.completedBy, !by.isEmpty {
                    Text("· \(by)")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
                Spacer()
            }
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 19)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle()
                    .fill(WorkstationTheme.borderSoft)
                    .frame(height: 1)
            }
        }
    }
}

enum IssueDetailRecurringDisplayMode {
    case full
    case controls
    case history
}
