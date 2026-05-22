import AppKit
import SwiftUI

// MARK: - Quick Capture Store

@MainActor
final class QuickCaptureStore: ObservableObject {
    let store: IssueStore
    let appVM: AppViewModel

    @Published var title: String = ""
    @Published var issueType: String = "task"
    @Published var createdIssueID: String?
    @Published var showToast: Bool = false
    @Published var isSubmitting: Bool = false

    private let issueTypes = ["task", "bug", "feature", "epic", "chore"]

    init(store: IssueStore, appVM: AppViewModel) {
        self.store = store
        self.appVM = appVM
        seedFromClipboard()
    }

    private func seedFromClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string),
           !clipboardString.isEmpty,
           clipboardString.count <= 200 {
            title = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func cycleIssueType() {
        guard let currentIdx = issueTypes.firstIndex(of: issueType) else { return }
        let nextIdx = (currentIdx + 1) % issueTypes.count
        issueType = issueTypes[nextIdx]
    }

    func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isSubmitting = true
        let input = CreateIssueInput(
            title: trimmedTitle,
            issueType: issueType,
            priority: 2
        )

        Task {
            await store.createIssue(input)
            let createdID = store.issues.first?.id
            await MainActor.run {
                self.isSubmitting = false
                if let id = createdID {
                    self.createdIssueID = id
                    self.showToast = true
                    // Auto-dismiss toast after 4 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(4))
                        await MainActor.run {
                            self.showToast = false
                        }
                    }
                }
                self.appVM.dismissQuickCapture()
            }
        }
    }
}

// MARK: - Quick Capture Toast

struct QuickCaptureToast: View {
    let issueID: String
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WorkstationTheme.green)

            VStack(alignment: .leading, spacing: 1) {
                Text("Issue created")
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)

                Text(issueID)
                    .font(WorkstationTheme.Fonts.body(11))
                    .foregroundStyle(WorkstationTheme.accent)
            }

            Spacer()

            Button { onTap() } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 320)
        .background(WorkstationTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Quick Capture Sheet

struct QuickCaptureSheet: View {
    @StateObject var store: QuickCaptureStore
    @FocusState private var isFocused: Bool
    @State private var toastIssueID: String?

    init(store: QuickCaptureStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WorkstationTheme.accent)

                Text("QUICK CAPTURE")
                    .font(WorkstationTheme.Fonts.body(9, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .textCase(.uppercase)

                Spacer()

                Button { store.appVM.dismissQuickCapture() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().overlay(WorkstationTheme.borderSoft)

            // Input area
            VStack(alignment: .leading, spacing: 12) {
                // Title input
                ZStack(alignment: .leading) {
                    if store.title.isEmpty {
                        Text("What needs to be done?")
                            .font(WorkstationTheme.Fonts.body(14))
                            .foregroundStyle(WorkstationTheme.textSubtle)
                    }
                    TextField("", text: $store.title)
                        .font(WorkstationTheme.Fonts.body(14, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit { store.submit() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(WorkstationTheme.cardAlt)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

                // Footer: type selector + submit
                HStack(spacing: 10) {
                    // Type selector
                    Button {
                        store.cycleIssueType()
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(typeColor(store.issueType))
                                .frame(width: 5, height: 5)
                            Text(store.issueType.capitalized)
                                .font(WorkstationTheme.Fonts.body(11.5, weight: .semibold))
                            Text("TAB")
                                .font(WorkstationTheme.Fonts.body(9, weight: .bold))
                                .foregroundStyle(WorkstationTheme.textSubtle)
                        }
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(WorkstationTheme.cardAlt)
                        .overlay(
                            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text("Priority: P2 default")
                        .font(WorkstationTheme.Fonts.body(10))
                        .foregroundStyle(WorkstationTheme.textSubtle)

                    Spacer()

                    if store.isSubmitting {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(WorkstationTheme.accent)
                    } else {
                        Button {
                            store.submit()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Create")
                            }
                            .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                            .foregroundStyle(WorkstationTheme.background)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(store.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? WorkstationTheme.textMuted
                                : WorkstationTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(width: 400)
        .background(WorkstationTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous)
                .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.panel, style: .continuous))
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 8)
        .onAppear { isFocused = true }
        .onKeyPress(.tab) {
            store.cycleIssueType()
            return .handled
        }
        .onChange(of: store.showToast) { _, newValue in
            if newValue {
                toastIssueID = store.createdIssueID
            }
        }
        .overlay(alignment: .bottom) {
            if store.showToast, let id = toastIssueID {
                QuickCaptureToast(issueID: id) {
                    store.store.selectIssue(id: id)
                    store.appVM.dismissQuickCapture()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, -50)
            }
        }
        .animation(.spring(response: 0.3, blendDuration: 0.2), value: store.showToast)
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "bug": return WorkstationTheme.red
        case "feature": return WorkstationTheme.accent
        case "epic": return WorkstationTheme.purple
        case "chore": return WorkstationTheme.textMuted
        default: return WorkstationTheme.blue
        }
    }
}