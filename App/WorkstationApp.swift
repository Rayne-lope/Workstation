import AppKit
import SwiftUI

/// Monitors keyboard events globally while a window is active.
/// Created and owned by the app-level view, stored to keep the monitor alive.
final class GlobalKeyboardMonitor {
    private var localMonitor: Any?

    func start(onKeyDown: @escaping (NSEvent) -> Bool) {
        stop()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌘⇧K = Command Palette
            if event.modifierFlags.contains([.command, .shift]),
               event.keyCode == 40 { // 'k' key
                if onKeyDown(event) {
                    return nil // consume
                }
            }
            // ⌘⇧N = Quick Capture
            if event.modifierFlags.contains([.command, .shift]),
               event.keyCode == 45 { // 'n' key
                if onKeyDown(event) {
                    return nil // consume
                }
            }
            return event
        }
    }

    func stop() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit { stop() }
}

@main
struct WorkstationApp: App {
    @StateObject private var viewModel: WorkspaceViewModel
    @State private var appVM: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var keyboardMonitor = GlobalKeyboardMonitor()

    init() {
        AppFontRegistrar.registerBundledFonts()

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
                .font(WorkstationTheme.Fonts.body(13))
                .onAppear {
                    startKeyboardMonitor()
                }
                .onDisappear {
                    keyboardMonitor.stop()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        startKeyboardMonitor()
                    case .inactive, .background:
                        keyboardMonitor.stop()
                    @unknown default:
                        break
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            guard appVM.preferencesStore.preferences.autoReloadEnabled else { return }
            appVM.reloadIssues()
        }
    }

    private func startKeyboardMonitor() {
        keyboardMonitor.start { [weak appVM] event in
            guard let appVM else { return false }
            // ⌘⇧K = Command Palette
            if event.keyCode == 40 {
                Task { @MainActor in
                    appVM.presentCommandPalette()
                }
                return true
            }
            // ⌘⇧N = Quick Capture
            if event.keyCode == 45 {
                Task { @MainActor in
                    appVM.presentQuickCapture()
                }
                return true
            }
            return false
        }
    }
}
