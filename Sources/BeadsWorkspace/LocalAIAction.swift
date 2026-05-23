import Foundation
#if canImport(BeadsContract)
import BeadsContract
#endif

public enum LocalAIModelTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case fast
    case strong

    public var id: String { rawValue }
}

public enum LocalAIAction: Equatable, Sendable {
    case issueDrafting(issue: BeadIssue)
    case backlogAnalysis(issues: [BeadIssue])
    case promptOptimization(prompt: String)
    case closeReason(issue: BeadIssue, summary: String)
    case runSummary(record: AgentRunRecord)
    case simplifyIssueIndonesian(issue: BeadIssue)
    case detailIssueFromRoughIdea(roughIdea: String)
    case draftIssuesFromPRD(prd: String)
    case copilot(prompt: String, contextIssues: [BeadIssue])
    case copilotPlan(prompt: String, contextIssues: [BeadIssue])
    case draftCommitMessage(worktreeURL: String, diffSummary: String, diff: String, lastCommit: String?)

    public var modelTier: LocalAIModelTier {
        switch self {
        case .issueDrafting, .backlogAnalysis, .runSummary, .simplifyIssueIndonesian, .detailIssueFromRoughIdea, .draftIssuesFromPRD, .copilot, .copilotPlan, .draftCommitMessage:
            return .strong
        case .promptOptimization, .closeReason:
            return .fast
        }
    }

    public var systemPrompt: String {
        switch self {
        case .draftCommitMessage:
            return """
            You are a professional commit message generator for the Beads Kanban app.
            Format the output according to Conventional Commits:
            type(scope): short description

            Do not wrap output in markdown fences or any formatting. Return plain text only.
            """
        default:
            return """
            You are a local AI assistant for the Beads Kanban app.
            Return plain text only.
            Do not execute commands, mutate Beads data, or write source code.
            """
        }
    }

