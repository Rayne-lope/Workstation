import SwiftUI
import AppKit
import Foundation
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

struct IssueRightPane: View {
    @Bindable var appVM: AppViewModel
    let store: IssueStore
    let issue: BeadIssue?

    var body: some View {
        ZStack {
            switch appVM.detailPaneMode {
            case .issue:
                if let issue {
                    IssueDetailView(appVM: appVM, store: store, issue: issue)
                        .transition(.opacity)
                }
            case .console:
                if let issue {
                    AgentRunConsolePane(appVM: appVM, issue: issue)
                        .transition(.opacity)
                }
            case .bulkAction:
                BulkActionPanel(appVM: appVM, store: store)
                    .transition(.opacity)
            case .copilot:
                WorkflowCopilotPane(appVM: appVM, store: store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: appVM.detailPaneMode)
        .onChange(of: issue?.id) { _, _ in
            guard appVM.detailPaneMode != .bulkAction else { return }
            guard appVM.detailPaneMode != .copilot else { return }
            if !store.hasMultiSelection {
                appVM.resetDetailPaneToIssue()
            }
        }
    }
}
