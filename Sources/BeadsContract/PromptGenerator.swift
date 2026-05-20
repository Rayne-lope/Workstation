import Foundation

public struct PromptGenerator: Sendable {
    public init() {}

    public func generateCommand(
        for profile: AgentProfile,
        issue: BeadIssue,
        projectPath: String?
    ) -> String {
        let prompt = generatePrompt(for: profile, issue: issue, projectPath: projectPath)
        let escaped = prompt.replacingOccurrences(of: "\"", with: "\\\"")
        let args = profile.commandArgsTemplate
            .replacingOccurrences(of: "{{prompt}}", with: escaped)
        if args.isEmpty {
            return profile.command
        }
        return "\(profile.command) \(args)"
    }

    public func generatePrompt(
        for profile: AgentProfile,
        issue: BeadIssue,
        projectPath: String?
    ) -> String {
        let path = projectPath ?? ""
        switch profile.role {
        case .specWriter:
            return Self.specWriterTemplate(issue: issue, projectPath: path)
        case .codingExecutor:
            return Self.executorTemplate(profile: profile, issue: issue, projectPath: path)
        case .reviewer:
            return Self.reviewerTemplate(issue: issue, projectPath: path)
        case .tester:
            return Self.testerTemplate(issue: issue, projectPath: path)
        case .custom:
            let template = profile.defaultPromptTemplate.isEmpty
                ? Self.customFallbackTemplate
                : profile.defaultPromptTemplate
            return Self.renderPlaceholders(
                template,
                profile: profile,
                issue: issue,
                projectPath: path
            )
        }
    }

    public func generateReviewFollowupPrompt(
        issue: BeadIssue,
        projectPath: String?,
        userNotes: String
    ) -> String {
        let path = projectPath ?? ""
        let trimmedNotes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let feedbackBlock = trimmedNotes.isEmpty ? "(no specific notes provided)" : trimmedNotes
        return """
        You are continuing work on a beads issue that is currently in Review.
        The reviewer flagged bugs / hardening needs — your job is to address them
        without losing the original spec.

        Project path: \(path)
        Issue: \(issue.id) — \(issue.title)

        Reviewer feedback:
        \(feedbackBlock)

        Workflow:
        1. Run `bd prime` to load project context.
        2. Run `bd show \(issue.id) --json` to re-read the original spec + prior notes.
        3. Apply the feedback above. Re-run relevant tests after each meaningful change.
        4. When done, `bd update \(issue.id) --add-label human --notes="follow-up: <summary>"`.
           Do NOT close — let the human re-review.

        Constraints:
        - Stay scoped to the feedback above; do not introduce unrelated refactors.
        - If feedback is ambiguous, leave a `bd update \(issue.id) --notes=...` question and stop.
        """
    }

    private static func renderPlaceholders(
        _ template: String,
        profile: AgentProfile,
        issue: BeadIssue,
        projectPath: String
    ) -> String {
        template
            .replacingOccurrences(of: "{{issue_id}}", with: issue.id)
            .replacingOccurrences(of: "{{issue_title}}", with: issue.title)
            .replacingOccurrences(of: "{{project_path}}", with: projectPath)
            .replacingOccurrences(of: "{{agent_name}}", with: profile.name)
            .replacingOccurrences(of: "{{agent_role}}", with: profile.role.displayName)
    }

    private static func specWriterTemplate(issue: BeadIssue, projectPath: String) -> String {
        """
        You are a Spec Writer for the beads issue tracker.

        Project path: \(projectPath)
        Issue: \(issue.id) — \(issue.title)

        Workflow:
        1. Run `bd prime` to load project context and conventions.
        2. Run `bd show \(issue.id) --json` to read the full issue payload.
        3. Draft a clear specification: goal, requirements, edge cases, acceptance criteria.
        4. Write the spec into the issue via `bd update \(issue.id) --description=...` (or --notes / --acceptance / --design as appropriate).

        Constraints:
        - Do not modify application source code.
        - Focus on producing an unambiguous spec the Coding Executor can act on.
        - Capture assumptions explicitly; flag unknowns with `bd human \(issue.id)` if a decision is required.
        """
    }

    private static func executorTemplate(profile: AgentProfile, issue: BeadIssue, projectPath: String) -> String {
        let finishStep: String
        if profile.shouldRequestHumanReview {
            finishStep = "When done, run relevant tests one more time, then `bd update \(issue.id) --add-label human` and leave a `--notes=...` summary. Do NOT close the issue — a human will review and close it."
        } else if profile.shouldCloseIssue {
            finishStep = "When done, run relevant tests one more time, then `bd close \(issue.id) --reason=\"...\"` summarizing what changed."
        } else {
            finishStep = "When done, run relevant tests one more time and report status via `bd update \(issue.id) --notes=...`. The user will decide what to do next."
        }

        return """
        You are a Coding Executor for the beads issue tracker.

        Project path: \(projectPath)
        Issue: \(issue.id) — \(issue.title)

        Workflow:
        1. Run `bd prime` to load project context.
        2. Read `GUIDE.md` for repo rules, Beads workflow, and completion conventions.
        3. If the work touches UI or visual polish, read `references/workstations_style_guide.md` before designing the change.
        4. Run `bd show \(issue.id) --json` to read the spec.
        5. Run `bd update \(issue.id) --claim` to claim the issue.
        6. Implement the change end-to-end. Run relevant tests after each meaningful step.
        7. \(finishStep)

        Constraints:
        - Follow project conventions; do not introduce unrelated refactors.
        - If a blocker appears, leave a note via `bd update \(issue.id) --notes=...` and stop instead of guessing.
        """
    }

    private static func reviewerTemplate(issue: BeadIssue, projectPath: String) -> String {
        """
        You are a Reviewer for the beads issue tracker.

        Project path: \(projectPath)
        Issue: \(issue.id) — \(issue.title)

        Workflow:
        1. Run `bd prime` to load project context.
        2. Run `bd show \(issue.id) --json` to read the spec and acceptance criteria.
        3. Inspect the change via `git diff` (and `git log` for context).
        4. Validate the diff against the acceptance criteria and project conventions.
        5. Record findings via `bd update \(issue.id) --notes=...` — list approvals and required changes.

        Constraints:
        - Do not modify source code; only review and report.
        - Cite specific files and lines when calling out issues.
        """
    }

    private static func testerTemplate(issue: BeadIssue, projectPath: String) -> String {
        """
        You are a Tester for the beads issue tracker.

        Project path: \(projectPath)
        Issue: \(issue.id) — \(issue.title)

        Workflow:
        1. Run `bd prime` to load project context.
        2. Run `bd show \(issue.id) --json` to read the spec.
        3. Add or extend tests only — do not modify production code.
        4. Cover the acceptance criteria plus relevant edge cases and regressions.
        5. Run the test suite and record results via `bd update \(issue.id) --notes=...`.

        Constraints:
        - Write tests only. Implementation changes are out of scope for this role.
        - Prefer deterministic tests; avoid flaky timing assumptions.
        """
    }

    private static let customFallbackTemplate = """
    You are {{agent_name}} ({{agent_role}}) working on the beads issue tracker.

    Project path: {{project_path}}
    Issue: {{issue_id}} — {{issue_title}}

    Workflow:
    1. Run `bd prime` to load project context.
    2. Run `bd show {{issue_id}} --json` to read the issue.
    3. Perform the work described by your role and record progress via `bd update {{issue_id}} --notes=...`.
    """
}