    public var prompt: String {
        switch self {
        case let .issueDrafting(issue):
            return """
            Draft a concise issue refinement for Beads.

            Issue:
            \(Self.renderIssue(issue))

            Output requirements:
            - Preserve the original intent.
            - Tighten the goal, scope, and acceptance criteria.
            - Call out missing details or risks as suggestions only.
            - Return plain text that the user can review before applying.
            """
        case let .backlogAnalysis(issues):
            let renderedIssues = issues.isEmpty ? "(no issues provided)" : issues.map(Self.renderIssue).joined(separator: "\n\n")
            return """
            Analyze the provided Beads backlog issues and suggest organization improvements.

            Issues:
            \(renderedIssues)

            Output requirements:
            - Suggest duplicates, oversized issues, missing dependencies, priority adjustments, split candidates, and issues that should be refined.
            - Do not mutate issues or produce CLI commands.
            - Return suggestions only, grouped by issue when helpful.
            """
        case let .promptOptimization(prompt):
            return """
            Improve the following prompt while keeping its intent and constraints intact.

            Prompt:
            \(prompt)

            Output requirements:
            - Preserve meaning.
            - Reduce ambiguity and unnecessary repetition.
            - Keep the result ready for a user preview.
            """
        case let .closeReason(issue, summary):
            let trimmedSummary = summary.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return """
            Draft a concise close reason for this Beads issue.

            Issue:
            \(Self.renderIssue(issue))

            Work summary:
            \(trimmedSummary.isEmpty ? "(no summary provided)" : trimmedSummary)

            Output requirements:
            - State what was completed and why the issue can be closed.
            - Keep the result short and factual.
            - Do not mention implementation details that are not in the summary.
            """
        case let .simplifyIssueIndonesian(issue):
            return """
            Jelaskan ulang isu Beads berikut dalam Bahasa Indonesia yang sederhana dan ramah.

            Issue:
            \(Self.renderIssue(issue))

            Output requirements:
            - Tulis dalam Bahasa Indonesia, hindari jargon teknis Beads jika bisa.
            - Mulai dengan ringkasan judul satu kalimat agar mudah dipahami.
            - Jelaskan deskripsi inti dengan kalimat pendek dan mudah dimengerti.
            - Jika ada acceptance criteria, ubah jadi daftar singkat dengan kata kerja konkret.
            - Jika ada blocker atau dependency, sebutkan secara singkat dan jelaskan dampaknya.
            - Jangan menambahkan informasi baru yang tidak ada di issue asli.
            - Output hanya teks biasa, siap dibaca pengguna sebagai pratinjau read-only.
            """
        case let .detailIssueFromRoughIdea(roughIdea):
            return """
            Turn this rough idea into a structured Beads issue draft.

            Rough idea:
            \(roughIdea)

            Output requirements:
            - Return a single JSON object only.
            - Use these keys: title, description, implementation_notes, acceptance_criteria, issue_type, priority, labels, split_suggestions, dependency_suggestions.
            - `acceptance_criteria`, `labels`, `split_suggestions`, and `dependency_suggestions` should be arrays of strings.
            - `priority` should be an integer from 0 to 4 when possible.
            - Keep split and dependency suggestions advisory only.
            - Do not wrap the JSON in markdown fences or add commentary outside the object.
            """
        case let .draftIssuesFromPRD(prd):
            return """
            Turn this PRD or long feature plan into reviewable Beads issue drafts.

            PRD:
            \(prd)

            Output requirements:
            - Return a JSON array only.
            - Create a practical set of epics, phase issues, and sub-phase tasks when the PRD supports them.
            - Use these keys on every draft: title, description, implementation_notes, acceptance_criteria, issue_type, priority, labels, dependency_suggestions, reason.
            - `acceptance_criteria`, `labels`, and `dependency_suggestions` must be arrays of strings.
            - `priority` should be an integer from 0 to 4 when possible.
            - `dependency_suggestions` are advisory only; do not imply dependencies were applied.
            - `reason` should briefly explain why this draft belongs in the generated plan.
            - Keep each draft scoped enough for a coding agent to implement.
            - Do not wrap the JSON in markdown fences or add commentary outside the array.
            """
        case let .copilot(prompt, contextIssues):
            let renderedIssues = contextIssues.isEmpty ? "(no issues provided)" : contextIssues.map(Self.renderIssue).joined(separator: "\n\n")
            return """
            Answer this Workflow Copilot request for the Beads Kanban app.

            User request:
            \(prompt)

            Context issues:
            \(renderedIssues)

            Output requirements:
            - Return a helpful plain-text answer.
            - Use the provided issue context when relevant.
            - Do not mutate Beads data, execute commands, or claim that a change was applied.
            - If the request requires a mutation, describe the proposed next step for human approval.
            """
        case let .copilotPlan(prompt, contextIssues):
            let renderedIssues = contextIssues.isEmpty ? "(no issues provided)" : contextIssues.map(Self.renderIssue).joined(separator: "\n\n")
            return """
            You are the Workflow Plan Generator for the Beads Kanban app.
            Your job is to parse the user request and generate a structured JSON plan to update the board or issues.

            Context issues available in the app:
            \(renderedIssues)

            User request:
            \(prompt)

            Output Requirements:
            - Output ONLY a valid JSON object matching the WorkflowPlan schema. No explanation, no conversational intro/outro.
            - Do NOT wrap JSON in markdown fences (like ```json ... ```). Output the raw JSON text directly.
            - If you cannot perform any mutation matching the user request, return an empty actions array.
            - NEVER fabricate issue IDs. Only reference the issue IDs from the context issues above. If the user refers to "this issue", "issue yang di select", or similar, map it to the active/selected issue in the context.

            JSON Schema:
            {
              "summary": "String explaining what changes will be made",
              "actions": [
                {
                  "id": "A unique string id, e.g., action-1, action-2",
                  "kind": "String: one of 'close_with_reason', 'update_field', 'create_issue', 'skip'",
                  "issue_id": "String: The ID of the issue (e.g., Workstation-ca6)",
                  "reason": "String: The reason for this action (for display to the user)",
                  "field": "Optional String: 'priority', 'status', 'assignee', 'title', 'description' (only for update_field kind)",
                  "value": "Optional String: The new value (e.g., '1' for priority, 'In Progress' for status, 'claude' for assignee) (only for update_field kind)",
                  "draft_reason": "Optional String: close reason (only for close_with_reason kind)",
                  "title": "Optional String: title of new issue (only for create_issue)",
                  "description": "Optional String: description of new issue (only for create_issue)",
                  "issue_type": "Optional String: 'feature', 'bug', 'chore', etc. (only for create_issue)",
                  "priority": "Optional Integer: 0 to 4 (only for create_issue)"
                }
              ],
              "warnings": ["Optional String array of warnings"]
            }
            """
        case let .runSummary(record):
            return """
            Summarize the following agent run for a Beads history note.

            Run metadata:
            - Issue: \(record.issueID) — \(record.issueTitle)
            - Agent: \(record.agentName)
            - Status: \(record.status.displayName)
            - Command: \(record.command)
            - Project path: \(record.projectPath)
            - Started at: \(Self.formatDate(record.startedAt))
            - Completed at: \(record.completedAt.map { Self.formatDate($0) } ?? "(not completed)")
            - Notes: \(Self.optionalText(record.notes) ?? "(none)")

            Original prompt:
            \(record.prompt)

            Output requirements:
            - Write a short run summary for a human reviewer.
            - Focus on what changed, what failed, and what still needs attention.
            - Do not invent facts that are not present above.
            """
        case let .draftCommitMessage(worktreeURL, diffSummary, diff, lastCommit):
            var lines = [
                "Generate a commit message for this worktree.",
                "Worktree: \(worktreeURL)",
                "Changed files summary:",
                diffSummary,
                "Diff content:",
                diff
            ]
            if let lastCommit = lastCommit, !lastCommit.isEmpty {
                lines.append("Last commit message: \(lastCommit)")
            }
            lines.append("Use Conventional Commits format.")
            return lines.joined(separator: "\n")
        }
    }

