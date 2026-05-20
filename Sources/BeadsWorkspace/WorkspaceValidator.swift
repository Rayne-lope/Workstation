import Foundation

public struct WorkspaceValidator: Sendable {
    private let rootResolver: ProjectRootResolver
    private let beadsService: BeadsService

    public init(
        rootResolver: ProjectRootResolver = ProjectRootResolver(),
        commandRunner: any CommandRunning = ShellCommandRunner()
    ) {
        self.init(rootResolver: rootResolver, beadsService: BeadsService(commandRunner: commandRunner))
    }

    public init(
        rootResolver: ProjectRootResolver = ProjectRootResolver(),
        beadsService: BeadsService
    ) {
        self.rootResolver = rootResolver
        self.beadsService = beadsService
    }

    public func validate(selection selectedURL: URL) async throws -> ProjectWorkspace {
        guard FileManager.default.fileExists(atPath: selectedURL.path) else {
            throw BeadsError.invalidProjectFolder
        }

        let discovery = rootResolver.resolve(from: selectedURL)
        let inspectionURL = discovery.rootURL ?? selectedURL

        let gitCheck = checkFile(named: ".git", in: inspectionURL)
        let beadsCheck = checkFile(named: ".beads", in: inspectionURL)
        let agentsCheck = checkFile(named: "AGENTS.md", in: inspectionURL)

        let bdAvailability = await checkBdAvailability(in: inspectionURL)
        let bdListCheck: WorkspaceCheck
        if shouldRunBdListProbe(gitCheck: gitCheck, beadsCheck: beadsCheck, bdAvailability: bdAvailability) {
            bdListCheck = await checkBdList(in: inspectionURL)
        } else {
            bdListCheck = WorkspaceCheck(
                id: "bd-list",
                title: "bd list",
                state: .missing,
                detail: "Skipped until Git, Beads, and bd CLI are available."
            )
        }

        let overallState = overallState(
            discovery: discovery,
            gitCheck: gitCheck,
            beadsCheck: beadsCheck,
            bdAvailability: bdAvailability,
            bdListCheck: bdListCheck
        )

        let suggestion: String? = {
            if !beadsCheck.isOk {
                return "Run `bd init` in this folder to create a Beads workspace."
            }
            if !bdAvailability.isOk {
                return "Install `bd` via Homebrew and make sure it is on your PATH."
            }
            if bdListCheck.state == .failed {
                return "Check `bd list --json` manually from the project root."
            }
            return nil
        }()

        let detail: String? = {
            switch overallState {
            case .valid:
                return "Workspace is ready."
            case .missing:
                return "One or more required checks are missing."
            case .failed:
                return "Workspace probe failed."
            case .notABeadsProject:
                return "No .git or .beads marker was found in this folder or any parent."
            }
        }()

        return ProjectWorkspace(
            selectedURL: selectedURL,
            rootURL: discovery.rootURL,
            inspectionURL: inspectionURL,
            name: inspectionURL.lastPathComponent.isEmpty ? inspectionURL.path : inspectionURL.lastPathComponent,
            validationState: overallState,
            checks: [gitCheck, beadsCheck, agentsCheck, bdAvailability, bdListCheck],
            suggestion: suggestion,
            detail: detail
        )
    }

    private func checkFile(named name: String, in url: URL) -> WorkspaceCheck {
        let exists = FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path)
        return WorkspaceCheck(
            id: name,
            title: name,
            state: exists ? .ok : .missing,
            detail: exists ? nil : "\(name) is missing at \(url.path)."
        )
    }

    private func checkBdAvailability(in url: URL) async -> WorkspaceCheck {
        do {
            let result = try await beadsService.version(in: url)
            if result.exitCode == 0 {
                return WorkspaceCheck(id: "bd-cli", title: "bd CLI", state: .ok, detail: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            let missing = result.exitCode == 127 || result.stderr.localizedCaseInsensitiveContains("not found")
            return WorkspaceCheck(
                id: "bd-cli",
                title: "bd CLI",
                state: missing ? .missing : .failed,
                detail: result.stderr.isEmpty ? "bd --version exited with \(result.exitCode)." : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            return WorkspaceCheck(id: "bd-cli", title: "bd CLI", state: .failed, detail: error.localizedDescription)
        }
    }

    private func shouldRunBdListProbe(gitCheck: WorkspaceCheck, beadsCheck: WorkspaceCheck, bdAvailability: WorkspaceCheck) -> Bool {
        gitCheck.state == .ok && beadsCheck.state == .ok && bdAvailability.state == .ok
    }

    private func checkBdList(in url: URL) async -> WorkspaceCheck {
        do {
            let result = try await beadsService.list(in: url)
            if result.exitCode == 0 {
                return WorkspaceCheck(id: "bd-list", title: "bd list", state: .ok, detail: "JSON probe succeeded.")
            }

            return WorkspaceCheck(
                id: "bd-list",
                title: "bd list",
                state: .failed,
                detail: result.stderr.isEmpty ? "bd list --json exited with \(result.exitCode)." : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            return WorkspaceCheck(id: "bd-list", title: "bd list", state: .failed, detail: error.localizedDescription)
        }
    }

    private func overallState(
        discovery: ProjectRootDiscovery,
        gitCheck: WorkspaceCheck,
        beadsCheck: WorkspaceCheck,
        bdAvailability: WorkspaceCheck,
        bdListCheck: WorkspaceCheck
    ) -> WorkspaceValidationState {
        guard discovery.rootURL != nil else {
            return .notABeadsProject
        }

        if bdListCheck.state == .failed {
            return .failed
        }

        if gitCheck.state == .missing || beadsCheck.state == .missing || bdAvailability.state == .missing {
            return .missing
        }

        if gitCheck.state == .failed || beadsCheck.state == .failed || bdAvailability.state == .failed {
            return .failed
        }

        return .valid
    }
}

private extension WorkspaceCheck {
    var isOk: Bool { state == .ok }
}
