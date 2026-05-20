import SwiftUI

struct BulkActionPanel: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore

    private var selected: [BeadIssue] {
        store.selectedIssues()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider().overlay(WorkstationTheme.borderSoft)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(selected) { issue in
                        selectedRow(issue: issue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            Divider().overlay(WorkstationTheme.borderSoft)

            actions
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(maxHeight: .infinity)
        .background(WorkstationTheme.surface)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CRAFTBOARD / BULK")
                    .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(WorkstationTheme.textSubtle)
                Text("\(selected.count) issues selected")
                    .font(WorkstationTheme.Fonts.display(20, weight: .heavy))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Cmd-click to toggle · Shift-click for range · Esc to clear")
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
            Spacer()
            Button {
                appVM.clearMultiSelection()
            } label: {
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
            .help("Clear selection (Esc)")
        }
    }

    private func selectedRow(issue: BeadIssue) -> some View {
        HStack(spacing: 10) {
            Text(issue.id)
                .font(WorkstationTheme.Fonts.body(10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(WorkstationTheme.accent)
                .frame(minWidth: 84, alignment: .leading)
            Text(issue.title)
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .lineLimit(2)
            Spacer()
            Button {
                store.toggleSelection(id: issue.id)
                if !store.hasMultiSelection {
                    appVM.resetDetailPaneToIssue()
                }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
            .buttonStyle(.plain)
            .help("Remove from selection")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(WorkstationTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                appVM.bulkClaim()
            } label: {
                Label("Claim All", systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationPrimaryButtonStyle())
            .disabled(store.isLoading)

            Button {
                appVM.bulkMarkHumanReview()
            } label: {
                Label("Mark Human Review", systemImage: "exclamationmark.bubble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationGhostButtonStyle())
            .disabled(store.isLoading)

            Button {
                appVM.presentBulkCloseSheet()
            } label: {
                Label("Close All…", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationGhostButtonStyle())
            .disabled(store.isLoading)

            Button {
                appVM.clearMultiSelection()
            } label: {
                Label("Clear Selection", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkstationGhostButtonStyle())
        }
    }
}

struct BulkCloseSheet: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore
    let onDismiss: () -> Void

    @State private var reason: String
    @FocusState private var reasonFocused: Bool

    init(
        appVM: AppViewModel,
        store: IssueStore,
        defaultReason: String = "",
        onDismiss: @escaping () -> Void
    ) {
        self.appVM = appVM
        self.store = store
        self.onDismiss = onDismiss
        _reason = State(initialValue: defaultReason)
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var count: Int { store.selectedIssueIDs.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CRAFTBOARD / BULK")
                        .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                        .tracking(0.9)
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Text("Close \(count) Issues")
                        .font(WorkstationTheme.Fonts.display(22, weight: .heavy))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                }
                Spacer()
                Button(action: onDismiss) {
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
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 18)

            Divider().overlay(WorkstationTheme.borderSoft)

            VStack(alignment: .leading, spacing: 18) {
                Text("The same reason will be applied to all \(count) selected issues.")
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textMuted)

                VStack(alignment: .leading, spacing: 8) {
                    Text("REASON")
                        .font(WorkstationTheme.Fonts.body(10.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    StyledTextEditor(
                        placeholder: "e.g. Batch closed — superseded by Workstation-xyz.",
                        text: $reason,
                        minHeight: 120,
                        isFocused: reasonFocused
                    )
                    .focused($reasonFocused)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(WorkstationTheme.background)

            Divider().overlay(WorkstationTheme.borderSoft)

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(WorkstationGhostButtonStyle())
                    .keyboardShortcut(.cancelAction)

                Button {
                    appVM.bulkClose(reason: reason)
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Close \(count) Issues")
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedReason.isEmpty)
                .opacity(trimmedReason.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 480)
        .background(WorkstationTheme.surface)
        .preferredColorScheme(.dark)
        .onAppear { reasonFocused = true }
    }
}
