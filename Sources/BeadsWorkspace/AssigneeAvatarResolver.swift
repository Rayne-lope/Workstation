import Foundation
#if canImport(BeadsContract)
import BeadsContract
#endif

public struct AssigneeAvatarDescriptor: Hashable, Sendable {
    public let kind: AgentAvatarKind
    public let label: String
    public let monogram: String

    public init(kind: AgentAvatarKind, label: String, monogram: String) {
        self.kind = kind
        self.label = label
        self.monogram = monogram
    }
}

public struct AssigneeAvatarResolver: Sendable {
    public init() {}

    public func resolve(
        assignee: String?,
        profiles: [AgentProfile]
    ) -> AssigneeAvatarDescriptor? {
        guard let name = assignee?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else {
            return nil
        }

        if let profile = profiles.first(where: { normalized($0.name) == normalized(name) }) {
            return AssigneeAvatarDescriptor(
                kind: profile.avatarKind,
                label: profile.name,
                monogram: profile.avatarMonogram
            )
        }

        if let kind = brandKind(forShortToken: name) {
            return AssigneeAvatarDescriptor(
                kind: kind,
                label: name,
                monogram: kind.fallbackMonogram
            )
        }

        return AssigneeAvatarDescriptor(
            kind: .initials,
            label: name,
            monogram: name.beadsAvatarInitial
        )
    }

    private func brandKind(forShortToken raw: String) -> AgentAvatarKind? {
        Self.brandKind(forShortToken: raw)
    }

    public static func brandKind(forShortToken raw: String) -> AgentAvatarKind? {
        let token = staticNormalized(raw)
        let claudeAliases = ["claude", "claude-code", "claude_code", "anthropic"]
        let codexAliases = ["codex", "openai-codex", "openai"]
        let kimiAliases = ["kimi", "moonshot"]
        let zhipuAliases = ["zhipu", "glm", "chatglm"]
        let geminiAliases = ["gemini", "google"]
        let deepseekAliases = ["deepseek", "deep-seek"]
        let minimaxAliases = ["minimax", "mini-max"]
        let otherAliases = ["other", "gpt", "llm", "bot", "ai-other", "agent"]
        if claudeAliases.contains(where: { token == $0 || token.contains($0) }) {
            return .claude
        }
        if codexAliases.contains(where: { token == $0 || token.contains($0) }) {
            return .codex
        }
        if kimiAliases.contains(where: { token == $0 || token.contains($0) }) {
            return .kimi
        }
        if zhipuAliases.contains(where: { token == $0 || token.contains($0) }) {
            return .zhipu
        }
        if geminiAliases.contains(where: { token == $0 || token.contains($0) }) {
            return .gemini
        }
        if deepseekAliases.contains(where: { token == $0 || token.contains($0) }) {
            return .deepseek
        }
        if minimaxAliases.contains(where: { token == $0 || token.contains($0) }) {
            return .minimax
        }
        if otherAliases.contains(where: { token == $0 || token.contains($0) }) {
            return .other
        }
        return nil
    }

    private static func staticNormalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
