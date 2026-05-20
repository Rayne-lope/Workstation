import Testing
@testable import BeadsContract
@testable import BeadsWorkspace

@Suite("AssigneeAvatarResolver")
struct AssigneeAvatarResolverTests {
    @Test("Known Claude and Codex profiles resolve to branded avatar kinds")
    func resolvesKnownBuiltIns() {
        let resolver = AssigneeAvatarResolver()
        let profiles = AgentProfile.builtInProfiles

        let claude = resolver.resolve(assignee: "Claude Code Executor", profiles: profiles)
        #expect(claude?.kind == .claude)
        #expect(claude?.label == "Claude Code Executor")
        #expect(claude?.monogram == "CL")

        let codex = resolver.resolve(assignee: "Codex Code Executor", profiles: profiles)
        #expect(codex?.kind == .codex)
        #expect(codex?.label == "Codex Code Executor")
        #expect(codex?.monogram == "CX")
    }

    @Test("Unknown assignees fall back to initials")
    func fallsBackToInitials() {
        let resolver = AssigneeAvatarResolver()
        let profiles = AgentProfile.builtInProfiles

        let avatar = resolver.resolve(assignee: "Rayne-lope", profiles: profiles)
        #expect(avatar?.kind == .initials)
        #expect(avatar?.label == "Rayne-lope")
        #expect(avatar?.monogram == "R")
    }

    @Test("Short tokens like 'claude' and 'codex' resolve to branded kinds")
    func resolvesShortTokens() {
        let resolver = AssigneeAvatarResolver()
        let profiles = AgentProfile.builtInProfiles

        for token in ["claude", "Claude", "CLAUDE", "claude-code", "anthropic"] {
            let avatar = resolver.resolve(assignee: token, profiles: profiles)
            #expect(avatar?.kind == .claude, "token=\(token)")
            #expect(avatar?.label == token)
        }

        for token in ["codex", "Codex", "openai-codex", "openai"] {
            let avatar = resolver.resolve(assignee: token, profiles: profiles)
            #expect(avatar?.kind == .codex, "token=\(token)")
            #expect(avatar?.label == token)
        }

        for token in ["other", "Other", "gemini", "gpt", "llm", "bot", "agent"] {
            let avatar = resolver.resolve(assignee: token, profiles: profiles)
            #expect(avatar?.kind == .other, "token=\(token)")
            #expect(avatar?.label == token)
            #expect(avatar?.monogram == "AI")
        }
    }

    @Test("Empty or missing assignees do not render avatars")
    func ignoresEmptyAssignees() {
        let resolver = AssigneeAvatarResolver()
        let profiles = AgentProfile.builtInProfiles

        #expect(resolver.resolve(assignee: nil, profiles: profiles) == nil)
        #expect(resolver.resolve(assignee: "", profiles: profiles) == nil)
        #expect(resolver.resolve(assignee: "   ", profiles: profiles) == nil)
    }
}