    private static func renderIssue(_ issue: BeadIssue) -> String {
        var lines: [String] = [
            "- ID: \(issue.id)",
            "- Title: \(issue.title)"
        ]
        if let status = issue.status, !status.isEmpty {
            let displayStatus = (status == "in_progress" && issue.labels?.contains("human") == true) ? "review" : status
            lines.append("- Status: \(displayStatus)")
        }
        if let priority = issue.priority {
            lines.append("- Priority: \(priority)")
        }
        if let issueType = issue.issueType, !issueType.isEmpty {
            lines.append("- Type: \(issueType)")
        }
        if let description = issue.description?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !description.isEmpty {
            lines.append("- Description: \(description)")
        }
        if let acceptanceCriteria = issue.acceptanceCriteria?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !acceptanceCriteria.isEmpty {
            lines.append("- Acceptance criteria: \(acceptanceCriteria)")
        }
        if let notes = issue.notes?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !notes.isEmpty {
            lines.append("- Notes: \(notes)")
        }
        if let labels = issue.labels, !labels.isEmpty {
            lines.append("- Labels: \(labels.joined(separator: ", "))")
        }
        if let assignee = issue.assignee, !assignee.isEmpty {
            lines.append("- Assignee: \(assignee)")
        }
        if let blockedBy = issue.blockedBy, !blockedBy.isEmpty {
            lines.append("- Blocked by: \(blockedBy.joined(separator: ", "))")
        }
        if let dependencies = issue.dependencies, !dependencies.isEmpty {
            lines.append("- Dependencies: \(dependencies.map(\.id).joined(separator: ", "))")
        }
        if let dependents = issue.dependents, !dependents.isEmpty {
            lines.append("- Dependents: \(dependents.map(\.id).joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    private static func optionalText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

public struct WorkflowPlan: Codable, Equatable, Sendable {
    public let summary: String
    public var actions: [WorkflowAction]
    public let warnings: [String]?

    public init(summary: String, actions: [WorkflowAction], warnings: [String]? = nil) {
        self.summary = summary
        self.actions = actions
        self.warnings = warnings
    }
}

public struct WorkflowAction: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: String // "close_with_reason", "update_field", "create_issue", "skip"
    public let issueId: String?
    public let reason: String?
    
    // For update_field
    public let field: String?
    public let value: String?
    
    // For close_with_reason
    public let draftReason: String?
    
    // For create_issue
    public let title: String?
    public let description: String?
    public let issueType: String?
    public let priority: Int?
    
    // UI Selection
    public var isSelected: Bool? = true

    public enum CodingKeys: String, CodingKey {
        case id
        case kind
        case issueId = "issue_id"
        case reason
        case field
        case value
        case draftReason = "draft_reason"
        case title
        case description
        case issueType = "issue_type"
        case priority
    }
    
    public init(id: String, kind: String, issueId: String? = nil, reason: String? = nil, field: String? = nil, value: String? = nil, draftReason: String? = nil, title: String? = nil, description: String? = nil, issueType: String? = nil, priority: Int? = nil, isSelected: Bool? = true) {
        self.id = id
        self.kind = kind
        self.issueId = issueId
        self.reason = reason
        self.field = field
        self.value = value
        self.draftReason = draftReason
        self.title = title
        self.description = description
        self.issueType = issueType
        self.priority = priority
        self.isSelected = isSelected
    }
}
