import AppKit
import SwiftUI

struct AssigneeBadgeView: View {
    let assignee: String?
    let profiles: [AgentProfile]
    var compact: Bool = false

    private let resolver = AssigneeAvatarResolver()

    var body: some View {
        if let descriptor = resolver.resolve(assignee: assignee, profiles: profiles) {
            HStack(spacing: compact ? 6 : 8) {
                avatarGlyph(for: descriptor)

                Text(descriptor.label)
                    .font(WorkstationTheme.Fonts.body(compact ? 11 : 12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, compact ? 7 : 8)
            .padding(.vertical, compact ? 3 : 5)
            .background(
                RoundedRectangle(cornerRadius: compact ? WorkstationTheme.Radius.medium : WorkstationTheme.Radius.large, style: .continuous)
                    .fill(WorkstationTheme.cardAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? WorkstationTheme.Radius.medium : WorkstationTheme.Radius.large, style: .continuous)
                    .stroke(borderColor(for: descriptor.kind), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Assignee \(descriptor.label)")
        }
    }

    @ViewBuilder
    private func avatarGlyph(for descriptor: AssigneeAvatarDescriptor) -> some View {
        let size: CGFloat = compact ? 18 : 22
        let iconSize: CGFloat = compact ? 10 : 12
        switch descriptor.kind {
        case .codex:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    avatarImage(name: "codex_logo", fallbackSystemImage: "chevron.left.forwardslash.chevron.right", kind: descriptor.kind, iconSize: iconSize)
                )
                .accessibilityLabel("Codex")
        case .claude:
            Capsule(style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size + 2, height: size)
                .overlay(
                    avatarImage(name: "claude-logo", fallbackSystemImage: "sparkles", kind: descriptor.kind, iconSize: iconSize + 1)
                )
                .accessibilityLabel("Claude")
        case .other:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    avatarImage(name: "robot_logo", fallbackSystemImage: "cpu.fill", kind: descriptor.kind, iconSize: iconSize)
                )
                .accessibilityLabel("Other AI")
        case .initials:
            Circle()
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    Text(descriptor.monogram)
                        .font(.system(size: compact ? 8.5 : 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(foregroundColor(for: descriptor.kind))
                )
        }
    }

    @ViewBuilder
    private func avatarImage(
        name: String,
        fallbackSystemImage: String,
        kind: AgentAvatarKind,
        iconSize: CGFloat
    ) -> some View {
        if let image = bundledImage(named: name) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(compact ? 2 : 3)
                .accessibilityHidden(true)
        } else {
            Image(systemName: fallbackSystemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(foregroundColor(for: kind))
                .accessibilityHidden(true)
        }
    }

    private func bundledImage(named name: String) -> NSImage? {
        Bundle.main
            .url(forResource: name, withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
    }

    private func backgroundColor(for kind: AgentAvatarKind) -> Color {
        switch kind {
        case .codex:
            return Color(hex: "0F1A1F")
        case .claude:
            return Color(hex: "1A1608")
        case .other:
            return Color(hex: "1A0F1A")
        case .initials:
            return Color(hex: "222222")
        }
    }

    private func borderColor(for kind: AgentAvatarKind) -> Color {
        switch kind {
        case .codex:
            return Color(hex: "0F2535")
        case .claude:
            return Color(hex: "3A2F0A")
        case .other:
            return Color(hex: "2E1A40")
        case .initials:
            return WorkstationTheme.borderStrong
        }
    }

    private func foregroundColor(for kind: AgentAvatarKind) -> Color {
        switch kind {
        case .codex:
            return WorkstationTheme.blue
        case .claude:
            return WorkstationTheme.accent
        case .other:
            return WorkstationTheme.purple
        case .initials:
            return WorkstationTheme.textSecondary
        }
    }
}
