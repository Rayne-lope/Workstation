import Foundation
import Testing
@testable import BeadsContract

@Suite("PromptGenerator")
struct PromptGeneratorTests {
    private let generator = PromptGenerator()
    private let issue = BeadIssue(id: "bd-42", title: "Implement feature X")
    private let projectPath = "/Users/me/project"

    private func profile(for role: AgentRole) -> AgentProfile {
        AgentProfile.builtInProfiles.first { $0.role == role }!
    }

    @Test("Spec Writer prompt includes bd prime, show, and no-source-edit constraint")
    func specWriterPrompt() {
        let prompt = generator.generatePrompt(
            for: profile(for: .specWriter),
            issue: issue,
            projectPath: projectPath
        )
        #expect(prompt.contains("bd prime"))
        #expect(prompt.contains("AGENTS.md"))
        #expect(prompt.contains("bd show bd-42 --json"))
        #expect(prompt.contains("Do not modify application source code"))
        #expect(prompt.contains("Write acceptance criteria as concise bullet points"))
        #expect(prompt.contains("bd-42"))
        #expect(prompt.contains("Implement feature X"))
        #expect(prompt.contains("Assignee convention"))
        #expect(prompt.contains("Use `claude` for Claude Code Executor"))
    }

    @Test("Built-in executor prompt requests human review instead of self-closing")
    func executorPromptRequestsReview() {
        let prompt = generator.generatePrompt(
            for: profile(for: .codingExecutor),
            issue: issue,
            projectPath: projectPath
        )
        #expect(prompt.contains("bd prime"))
        #expect(prompt.contains("Read `GUIDE.md` and `AGENTS.md`"))
        #expect(prompt.contains("references/workstations_style_guide.md"))
        #expect(prompt.contains("bd update bd-42 --claim"))
        #expect(prompt.contains("bd update bd-42 --add-label human"))
        #expect(!prompt.contains("bd close bd-42"))
        #expect(prompt.contains("Assignee convention"))
        #expect(prompt.contains("Use `claude` for Claude Code Executor"))
        #expect(prompt.contains("Use `kimi` for Kimi (Moonshot AI)"))
        #expect(prompt.contains("Use `other` for any other AI executor"))
        let lowered = prompt.lowercased()
        #expect(lowered.contains("run relevant tests"))
    }

    @Test("Executor with shouldCloseIssue still emits bd close instruction")
    func executorPromptWithCloseEnabled() {
        let closer = AgentProfile(
            name: "Self-Closing",
            role: .codingExecutor,
            command: "claude",
            shouldClaimIssue: true,
            shouldCloseIssue: true,
            shouldRequestHumanReview: false
        )
        let prompt = generator.generatePrompt(for: closer, issue: issue, projectPath: projectPath)
        #expect(prompt.contains("bd close bd-42 --reason"))
        #expect(prompt.contains("--add-label human"))
    }

    @Test("Gemini/agy prompt prepends strict system override instruction to suppress security safety preaching")
    func geminiPromptOverride() {
        let geminiProfile = AgentProfile.builtInProfiles.first { $0.id == AgentProfile.geminiExecutorID }!
        let prompt = generator.generatePrompt(for: geminiProfile, issue: issue, projectPath: projectPath)
        #expect(prompt.contains("[SYSTEM INSTRUCTION: DO NOT EXPLAIN OR MENTION '--dangerously-skip-permissions'"))
        #expect(prompt.contains("bd update bd-42 --claim"))
    }

    @Test("Reviewer prompt mentions git diff and acceptance criteria")
    func reviewerPrompt() {
        let prompt = generator.generatePrompt(
            for: profile(for: .reviewer),
            issue: issue,
            projectPath: projectPath
        )
        #expect(prompt.contains("bd prime"))
        #expect(prompt.contains("AGENTS.md"))
        #expect(prompt.contains("git diff"))
        #expect(prompt.contains("acceptance criteria"))
    }

