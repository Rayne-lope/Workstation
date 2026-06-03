import SwiftUI
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

struct SchedulerSettingsPanelView: View {
    @Bindable var appVM: AppViewModel

    private var prefs: SchedulerPreferences {
        appVM.preferencesStore.preferences.scheduler
    }

    private var executorProfiles: [AgentProfile] {
        appVM.agentProfileStore.profiles.filter { $0.canExecuteCode && $0.shouldClaimIssue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                // Enable/Disable
                card {
                    VStack(alignment: .leading, spacing: 16) {
                        ToggleRow(
                            icon: "clock.arrow.2.circlepath",
                            title: "Enable Auto-Scheduler",
                            subtitle: "Automatically claim and launch issues assigned to agent executors",
                            isOn: Binding(
                                get: { prefs.isEnabled },
                                set: { val in
                                    appVM.preferencesStore.update { $0.scheduler.isEnabled = val }
                                    if val { appVM.agentScheduler.start() } else { appVM.agentScheduler.stop() }
                                }
                            )
                        )

                        if prefs.isEnabled {
                            Divider().overlay(WorkstationTheme.borderSoft)
                            schedulerStatus
                        }
                    }
                }

                if prefs.isEnabled {
                    // Config
                    card {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionLabel("Behavior")
                            pollIntervalRow
                            Divider().overlay(WorkstationTheme.borderSoft)
                            maxConcurrentRow
                            Divider().overlay(WorkstationTheme.borderSoft)
                            approvalGateRow
                        }
                    }

                    // Per-profile toggles
                    if !executorProfiles.isEmpty {
                        card {
                            VStack(alignment: .leading, spacing: 16) {
                                sectionLabel("Per-Agent Settings")
                                ForEach(Array(executorProfiles.enumerated()), id: \.element.id) { idx, profile in
                                    if idx > 0 { Divider().overlay(WorkstationTheme.borderSoft) }
                                    profileRow(profile)
                                }
                            }
                        }
                    }

                    // Pending approvals
                    if !appVM.agentScheduler.pendingApprovals.isEmpty {
                        card {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionLabel("Pending Approvals")
                                ForEach(appVM.agentScheduler.pendingApprovals) { launch in
                                    pendingApprovalRow(launch)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkstationTheme.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scheduler")
                .font(WorkstationTheme.Fonts.display(22, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Text("Auto-claim and launch issues assigned to agent executors")
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
    }

    // MARK: - Status

    private var schedulerStatus: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            Text(stateLabel)
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textSecondary)
            if let last = appVM.agentScheduler.lastPollAt {
                Spacer()
                Text("Last poll: \(last.formatted(.relative(presentation: .named)))")
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
        }
    }

    private var stateColor: Color {
        switch appVM.agentScheduler.state {
        case .idle: return WorkstationTheme.green
        case .polling, .launching: return WorkstationTheme.accent
        case .paused: return WorkstationTheme.red
        }
    }

    private var stateLabel: String {
        switch appVM.agentScheduler.state {
        case .idle: return "Idle"
        case .polling: return "Polling…"
        case .launching(let id): return "Launching \(id)…"
        case .paused(let reason): return "Paused: \(reason)"
        }
    }

    // MARK: - Config Rows

    private var pollIntervalRow: some View {
        HStack {
            Label("Check every", systemImage: "timer")
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Spacer()
            Picker("", selection: Binding(
                get: { prefs.pollIntervalSeconds },
                set: { val in appVM.preferencesStore.update { $0.scheduler.pollIntervalSeconds = val } }
            )) {
                Text("30s").tag(30)
                Text("1 min").tag(60)
                Text("2 min").tag(120)
                Text("5 min").tag(300)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    private var maxConcurrentRow: some View {
        HStack {
            Label("Max concurrent agents", systemImage: "person.2")
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Spacer()
            Stepper("\(prefs.maxConcurrentRuns)", value: Binding(
                get: { prefs.maxConcurrentRuns },
                set: { val in appVM.preferencesStore.update { $0.scheduler.maxConcurrentRuns = max(1, min(4, val)) } }
            ), in: 1...4)
            .frame(width: 120)
        }
    }

    private var approvalGateRow: some View {
        ToggleRow(
            icon: "hand.raised",
            title: "Require approval before each launch",
            subtitle: "Issues queue in Pending Approvals instead of launching automatically",
            isOn: Binding(
                get: { prefs.requireApprovalBeforeLaunch },
                set: { val in appVM.preferencesStore.update { $0.scheduler.requireApprovalBeforeLaunch = val } }
            )
        )
    }

    // MARK: - Per-profile Row

    private func profileRow(_ profile: AgentProfile) -> some View {
        let key = profile.id.uuidString
        let profilePrefs = prefs.perProfileSettings[key] ?? SchedulerProfileSettings()
        return HStack(spacing: 12) {
            AssigneeBadgeView(assignee: profile.claimAssigneeToken, profiles: appVM.agentProfileStore.profiles, compact: true, showName: false)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Daily limit: \(profilePrefs.dailyRunLimit) runs")
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
            Spacer()
            Stepper("\(profilePrefs.dailyRunLimit)/day", value: Binding(
                get: { profilePrefs.dailyRunLimit },
                set: { val in
                    appVM.preferencesStore.update { prefs in
                        var ps = prefs.scheduler.perProfileSettings[key] ?? SchedulerProfileSettings()
                        ps.dailyRunLimit = max(1, min(20, val))
                        prefs.scheduler.perProfileSettings[key] = ps
                    }
                }
            ), in: 1...20)
            .frame(width: 120)
            Toggle("", isOn: Binding(
                get: { profilePrefs.enabled },
                set: { val in
                    appVM.preferencesStore.update { prefs in
                        var ps = prefs.scheduler.perProfileSettings[key] ?? SchedulerProfileSettings()
                        ps.enabled = val
                        prefs.scheduler.perProfileSettings[key] = ps
                    }
                }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.8)
        }
    }

    // MARK: - Pending Approval Row

    private func pendingApprovalRow(_ launch: ScheduledLaunch) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(launch.issueTitle)
                    .font(WorkstationTheme.Fonts.body(13, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(1)
                Text("\(launch.issueID) · \(launch.profileName)")
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
            Spacer()
            Button("Approve") {
                appVM.agentScheduler.approveLaunch(launch)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(WorkstationTheme.green)
            Button("Reject") {
                appVM.agentScheduler.rejectLaunch(launch)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(WorkstationTheme.cardAlt)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Card Helper

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(WorkstationTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(WorkstationTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(WorkstationTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
