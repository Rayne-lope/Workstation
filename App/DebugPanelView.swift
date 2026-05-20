import SwiftUI

struct DebugPanelView: View {
    let history: [CommandSnapshot]
    let latestDecodeFailureRawJSON: String?
    let agentRunHistoryStore: AgentRunHistoryStore
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Debug Panel")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Close") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            rawJSONSection
            recentAgentRunsSection

            if history.isEmpty {
                Text("No commands recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(history.enumerated().reversed()), id: \.offset) { _, snapshot in
                            row(snapshot)
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 860, height: 620)
    }

    @ViewBuilder
    private var rawJSONSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest JSON Decode Failure")
                .font(.headline)
            if let raw = latestDecodeFailureRawJSON, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ScrollView {
                    Text(raw)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
                .padding(10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text("No JSON decode failures recorded.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var recentAgentRunsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Agent Runs")
                    .font(.headline)
                Spacer()
                Text("\(agentRunHistoryStore.records.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let error = agentRunHistoryStore.errorMessage, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if agentRunHistoryStore.records.isEmpty {
                Text("No agent runs recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(agentRunHistoryStore.records) { record in
                            agentRunRow(record)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func row(_ snapshot: CommandSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(([snapshot.command] + snapshot.arguments).joined(separator: " "))
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                Spacer()
                Text("exit \(snapshot.exitCode)")
                    .foregroundStyle(snapshot.exitCode == 0 ? .green : .orange)
            }
            HStack {
                Text(snapshot.workingDirectory.path)
                Spacer()
                Text("\(snapshot.durationMs) ms")
                Text(snapshot.timestamp.formatted(date: .omitted, time: .standard))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let err = snapshot.errorMessage {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            if !snapshot.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("stdout: \(snapshot.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !snapshot.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("stderr: \(snapshot.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func agentRunRow(_ record: AgentRunRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(record.issueID)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(record.issueTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Text(record.projectPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    statusMenu(for: record)
                    Text(record.agentName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let completedAt = record.completedAt {
                Text("Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let notes = record.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusMenu(for record: AgentRunRecord) -> some View {
        Menu(record.status.displayName) {
            ForEach([AgentRunStatus.needsReview, .accepted, .failed, .abandoned], id: \.self) { status in
                Button(status.displayName) {
                    agentRunHistoryStore.updateStatus(id: record.id, status: status)
                }
                .disabled(record.status == status)
            }
        }
        .menuStyle(.borderlessButton)
    }
}
