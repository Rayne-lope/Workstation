import SwiftUI

struct AgentRunNotesView: View {
    @Binding var notes: String
    let isDirty: Bool
    let onSave: () -> Void
    let onRevert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Notes")
                    .font(WorkstationTheme.Fonts.label)
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                if isDirty {
                    Text("Unsaved")
                        .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.orange)
                }
            }

            TextEditor(text: $notes)
                .font(.system(size: 12))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 110)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

            HStack(spacing: 8) {
                Spacer()
                Button {
                    onRevert()
                } label: {
                    Text("Revert")
                }
                .buttonStyle(WorkstationGhostButtonStyle(compact: true))
                .disabled(!isDirty)

                Button {
                    onSave()
                } label: {
                    Label("Save Notes", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(!isDirty)
            }
        }
    }
}