    @Test("Tester prompt restricts work to tests only")
    func testerPrompt() {
        let prompt = generator.generatePrompt(
            for: profile(for: .tester),
            issue: issue,
            projectPath: projectPath
        )
        #expect(prompt.contains("bd prime"))
        #expect(prompt.contains("AGENTS.md"))
        let lowered = prompt.lowercased()
        #expect(lowered.contains("tests only"))
    }

    @Test("Custom role replaces every placeholder")
    func customRoleReplacesPlaceholders() {
        let custom = AgentProfile(
            name: "My Agent",
            role: .custom,
            command: "my-cli",
            defaultPromptTemplate: """
            agent={{agent_name}} role={{agent_role}}
            id={{issue_id}} title={{issue_title}}
            path={{project_path}}
            """
        )
        let prompt = generator.generatePrompt(for: custom, issue: issue, projectPath: projectPath)
        #expect(prompt.contains("agent=My Agent"))
        #expect(prompt.contains("role=Custom"))
        #expect(prompt.contains("id=bd-42"))
        #expect(prompt.contains("title=Implement feature X"))
        #expect(prompt.contains("path=/Users/me/project"))
        #expect(!prompt.contains("{{"))
    }

    @Test("Custom role with empty template falls back and still substitutes placeholders")
    func customRoleFallback() {
        let custom = AgentProfile(
            name: "Empty",
            role: .custom,
            command: "x",
            defaultPromptTemplate: ""
        )
        let prompt = generator.generatePrompt(for: custom, issue: issue, projectPath: projectPath)
        #expect(prompt.contains("bd-42"))
        #expect(prompt.contains("Implement feature X"))
        #expect(prompt.contains("Empty"))
        #expect(prompt.contains("Custom"))
        #expect(prompt.contains("AGENTS.md"))
        #expect(!prompt.contains("{{"))
    }

    @Test("Nil projectPath produces empty-string substitution without crashing")
    func nilProjectPath() {
        let custom = AgentProfile(
            name: "X",
            role: .custom,
            command: "x",
            defaultPromptTemplate: "path=[{{project_path}}]"
        )
        let prompt = generator.generatePrompt(for: custom, issue: issue, projectPath: nil)
        #expect(prompt.contains("path=[]"))
    }

    @Test("generateCommand for Claude executor starts with claude and embeds the prompt")
    func generateCommandClaudeExecutor() {
        let claude = AgentProfile.builtInProfiles.first { $0.id == AgentProfile.codingExecutorID }!
        let cmd = generator.generateCommand(for: claude, issue: issue, projectPath: projectPath)
        #expect(cmd.hasPrefix("claude --dangerously-skip-permissions \""))
        #expect(cmd.contains("bd-42"))
        #expect(cmd.hasSuffix("\""))
    }

    @Test("generateCommand for Codex executor uses interactive codex with prompt")
    func generateCommandCodexExecutor() {
        let codex = AgentProfile.builtInProfiles.first { $0.id == AgentProfile.codexExecutorID }!
        let cmd = generator.generateCommand(for: codex, issue: issue, projectPath: projectPath)
        #expect(cmd.hasPrefix("codex --dangerously-bypass-approvals-and-sandbox \""))
        #expect(!cmd.hasPrefix("codex exec"))
        #expect(cmd.contains("bd-42"))
    }

    @Test("generateCommand for DeepSeek executor keeps opencode model")
    func generateCommandDeepSeekExecutor() {
        let deepseek = AgentProfile.builtInProfiles.first { $0.id == AgentProfile.deepseekExecutorID }!
        let cmd = generator.generateCommand(for: deepseek, issue: issue, projectPath: projectPath)
        #expect(cmd.hasPrefix("opencode run -m opencode-go/deepseek-v4-flash \""))
        #expect(cmd.contains("bd-42"))
        #expect(cmd.hasSuffix("\""))
    }

