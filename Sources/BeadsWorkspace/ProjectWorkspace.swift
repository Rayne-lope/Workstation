import Foundation

public struct ProjectWorkspace: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let selectedURL: URL
    public let rootURL: URL?
    public let inspectionURL: URL
    public let name: String
    public let validationState: WorkspaceValidationState
    public let checks: [WorkspaceCheck]
    public let suggestion: String?
    public let detail: String?

    public init(
        id: UUID = UUID(),
        selectedURL: URL,
        rootURL: URL?,
        inspectionURL: URL,
        name: String,
        validationState: WorkspaceValidationState,
        checks: [WorkspaceCheck],
        suggestion: String? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.selectedURL = selectedURL
        self.rootURL = rootURL
        self.inspectionURL = inspectionURL
        self.name = name
        self.validationState = validationState
        self.checks = checks
        self.suggestion = suggestion
        self.detail = detail
    }

    public var selectedPath: String {
        selectedURL.path
    }

    public var rootPath: String? {
        rootURL?.path
    }
}

public struct WorkspaceSetupHint: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let command: String
    public let detail: String

    public init(id: String, title: String, command: String, detail: String) {
        self.id = id
        self.title = title
        self.command = command
        self.detail = detail
    }
}

public extension ProjectWorkspace {
    var setupHints: [WorkspaceSetupHint] {
        var hints: [WorkspaceSetupHint] = []

        if check(id: ".beads")?.state == .missing || validationState == .notABeadsProject {
            hints.append(
                WorkspaceSetupHint(
                    id: "bd-init",
                    title: "Run `bd init`",
                    command: "bd init",
                    detail: "Creates the .beads workspace in the project root."
                )
            )
        }

        if check(id: "AGENTS.md")?.state == .missing {
            hints.append(
                WorkspaceSetupHint(
                    id: "bd-setup-claude",
                    title: "Run `bd setup claude`",
                    command: "bd setup claude",
                    detail: "Installs agent workflow guidance for Claude."
                )
            )
        }

        if check(id: "bd-cli")?.state == .missing {
            hints.append(
                WorkspaceSetupHint(
                    id: "bd-install",
                    title: "Install bd via brew",
                    command: "brew install beads",
                    detail: "Installs the bd CLI on this machine."
                )
            )
        }

        return hints
    }

    private func check(id: String) -> WorkspaceCheck? {
        checks.first { $0.id == id }
    }
}
