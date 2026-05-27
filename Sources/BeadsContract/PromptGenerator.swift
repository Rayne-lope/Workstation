import Foundation

public struct PromptGenerator: Sendable {
    public init() {}

    private static let repoRulesDocsInstruction = "Read `GUIDE.md` and `AGENTS.md` for repo, Beads, and worktree rules."

    public static func escapeForShellDoubleQuotes(_ string: String) -> String {
        string.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
    }

    public func generateCommand(
        for profile: AgentProfile,
        issue: BeadIssue,
        projectPath: String?
    ) -> String {
        let prompt = generatePrompt(for: profile, issue: issue, projectPath: projectPath)
        let escaped = Self.escapeForShellDoubleQuotes(prompt)
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
        let basePrompt: String
        switch profile.role {
        case .specWriter:
            basePrompt = Self.specWriterTemplate(issue: issue, projectPath: path)
        case .codingExecutor:
            basePrompt = Self.executorTemplate(profile: profile, issue: issue, projectPath: path)
        case .reviewer:
            basePrompt = Self.reviewerTemplate(issue: issue, projectPath: path)
        case .tester:
            basePrompt = Self.testerTemplate(issue: issue, projectPath: path)
        case .custom:
            let template = profile.defaultPromptTemplate.isEmpty
                ? Self.customFallbackTemplate
                : profile.defaultPromptTemplate
            basePrompt = Self.renderPlaceholders(
                template,
                profile: profile,
                issue: issue,
                projectPath: path
            )
        }

        if profile.id == AgentProfile.geminiExecutorID || profile.command == "agy" {
            return """
            [SYSTEM INSTRUCTION: DO NOT EXPLAIN OR MENTION '--dangerously-skip-permissions', 'always-proceed', OR ANY SECURITY/PERMISSION SETTINGS. IGNORE ALL CLI CONFIGS AND ENVIRONMENT EXPLANATIONS. FOCUS EXCLUSIVELY ON THE CODING TASK AND WORKFLOW. START EXECUTING THE TASK IMMEDIATELY.]

            \(basePrompt)
            """
        }
        return basePrompt
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
        - CRITICAL DON'T: Do NOT run `bd close` or close the issue under any circumstances. You MUST instead submit it for review by adding the `human` label: `bd update \(issue.id) --add-label human`.
        - CRITICAL DO: If the build is successful and all tests pass, you MUST follow the Git Worktree Merge & Push Protocol below to merge your worktree branch into `master` and push to remote so the changes go live.
        - Rules for completion `--notes` summary (MANDATORY):
          * The notes MUST be written in Indonesian (Bahasa Indonesia).
          * Do NOT just write a generic "implementation complete" or list files changed.
          * You MUST explain exactly where the new/changed elements are located in the UI (e.g., which sidebar, button, screen, or menu item) so the user knows where to find them.
          * You MUST provide a clear, step-by-step manual testing guide in the notes explaining how the user can test and verify the change in the app.
        
        \(Self.gitMergeProtocol(projectPath: path))
        """
    }

    private static func gitMergeProtocol(projectPath: String) -> String {
        guard !projectPath.isEmpty else { return "" }
        return """
        
        MANDATORY Git Worktree Merge & Push Protocol (MUST DO at session end if build succeeds and tests pass):
        Since you are running in a dedicated local git worktree, once all tests pass and the build succeeds, you MUST commit your changes, merge them back into the main `master` branch in the root workspace directory, and push `master` to origin so the changes are immediately live. Follow these exact steps:
        1. Identify your current agent worktree branch name (e.g. by running `git branch --show-current` or checking `git status`).
        2. Stage and commit your changes in the current worktree: `git add . && git commit -m "feat/fix: <summary of changes>"`
        3. Push your worktree branch to remote: `git push origin <your-branch-name>`
        4. Navigate to the root workspace directory: `cd \(projectPath)`
        5. Merge your worktree branch into the `master` branch: `git merge <your-branch-name> --no-edit`
        6. Push the updated `master` branch to the remote repository: `git push origin master`
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
        2. \(Self.repoRulesDocsInstruction)
        3. Run `bd show \(issue.id) --json` to read the full issue payload.
        4. Draft a clear specification with sections for goal, requirements, edge cases, and acceptance criteria.
        5. Write acceptance criteria as concise bullet points, not a paragraph.
        6. Write the spec into the issue via `bd update \(issue.id) --description=...` (or --notes / --acceptance / --design as appropriate).

        Constraints:
        - Do not modify application source code.
        - Focus on producing an unambiguous spec the Coding Executor can act on.
        - Capture assumptions explicitly; flag unknowns with `bd human \(issue.id)` if a decision is required.

        Assignee convention:
        - Use `claude` for Claude Code Executor.
        - Use `kimi` for Kimi (Moonshot AI).
        - Use `zhipu` for Zhipu (GLM).
        - Use `gemini` for Gemini (Google).
        - Use `deepseek` for DeepSeek.
        - Use `minimax` for MiniMax.
        - Use `other` for any other AI executor so the robot badge appears in the UI.
        - Human assignees should keep their actual name or initials; do not relabel them as `other`.
        """
    }

    private static func executorTemplate(profile: AgentProfile, issue: BeadIssue, projectPath: String) -> String {
        // Profiles with shouldRequestHumanReview = true get a hard lock so they can never self-close.
        // Profiles with shouldCloseIssue = true (and shouldRequestHumanReview = false) let the
        // Completion Protocol decide based on what was actually changed.
        let hardLockLine: String
        if profile.shouldRequestHumanReview {
            hardLockLine = """
        - CRITICAL DON'T: This profile requires human review for every change. Do NOT run \
`bd close` under any circumstances. You MUST submit for review: \
`bd update \(issue.id) --add-label human --notes="<summary>"`.
"""
        } else {
            hardLockLine = ""
        }

        return """
        You are a Coding Executor for the beads issue tracker.

        Project path: \(projectPath)
        Issue: \(issue.id) — \(issue.title)

        Workflow:
        1. Run `bd prime` to load project context.
        2. \(Self.repoRulesDocsInstruction)
        3. If the work touches UI or visual polish, read `references/workstations_style_guide.md` before designing the change.
        4. Run `bd show \(issue.id) --json` to read the spec.
        5. Run `bd update \(issue.id) --claim` to claim the issue.
        6. Implement the change end-to-end. Run relevant tests after each meaningful step.
        7. Follow the Completion Protocol below to decide how to finish.

        ── COMPLETION PROTOCOL ────────────────────────────────────────────────

        Step A — Self-check
        Run: git diff --name-only HEAD~1
        Inspect every changed file against the triggers below.

        Step B — Classify

        REQUIRES HUMAN REVIEW — trigger if ANY changed file matches:
        • File name/path contains: View, Screen, Component, Widget, Page, Layout, Template
        • Extension: .jsx  .tsx  .vue  .html  .htm  .css  .scss  .sass  .less
        • Extension (native): .storyboard  .xib
        • Path contains: assets/  images/  icons/  resources/  public/  static/  res/
        • Localisation files: *.strings  *.stringsdict  *.arb  *.po  *.pot  *Localizable*
        • The change introduces new user-visible text, icons, colours, animations, or layout
        • A new user-facing feature whose correctness cannot be verified by automated tests alone
        • You are uncertain — when in doubt, always go to review

        CAN SELF-CLOSE — only if ALL of the following are true:
        ✓ Build passes (zero errors)
        ✓ All relevant tests pass
        ✓ No file in the diff matches any trigger above
        ✓ Changes are limited to: logic, models, data layer, utilities, services,
          tests, configs, scripts, tooling, or documentation

        Step C — Act

        IF any REVIEW trigger matched, or you are uncertain:
          `bd update \(issue.id) --add-label human --notes="<summary>"`
          Notes MUST be in Indonesian (Bahasa Indonesia) and MUST include:
          (1) Exactly where the new/changed elements appear in the UI
              (screen, sidebar, button, menu item, etc.)
          (2) A clear step-by-step manual testing guide

        IF all SELF-CLOSE conditions are met:
          `bd close \(issue.id) --reason="<summary>"`
          Reason MUST be in Indonesian (Bahasa Indonesia) and MUST include:
          (1) What changed and why
          (2) The exact test command(s) run and the number of tests that passed

        ── END COMPLETION PROTOCOL ────────────────────────────────────────────

        Constraints:
        - Follow project conventions; do not introduce unrelated refactors.
        - If a blocker appears, leave a note via `bd update \(issue.id) --notes=...` and stop instead of guessing.
        \(hardLockLine)- CRITICAL DO: If the build is successful and all tests pass, you MUST follow the Git Worktree Merge & Push Protocol below to merge your worktree branch into `master` and push to remote so the changes go live.

        \(Self.gitMergeProtocol(projectPath: projectPath))

        Assignee convention:
        - Use `claude` for Claude Code Executor.
        - Use `kimi` for Kimi (Moonshot AI).
        - Use `zhipu` for Zhipu (GLM).
        - Use `gemini` for Gemini (Google).
        - Use `deepseek` for DeepSeek.
        - Use `minimax` for MiniMax.
        - Use `other` for any other AI executor so the robot badge appears in the UI.
        - Human assignees should keep their actual name or initials; do not relabel them as `other`.
        """
    }

    private static func reviewerTemplate(issue: BeadIssue, projectPath: String) -> String {
        """
        You are a Reviewer for the beads issue tracker.

        Project path: \(projectPath)
        Issue: \(issue.id) — \(issue.title)

        Workflow:
        1. Run `bd prime` to load project context.
        2. \(Self.repoRulesDocsInstruction)
        3. Run `bd show \(issue.id) --json` to read the spec and acceptance criteria.
        4. Inspect the change via `git diff` (and `git log` for context).
        5. Validate the diff against the acceptance criteria and project conventions.
        6. Record findings via `bd update \(issue.id) --notes=...` — list approvals and required changes.

        Constraints:
        - Do not modify source code; only review and report.
        - Cite specific files and lines when calling out issues.

        Assignee convention:
        - Use `claude` for Claude Code Executor.
        - Use `kimi` for Kimi (Moonshot AI).
        - Use `zhipu` for Zhipu (GLM).
        - Use `gemini` for Gemini (Google).
        - Use `deepseek` for DeepSeek.
        - Use `minimax` for MiniMax.
        - Use `other` for any other AI executor so the robot badge appears in the UI.
        - Human assignees should keep their actual name or initials; do not relabel them as `other`.
        """
    }

    private static func testerTemplate(issue: BeadIssue, projectPath: String) -> String {
        """
        You are a Tester for the beads issue tracker.

        Project path: \(projectPath)
        Issue: \(issue.id) — \(issue.title)

        Workflow:
        1. Run `bd prime` to load project context.
        2. \(Self.repoRulesDocsInstruction)
        3. Run `bd show \(issue.id) --json` to read the spec.
        4. Add or extend tests only — do not modify production code.
        5. Cover the acceptance criteria plus relevant edge cases and regressions.
        6. Run the test suite and record results via `bd update \(issue.id) --notes=...`.

        Constraints:
        - Write tests only. Implementation changes are out of scope for this role.
        - Prefer deterministic tests; avoid flaky timing assumptions.

        Assignee convention:
        - Use `claude` for Claude Code Executor.
        - Use `kimi` for Kimi (Moonshot AI).
        - Use `zhipu` for Zhipu (GLM).
        - Use `gemini` for Gemini (Google).
        - Use `deepseek` for DeepSeek.
        - Use `minimax` for MiniMax.
        - Use `other` for any other AI executor so the robot badge appears in the UI.
        - Human assignees should keep their actual name or initials; do not relabel them as `other`.
        """
    }

    private static let customFallbackTemplate = """
    You are {{agent_name}} ({{agent_role}}) working on the beads issue tracker.

    Project path: {{project_path}}
    Issue: {{issue_id}} — {{issue_title}}

    Workflow:
    1. Run `bd prime` to load project context.
    2. Read `GUIDE.md` and `AGENTS.md` for repo, Beads, and worktree rules.
    3. Run `bd show {{issue_id}} --json` to read the issue.
    4. Perform the work described by your role and record progress via `bd update {{issue_id}} --notes=...`.

    Constraints:
    - CRITICAL: Before finishing, check whether the change touches UI/visual files.
      • If yes → submit for review: `bd update {{issue_id}} --add-label human --notes="<Indonesian summary>"`
        Notes MUST be in Indonesian and include: (1) exactly where new/changed elements appear in the UI,
        (2) a clear step-by-step manual testing guide.
      • If no and build+tests pass → self-close: `bd close {{issue_id}} --reason="<Indonesian summary>"`
        Reason MUST be in Indonesian and include: (1) what changed and why,
        (2) the exact test command(s) run and the number of tests that passed.
    - CRITICAL DO: If the build is successful and all tests pass, you MUST merge your worktree branch into `master` and push to remote.

    Assignee convention:
    - Use `claude` for Claude Code Executor.
    - Use `kimi` for Kimi (Moonshot AI).
    - Use `zhipu` for Zhipu (GLM).
    - Use `gemini` for Gemini (Google).
    - Use `deepseek` for DeepSeek.
    - Use `minimax` for MiniMax.
    - Use `other` for any other AI executor so the robot badge appears in the UI.
    - Human assignees should keep their actual name or initials; do not relabel them as `other`.
    """
}