    @Test("generateCommand escapes inner double-quotes")
    func generateCommandEscapesQuotes() {
        let trickyIssue = BeadIssue(id: "bd-1", title: "She said \"hi\"")
        let custom = AgentProfile(
            name: "Echo",
            role: .custom,
            command: "echo",
            defaultPromptTemplate: "title={{issue_title}}",
            commandArgsTemplate: "\"{{prompt}}\""
        )
        let cmd = generator.generateCommand(for: custom, issue: trickyIssue, projectPath: nil)
        #expect(cmd.contains("\\\"hi\\\""))
    }

    @Test("Review follow-up prompt embeds user notes and tells agent not to close")
    func reviewFollowupPromptIncludesNotes() {
        let prompt = generator.generateReviewFollowupPrompt(
            issue: issue,
            projectPath: projectPath,
            userNotes: "dark mode toggle nggak persist setelah restart"
        )
        #expect(prompt.contains("bd-42"))
        #expect(prompt.contains("Implement feature X"))
        #expect(prompt.contains("dark mode toggle nggak persist"))
        #expect(prompt.contains("bd prime"))
        #expect(prompt.contains("bd show bd-42 --json"))
        #expect(prompt.contains("bd update bd-42 --add-label human"))
        #expect(!prompt.contains("bd close bd-42"))
    }

    @Test("Review follow-up prompt trims whitespace from notes and handles empty input")
    func reviewFollowupPromptHandlesEmptyNotes() {
        let prompt = generator.generateReviewFollowupPrompt(
            issue: issue,
            projectPath: nil,
            userNotes: "   \n  "
        )
        #expect(prompt.contains("(no specific notes provided)"))
        #expect(prompt.contains("bd-42"))
    }

    @Test("generateCommand with empty args template returns just the command")
    func generateCommandEmptyTemplateReturnsCommandOnly() {
        let custom = AgentProfile(
            name: "Bare",
            role: .custom,
            command: "mycli",
            defaultPromptTemplate: "hello",
            commandArgsTemplate: ""
        )
        let cmd = generator.generateCommand(for: custom, issue: issue, projectPath: nil)
        #expect(cmd == "mycli")
    }

    @Test("executor and review followup prompts contain mandatory git merge and push protocol")
    func promptsContainGitMergeAndPushProtocol() {
        let executorPrompt = generator.generatePrompt(
            for: profile(for: .codingExecutor),
            issue: issue,
            projectPath: projectPath
        )
        #expect(executorPrompt.contains("MANDATORY Git Worktree Merge & Push Protocol"))
        #expect(executorPrompt.contains("git merge <your-branch-name> --no-edit"))
        #expect(executorPrompt.contains("git push origin master"))

        let followupPrompt = generator.generateReviewFollowupPrompt(
            issue: issue,
            projectPath: projectPath,
            userNotes: "re-test"
        )
        #expect(followupPrompt.contains("MANDATORY Git Worktree Merge & Push Protocol"))
        #expect(followupPrompt.contains("git merge <your-branch-name> --no-edit"))
        #expect(followupPrompt.contains("git push origin master"))
    }

    @Test("generateCommand robustly escapes backticks, dollar signs, and backslashes")
    func generateCommandEscapesSpecialShellCharacters() {
        let trickyIssue = BeadIssue(id: "bd-1", title: "Tricky title with `backticks`, $dollars, and \\backslashes")
        let custom = AgentProfile(
            name: "Echo",
            role: .custom,
            command: "echo",
            defaultPromptTemplate: "title={{issue_title}}",
            commandArgsTemplate: "\"{{prompt}}\""
        )
        let cmd = generator.generateCommand(for: custom, issue: trickyIssue, projectPath: nil)
        #expect(cmd.contains("\\`backticks\\`"))
        #expect(cmd.contains("\\$dollars"))
        #expect(cmd.contains("\\\\backslashes"))
    }
}
