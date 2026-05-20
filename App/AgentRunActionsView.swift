import SwiftUI

struct AgentRunActionsView: View {
    let record: AgentRunRecord
    let onUpdateStatus: (AgentRunStatus) -> Void

    private let statuses: [AgentRunStatus] = [.needsReview, .accepted, .failed, .abandoned]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mark Run As")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                Text("Current: \(record.status.displayName)")
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSecondary)
            }

            FlowLayout(spacing: 8) {
                ForEach(statuses, id: \.self) { status in
                    Button {
                        onUpdateStatus(status)
                    } label: {
                        Text(status.displayName)
                    }
                    .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                    .disabled(record.status == status)
                    .help("Update local run status to \(status.displayName). Does not modify the Beads issue.")
                }
            }

            Text("These statuses only affect this app's local run record. Beads issue status is not changed automatically.")
                .font(WorkstationTheme.Fonts.body(11, weight: .regular))
                .foregroundStyle(WorkstationTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
