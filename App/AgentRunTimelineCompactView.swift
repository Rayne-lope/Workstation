import SwiftUI

/// Compact timeline view for the Issue Detail Pane.
/// Shows latest 5 grouped events, current status header, control actions, and pinned approval cards.
/// Follows Craftboard Style Guide (dark charcoal surfaces, thin borders, gold/amber highlights).
struct AgentRunTimelineCompactView: View {
    @Bindable var appVM: AppViewModel
    let runID: UUID
    let issueID: String

    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil
    @State private var approvalExpanded: Bool = false

    private var runRecord: AgentRunRecord? {
        appVM.agentRunHistoryStore.record(id: runID)
    }

    private var events: [AgentTimelineEvent] {
        AgentTimelineStore.shared.compactEvents(forRunID: runID)
    }

    private var activeApproval: AgentApprovalRequest? {
        AgentTimelineStore.shared.activeApproval(forRunID: runID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status header with agent name, status badge, and elapsed timer
            statusHeader

            if !events.isEmpty || activeApproval != nil {
                Divider()
                    .overlay(WorkstationTheme.borderSoft)
                    .padding(.vertical, 8)

                // Timeline node list (latest 5 events)
                if !events.isEmpty {
                    timelineEventList
                }

                // Interactive approval card (pinned prominently if active)
                if let approval = activeApproval {
                    Divider()
                        .overlay(WorkstationTheme.borderSoft)
                        .padding(.vertical, 6)
                    approvalCard(for: approval)
                }

                Divider()
                    .overlay(WorkstationTheme.borderSoft)
                    .padding(.vertical, 6)

                // Control action row
                controlActionsRow
            }
        }
        .padding(14)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(WorkstationTheme.accentBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 10) {
            // Agent name and status
            VStack(alignment: .leading, spacing: 4) {
                Text(runRecord?.agentName ?? "Agent")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)

                    Text(runRecord?.status.displayName ?? "Running")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(statusColor)

                    if elapsedSeconds > 0 {
                        Text("·")
                            .font(WorkstationTheme.Fonts.body(11))
                            .foregroundStyle(WorkstationTheme.textMuted)

                        Text(elapsedTimeString)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(WorkstationTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // Quick stat badges
            if let record = runRecord {
                let eventCount = events.count
                HStack(spacing: 8) {
                    if eventCount > 0 {
                        statBadge(icon: "list.bullet", value: "\(eventCount)")
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        guard let record = runRecord else { return WorkstationTheme.accent }
        switch record.status {
        case .prepared, .terminalOpened:
            return WorkstationTheme.accent
        case .needsReview:
            return WorkstationTheme.blue
        case .accepted:
            return WorkstationTheme.green
        case .failed, .abandoned:
            return WorkstationTheme.red
        }
    }

    private var elapsedTimeString: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func statBadge(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(WorkstationTheme.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(WorkstationTheme.cardAlt)
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    // MARK: - Timeline Event List

    private var timelineEventList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.stableKey) { index, event in
                timelineEventRow(event, isLast: index == events.count - 1)
            }
        }
    }

    private func timelineEventRow(_ event: AgentTimelineEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Connector line + status indicator
            VStack(spacing: 0) {
                // Top connector (hidden for first item)
                if indexOf(event) > 0 {
                    Rectangle()
                        .fill(WorkstationTheme.borderSoft)
                        .frame(width: 1.5, height: 8)
                } else {
                    Spacer().frame(height: 8)
                }

                // Status indicator dot
                statusDot(for: event)
                    .frame(width: 14, height: 14)

                // Bottom connector (hidden for last item)
                if !isLast {
                    Rectangle()
                        .fill(WorkstationTheme.borderSoft)
                        .frame(width: 1.5, height: 8)
                }
            }
            .frame(width: 14)

            // Event content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                    .lineLimit(1)

                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(WorkstationTheme.Fonts.body(10))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func indexOf(_ event: AgentTimelineEvent) -> Int {
        events.firstIndex(where: { $0.stableKey == event.stableKey }) ?? 0
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

    // MARK: - Approval Card

    private func approvalCard(for approval: AgentApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(riskHeaderColor(for: approval.riskLevel))

                Text("Approval Required")
                    .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                    .foregroundStyle(riskHeaderColor(for: approval.riskLevel))

                Spacer()

                // Risk level badge
                riskLevelBadge(approval.riskLevel)
            }

            // Prompt text
            Text(approval.prompt)
                .font(WorkstationTheme.Fonts.body(10))
                .foregroundStyle(WorkstationTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Action buttons based on risk level
            approvalActions(for: approval)
        }
        .padding(10)
        .background(riskCardBackground(for: approval.riskLevel))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(riskCardBorder(for: approval.riskLevel), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private func approvalActions(for approval: AgentApprovalRequest) -> some View {
        switch approval.riskLevel {
        case .low, .medium:
            lowMediumApprovalActions(for: approval)
        case .high:
            highApprovalActions(for: approval)
        case .critical:
            criticalApprovalActions(for: approval)
        }
    }

    private func lowMediumApprovalActions(for approval: AgentApprovalRequest) -> some View {
        HStack(spacing: 8) {
            // Approve button
            Button {
                handleApproval(runID: runID, approved: true, forApproval: approval)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Approve")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                }
                .foregroundStyle(WorkstationTheme.card)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(WorkstationTheme.green)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            }
            .buttonStyle(.plain)

            // Reject button
            Button {
                handleApproval(runID: runID, approved: false, forApproval: approval)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Reject")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                }
                .foregroundStyle(WorkstationTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(WorkstationTheme.cardAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()

            // View Raw Log button
            Button {
                appVM.showConsolePane(forIssueID: issueID)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Raw Log")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                }
                .foregroundStyle(WorkstationTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
    }

    private func highApprovalActions(for approval: AgentApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Expand button
            if !approvalExpanded {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        approvalExpanded = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Expand Details")
                            .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                    }
                    .foregroundStyle(WorkstationTheme.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(WorkstationTheme.orangeBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                            .stroke(WorkstationTheme.orangeBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if approvalExpanded {
                // Expanded details
                VStack(alignment: .leading, spacing: 8) {
                    // Command preview if available
                    if let command = approval.commandPreview, !command.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(WorkstationTheme.textMuted)
                            Text(command)
                                .font(WorkstationTheme.Fonts.body(10, weight: .medium).monospaced())
                                .foregroundStyle(WorkstationTheme.textMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WorkstationTheme.cardAlt)
                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                    }

                    // Affected files
                    if !approval.filePreview.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AFFECTED FILES")
                                .font(WorkstationTheme.Fonts.label)
                                .foregroundStyle(WorkstationTheme.textMuted)
                                .textCase(.uppercase)
                                .tracking(0.3)

                            ForEach(approval.filePreview.prefix(3), id: \.self) { file in
                                HStack(spacing: 6) {
                                    Image(systemName: "doc")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(WorkstationTheme.textMuted)
                                    Text(file)
                                        .font(WorkstationTheme.Fonts.body(10))
                                        .foregroundStyle(WorkstationTheme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            if approval.filePreview.count > 3 {
                                Text("+ \(approval.filePreview.count - 3) more")
                                    .font(WorkstationTheme.Fonts.body(9))
                                    .foregroundStyle(WorkstationTheme.textMuted)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 8) {
                        // Approve button
                        Button {
                            handleApproval(runID: runID, approved: true, forApproval: approval)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Approve Once")
                                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                            }
                            .foregroundStyle(WorkstationTheme.card)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(WorkstationTheme.orange)
                            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        // Reject button
                        Button {
                            handleApproval(runID: runID, approved: false, forApproval: approval)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Reject")
                                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                            }
                            .foregroundStyle(WorkstationTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(WorkstationTheme.cardAlt)
                            .overlay(
                                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    // Raw Terminal button
                    Button {
                        appVM.showConsolePane(forIssueID: issueID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Raw Terminal")
                                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                        }
                        .foregroundStyle(WorkstationTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func criticalApprovalActions(for approval: AgentApprovalRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Warning message
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.red)
                Text("Critical operation — requires explicit confirmation")
                    .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.red)
            }

            // Open confirmation sheet button
            Button {
                appVM.presentCriticalApprovalConfirmation(for: approval)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Open Confirmation")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                }
                .foregroundStyle(WorkstationTheme.card)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(WorkstationTheme.red)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            }
            .buttonStyle(.plain)

            // Raw Terminal fallback
            Button {
                appVM.showConsolePane(forIssueID: issueID)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Handle manually in Raw Terminal")
                        .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                }
                .foregroundStyle(WorkstationTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Risk-based Color Helpers

    private func riskHeaderColor(for level: ApprovalRiskLevel) -> Color {
        switch level {
        case .low, .medium:
            return WorkstationTheme.orange
        case .high:
            return WorkstationTheme.orange
        case .critical:
            return WorkstationTheme.red
        }
    }

    private func riskCardBackground(for level: ApprovalRiskLevel) -> Color {
        switch level {
        case .low, .medium:
            return WorkstationTheme.orangeBg
        case .high:
            return WorkstationTheme.orangeBg
        case .critical:
            return WorkstationTheme.redBg
        }
    }

    private func riskCardBorder(for level: ApprovalRiskLevel) -> Color {
        switch level {
        case .low, .medium:
            return WorkstationTheme.orangeBorder
        case .high:
            return WorkstationTheme.orangeBorder
        case .critical:
            return WorkstationTheme.redBorder
        }
    }

    private func riskLevelBadge(_ level: ApprovalRiskLevel) -> some View {
        let (label, color, bg, border) = {
            switch level {
            case .low:
                return ("Low", WorkstationTheme.green, WorkstationTheme.greenBg, WorkstationTheme.greenBorder)
            case .medium:
                return ("Medium", WorkstationTheme.textSecondary, WorkstationTheme.cardAlt, WorkstationTheme.borderStrong)
            case .high:
                return ("High", WorkstationTheme.orange, WorkstationTheme.orangeBg, WorkstationTheme.orangeBorder)
            case .critical:
                return ("Critical", WorkstationTheme.red, WorkstationTheme.redBg, WorkstationTheme.redBorder)
            }
        }()

        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    // MARK: - Control Actions Row

    private var controlActionsRow: some View {
        HStack(spacing: 8) {
            // Kill Agent button
            Button {
                appVM.killActiveAgent(runID: runID)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Kill Agent")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                }
                .foregroundStyle(WorkstationTheme.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(WorkstationTheme.redBg)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(WorkstationTheme.redBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Cancel the agent run")

            Spacer()

            // View Full Run / Raw Log button
            Button {
                appVM.showConsolePane(forIssueID: issueID)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 10, weight: .semibold))
                    Text("View Full Run")
                        .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                }
                .foregroundStyle(WorkstationTheme.textMuted)
            }
            .buttonStyle(.plain)
            .help("Open the full run console")
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        // Initialize elapsed time from run record
        if let record = runRecord {
            if let completed = record.completedAt {
                elapsedSeconds = max(0, Int(completed.timeIntervalSince(record.startedAt)))
            } else {
                elapsedSeconds = max(0, Int(Date().timeIntervalSince(record.startedAt)))
            }
        }

        // Start 1-second ticker
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            Task { @MainActor in
                if let record = self.runRecord {
                    if record.status.isFinalized {
                        if let completed = record.completedAt {
                            self.elapsedSeconds = max(0, Int(completed.timeIntervalSince(record.startedAt)))
                        }
                        self.stopTimer()
                    } else {
                        let elapsed = Int(Date().timeIntervalSince(record.startedAt))
                        self.elapsedSeconds = max(0, elapsed)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Approval Handling

    /// Handles approval action with proper validation following the safety contract.
    /// - Validates approval is still active and prompt hash matches
    /// - Transitions state to responding before writing
    /// - Updates final state based on PTY write success
    private func handleApproval(runID: UUID, approved: Bool, forApproval approval: AgentApprovalRequest) {
        // 1. Validate approval is still active in the store
        guard let activeApproval = AgentTimelineStore.shared.activeApproval(forRunID: runID) else {
            return
        }

        // 2. Validate state is still .active (not stale/expired/already responded)
        guard activeApproval.state == .active else { return }

        // 3. Validate prompt hash matches (prevent stale approvals)
        guard activeApproval.promptHash == approval.promptHash else { return }

        // 4. Set state to responding
        AgentTimelineStore.shared.updateApprovalState(forRunID: runID, newState: .responding)

        // 5. Get the appropriate input
        let input = approved ? approval.proposedInput : approval.rejectInput

        // 6. Write to PTY
        let success = PTYProcessRegistry.shared.writeInput(for: runID, text: input)

        // 7. Update final state based on write result
        let finalState: ApprovalState = success ? (approved ? .accepted : .rejected) : .failedToSend
        AgentTimelineStore.shared.updateApprovalState(forRunID: runID, newState: finalState)
    }
}