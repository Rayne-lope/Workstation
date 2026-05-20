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
    }
}
