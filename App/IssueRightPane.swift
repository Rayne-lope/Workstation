import SwiftUI

struct IssueRightPane: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore
    let issue: BeadIssue

    var body: some View {
        ZStack {
            switch appVM.detailPaneMode {
            case .issue:
                IssueDetailView(appVM: appVM, store: store, issue: issue)
                    .transition(.opacity)
            case .console:
                AgentRunConsolePane(appVM: appVM, issue: issue)
                    .transition(.opacity)
            case .bulkAction:
                BulkActionPanel(appVM: appVM, store: store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: appVM.detailPaneMode)
        .onChange(of: issue.id) { _, _ in
            if !store.hasMultiSelection {
                appVM.resetDetailPaneToIssue()
            }
        }
    }
}
