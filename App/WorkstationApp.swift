import SwiftUI

@main
struct WorkstationApp: App {
    @StateObject private var viewModel: WorkspaceViewModel
    @State private var appVM: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let runner = ShellCommandRunner()
        let workspaceVM = WorkspaceViewModel(shellRunner: runner)
        let appViewModel = AppViewModel(shellRunner: runner)
        appViewModel.bind(workspaceVM: workspaceVM)
        _viewModel = StateObject(wrappedValue: workspaceVM)
        _appVM = State(initialValue: appViewModel)

        let prefs = appViewModel.preferencesStore.preferences
        if prefs.autoRestoreOnLaunch,
           let path = prefs.lastSelectedPath,
           FileManager.default.fileExists(atPath: path) {
            workspaceVM.loadWorkspace(from: URL(fileURLWithPath: path, isDirectory: true))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, appVM: appVM)
        }
        .windowResizability(.contentMinSize)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            guard appVM.preferencesStore.preferences.autoReloadEnabled else { return }
            appVM.reloadIssues()
        }
    }
}
