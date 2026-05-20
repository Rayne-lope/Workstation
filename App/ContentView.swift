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
    }
}
