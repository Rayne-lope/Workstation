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
    case copilot(prompt: String, contextIssues: [BeadIssue])

    public var modelTier: LocalAIModelTier {
        switch self {
        case .issueDrafting, .backlogAnalysis, .runSummary, .simplifyIssueIndonesian, .detailIssueFromRoughIdea, .copilot:
            return .strong
        case .promptOptimization, .closeReason:
            return .fast
        }
    }

    public var systemPrompt: String {
        """
        You are a local AI assistant for the Beads Kanban app.
        Return plain text only.
        Do not execute commands, mutate Beads data, or write source code.
        """
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
        }
    }

    private static func renderIssue(_ issue: BeadIssue) -> String {
        var lines: [String] = [
            "- ID: \(issue.id)",
            "- Title: \(issue.title)"
        ]
        if let status = issue.status, !status.isEmpty {
            lines.append("- Status: \(status)")
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
