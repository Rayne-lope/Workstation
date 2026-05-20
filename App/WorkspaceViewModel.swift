import AppKit
import Combine
import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var selectedFolderPath: String?
    @Published var rootPath: String?
    @Published var workspace: ProjectWorkspace?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var commandHistory: [CommandSnapshot] = []

    private let shellRunner: ShellCommandRunner
    private let validator: WorkspaceValidator
    private var validationTask: Task<Void, Never>?

    init(shellRunner: ShellCommandRunner = ShellCommandRunner()) {
        self.shellRunner = shellRunner
        self.validator = WorkspaceValidator(commandRunner: shellRunner)
    }

    func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"

        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else {
            return
        }

        loadWorkspace(from: selectedURL)
    }

    func reloadValidation() {
        guard let selectedFolderPath else {
            return
        }
        loadWorkspace(from: URL(fileURLWithPath: selectedFolderPath, isDirectory: true))
    }

    func cancelLoading() {
        validationTask?.cancel()
        validationTask = nil
        isLoading = false
    }

    func loadWorkspace(from selectedURL: URL) {
        validationTask?.cancel()
        selectedFolderPath = selectedURL.path
        errorMessage = nil
        isLoading = true
        commandHistory = []

        let validator = self.validator
        let shellRunner = self.shellRunner
        validationTask = Task.detached(priority: .userInitiated) { [selectedURL, validator, shellRunner] in
            do {
                let workspace = try await validator.validate(selection: selectedURL)
                let history = shellRunner.history
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.workspace = workspace
                    self.rootPath = workspace.rootPath
                    self.selectedFolderPath = workspace.selectedPath
                    self.errorMessage = nil
                    self.isLoading = false
                    self.commandHistory = history
                    self.validationTask = nil
                }
            } catch is CancellationError {
                let history = shellRunner.history
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.commandHistory = history
                    self.isLoading = false
                    self.validationTask = nil
                }
            } catch {
                let history = shellRunner.history
                let message = error.localizedDescription
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.workspace = nil
                    self.rootPath = nil
                    self.errorMessage = message
                    self.isLoading = false
                    self.commandHistory = history
                    self.validationTask = nil
                }
            }
        }
    }
}
