import Foundation
import Testing
@testable import BeadsContract

@Suite("AgentProfile")
struct AgentProfileTests {
    @Test("Built-in profiles cover the canonical roles and include both executors")
    func builtInProfilesCoverRoles() {
        let roles = AgentProfile.builtInProfiles.map(\.role)
        #expect(roles.contains(.specWriter))
        #expect(roles.contains(.codingExecutor))
        #expect(roles.contains(.reviewer))
        #expect(roles.contains(.tester))
        #expect(AgentProfile.builtInProfiles.count == 5)
        let executors = AgentProfile.builtInProfiles.filter { $0.role == .codingExecutor }
        #expect(executors.count == 2)
        let allBuiltIn = AgentProfile.builtInProfiles.allSatisfy { $0.isBuiltIn }
        #expect(allBuiltIn)
    }

    @Test("Built-in commands cover Claude and Codex executors")
    func builtInCommandsMatchExpectations() {
        let byID = Dictionary(uniqueKeysWithValues: AgentProfile.builtInProfiles.map { ($0.id, $0) })
        #expect(byID[AgentProfile.specWriterID]?.command == "codex")
        #expect(byID[AgentProfile.codingExecutorID]?.command == "claude")
        #expect(byID[AgentProfile.codexExecutorID]?.command == "codex")
        #expect(byID[AgentProfile.reviewerID]?.command == "claude")
        #expect(byID[AgentProfile.testerID]?.command == "claude")
    }

    @Test("Built-in profiles expose avatar kinds for Codex and Claude")
    func builtInAvatarKindsMatchExpectations() {
        let byID = Dictionary(uniqueKeysWithValues: AgentProfile.builtInProfiles.map { ($0.id, $0) })
        #expect(byID[AgentProfile.specWriterID]?.avatarKind == .codex)
        #expect(byID[AgentProfile.codingExecutorID]?.avatarKind == .claude)
        #expect(byID[AgentProfile.codexExecutorID]?.avatarKind == .codex)
        #expect(byID[AgentProfile.reviewerID]?.avatarKind == .claude)
        #expect(byID[AgentProfile.testerID]?.avatarKind == .claude)
    }

    @Test("Avatar kinds map to the expected claim assignee tokens")
    func avatarKindsMapToClaimAssigneeTokens() {
        #expect(AgentAvatarKind.claude.claimAssigneeToken == "claude")
        #expect(AgentAvatarKind.codex.claimAssigneeToken == "codex")
        #expect(AgentAvatarKind.other.claimAssigneeToken == "other")
        #expect(AgentAvatarKind.initials.claimAssigneeToken == "other")
        let custom = AgentProfile(
            name: "Custom",
            role: .custom,
            command: "tool",
            avatarKind: .initials
        )
        #expect(custom.claimAssigneeToken == "other")
    }

    @Test("Capability flags are set correctly for built-in profiles")
    func capabilityFlagsForBuiltIns() {
        let byID = Dictionary(uniqueKeysWithValues: AgentProfile.builtInProfiles.map { ($0.id, $0) })
        // Executors can execute + claim + request review, but do NOT close (human decides)
        for execID in [AgentProfile.codingExecutorID, AgentProfile.codexExecutorID] {
            let p = byID[execID]
            #expect(p?.canExecuteCode == true)
            #expect(p?.shouldClaimIssue == true)
            #expect(p?.shouldCloseIssue == false)
            #expect(p?.shouldRequestHumanReview == true)
        }
        // Non-executors have everything disabled
        for nonExecID in [AgentProfile.specWriterID, AgentProfile.reviewerID, AgentProfile.testerID] {
            let p = byID[nonExecID]
            #expect(p?.canExecuteCode == false)
            #expect(p?.shouldClaimIssue == false)
            #expect(p?.shouldCloseIssue == false)
            #expect(p?.shouldRequestHumanReview == false)
        }
    }

    @Test("Legacy JSON without new fields decodes with default values")
    func decodableWithLegacyJSON() throws {
        let legacy = """
        {
            "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            "name": "Old Custom",
            "role": "custom",
            "command": "x",
            "defaultPromptTemplate": "hi",
            "isBuiltIn": false
        }
        """
        let decoded = try JSONDecoder().decode(AgentProfile.self, from: Data(legacy.utf8))
        #expect(decoded.name == "Old Custom")
        #expect(decoded.commandArgsTemplate == "")
        #expect(decoded.avatarKind == .initials)
        #expect(decoded.canExecuteCode == false)
        #expect(decoded.shouldClaimIssue == false)
        #expect(decoded.shouldCloseIssue == false)
        #expect(decoded.shouldRequestHumanReview == false)
    }

    @Test("Built-in IDs are stable across calls")
    func builtInIDsAreStable() {
        let first = AgentProfile.builtInProfiles.map(\.id)
        let second = AgentProfile.builtInProfiles.map(\.id)
        #expect(first == second)
    }

    @Test("AgentProfile roundtrips through Codable")
    func codableRoundtrip() throws {
        let original = AgentProfile(
            id: UUID(),
            name: "Custom",
            role: .custom,
            command: "my-cli",
            defaultPromptTemplate: "hello {{issue_id}}",
            avatarKind: .claude,
            isBuiltIn: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentProfile.self, from: data)
        #expect(decoded == original)
    }

    @Test("AgentRole.allCases covers every role with non-empty display names")
    func agentRoleMetadata() {
        #expect(AgentRole.allCases.count == 5)
        for role in AgentRole.allCases {
            #expect(!role.displayName.isEmpty)
        }
    }
}
