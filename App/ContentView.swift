import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @Bindable var appVM: AppViewModel

    var body: some View {
        Group {
            if let store = appVM.issueStore {
                BoardView(appVM: appVM, workspaceVM: viewModel, store: store)
            } else {
                WelcomeView(
                    viewModel: viewModel,
                    recentProjectsStore: appVM.recentProjectsStore,
                    appVM: appVM
                )
            }
        }
        .sheet(item: $appVM.localAISuggestionPreview, onDismiss: {
            appVM.dismissLocalAISuggestionPreview()
        }) { preview in
            LocalAISuggestionPreviewSheet(
                preview: preview,
                onDismiss: { appVM.dismissLocalAISuggestionPreview() }
            )
        }
        .sheet(isPresented: Binding(
            get: { appVM.commandPaletteStore != nil },
            set: { if !$0 { appVM.dismissCommandPalette() } }
        )) {
            if let store = appVM.commandPaletteStore {
                CommandPaletteSheet(store: store)
            }
        }
        .sheet(isPresented: $appVM.isQuickCapturePresented) {
            if let store = appVM.quickCaptureStore {
                QuickCaptureSheet(store: store)
            }
        }
        .sheet(isPresented: $appVM.isApprovalConfirmationPresented) {
            if let approval = appVM.pendingCriticalApproval {
                ApprovalConfirmationSheet(
                    approval: approval,
                    onConfirm: { appVM.confirmCriticalApproval() },
                    onCancel: { appVM.dismissApprovalConfirmation() }
                )
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appVM.preferencesStore.preferences.theme {
        case .light:
            return .light
        case .obsidianDark, .beadsDark:
            return .dark
        case .system:
            return nil
        }
    }
}
