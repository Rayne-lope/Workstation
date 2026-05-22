import AppKit
import SwiftUI

struct AssigneeBadgeView: View {
    let assignee: String?
    let profiles: [AgentProfile]
    var compact: Bool = false
    var showName: Bool = true

    private let resolver = AssigneeAvatarResolver()

    var body: some View {
        if let descriptor = resolver.resolve(assignee: assignee, profiles: profiles) {
            HStack(spacing: compact ? 6 : 8) {
                avatarGlyph(for: descriptor)

                if showName {
                    Text(descriptor.label)
                        .font(WorkstationTheme.Fonts.body(compact ? 11 : 12, weight: .semibold))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, showName ? (compact ? 7 : 8) : 0)
            .padding(.vertical, showName ? (compact ? 3 : 5) : 0)
            .background(
                Group {
                    if showName {
                        RoundedRectangle(cornerRadius: compact ? WorkstationTheme.Radius.medium : WorkstationTheme.Radius.large, style: .continuous)
                            .fill(WorkstationTheme.cardAlt)
                    }
                }
            )
            .overlay(
                Group {
                    if showName {
                        RoundedRectangle(cornerRadius: compact ? WorkstationTheme.Radius.medium : WorkstationTheme.Radius.large, style: .continuous)
                            .stroke(borderColor(for: descriptor.kind), lineWidth: 1)
                    }
                }
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
                .clipped()
                .accessibilityLabel("Codex")
        case .claude:
            Capsule(style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size + 2, height: size)
                .overlay(
                    avatarImage(name: "claude-logo", fallbackSystemImage: "sparkles", kind: descriptor.kind, iconSize: iconSize + 1)
                )
                .clipped()
                .accessibilityLabel("Claude")
        case .kimi:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    avatarImage(name: "kimi", fallbackSystemImage: "moon.stars.fill", kind: descriptor.kind, iconSize: iconSize)
                )
                .clipped()
                .accessibilityLabel("Kimi")
        case .zhipu:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    avatarImage(name: "glm", fallbackSystemImage: "cube.fill", kind: descriptor.kind, iconSize: iconSize)
                )
                .clipped()
                .accessibilityLabel("Zhipu")
        case .gemini:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    avatarImage(name: "gemini", fallbackSystemImage: "diamond.fill", kind: descriptor.kind, iconSize: iconSize)
                )
                .clipped()
                .accessibilityLabel("Gemini")
        case .deepseek:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    avatarImage(name: "deepseek", fallbackSystemImage: "water.waves", kind: descriptor.kind, iconSize: iconSize)
                )
                .clipped()
                .accessibilityLabel("DeepSeek")
        case .minimax:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    avatarImage(name: "minimax", fallbackSystemImage: "arrow.up.forward", kind: descriptor.kind, iconSize: iconSize)
                )
                .clipped()
                .accessibilityLabel("MiniMax")
        case .other:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(for: descriptor.kind))
                .frame(width: size, height: size)
                .overlay(
                    avatarImage(name: "robot_logo", fallbackSystemImage: "cpu.fill", kind: descriptor.kind, iconSize: iconSize)
                )
                .clipped()
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
        let imageSize = CGSize(width: iconSize + 4, height: iconSize + 4)
        if let image = bundledImage(named: name, fitting: imageSize) {
            Image(nsImage: image)
                .frame(width: imageSize.width, height: imageSize.height)
                .padding(compact ? 2 : 3)
                .accessibilityHidden(true)
        } else {
            Image(systemName: fallbackSystemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(foregroundColor(for: kind))
                .frame(width: imageSize.width, height: imageSize.height)
                .accessibilityHidden(true)
        }
    }

    private func bundledImage(named name: String, fitting size: CGSize) -> NSImage? {
        guard let sourceImage = Bundle.main
            .url(forResource: name, withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        else {
            return nil
        }

        let targetRect = NSRect(origin: .zero, size: size)
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        sourceImage.draw(
            in: targetRect,
            from: NSRect(origin: .zero, size: sourceImage.size),
            operation: .sourceOver,
            fraction: 1
        )
        resizedImage.unlockFocus()
        return resizedImage
    }

    private func backgroundColor(for kind: AgentAvatarKind) -> Color {
        switch kind {
        case .codex:
            // dark: deep teal  |  light: soft sky
            return adaptive(light: "EFF6FF", dark: "0F1A1F")
        case .claude:
            // dark: deep gold  |  light: soft amber
            return adaptive(light: "FEFCE8", dark: "1A1608")
        case .kimi:
            // dark: deep indigo  |  light: soft lavender
            return adaptive(light: "F5F3FF", dark: "1A1030")
        case .zhipu:
            // dark: deep cyan  |  light: soft cyan
            return adaptive(light: "ECFEFF", dark: "0A1A1F")
        case .gemini:
            // dark: deep blue  |  light: soft blue
            return adaptive(light: "EFF6FF", dark: "0F172A")
        case .deepseek:
            // dark: deep ocean  |  light: soft teal
            return adaptive(light: "F0FDFA", dark: "0A1F1A")
        case .minimax:
            // dark: deep rose  |  light: soft rose
            return adaptive(light: "FFF1F2", dark: "1A0A0F")
        case .other:
            // dark: deep indigo  |  light: soft lavender
            return adaptive(light: "FAF5FF", dark: "1A0F1A")
        case .initials:
            return WorkstationTheme.hover
        }
    }

    private func borderColor(for kind: AgentAvatarKind) -> Color {
        switch kind {
        case .codex:
            return adaptive(light: "BFDBFE", dark: "0F2535")
        case .claude:
            return adaptive(light: "FDE68A", dark: "3A2F0A")
        case .kimi:
            return adaptive(light: "DDD6FE", dark: "2E1A5C")
        case .zhipu:
            return adaptive(light: "A5F3FC", dark: "0F2E35")
        case .gemini:
            return adaptive(light: "BFDBFE", dark: "1E3A5F")
        case .deepseek:
            return adaptive(light: "99F6E4", dark: "0F3528")
        case .minimax:
            return adaptive(light: "FECDD3", dark: "3E1A1A")
        case .other:
            return adaptive(light: "E9D5FF", dark: "2E1A40")
        case .initials:
            return WorkstationTheme.borderStrong
        }
    }

    /// Mirrors `WorkstationTheme.adaptive` — local helper so this file stays self-contained.
    private func adaptive(light: String, dark: String) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            var value: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&value)
            return NSColor(
                red:   CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >>  8) & 0xFF) / 255,
                blue:  CGFloat( value        & 0xFF) / 255,
                alpha: 1
            )
        }))
    }

    private func foregroundColor(for kind: AgentAvatarKind) -> Color {
        switch kind {
        case .codex:
            return WorkstationTheme.blue
        case .claude:
            return WorkstationTheme.accent
        case .kimi:
            return adaptive(light: "7C3AED", dark: "A78BFA")
        case .zhipu:
            return adaptive(light: "0891B2", dark: "22D3EE")
        case .gemini:
            return adaptive(light: "3B82F6", dark: "60A5FA")
        case .deepseek:
            return adaptive(light: "14B8A6", dark: "2DD4BF")
        case .minimax:
            return adaptive(light: "F43F5E", dark: "FB7185")
        case .other:
            return WorkstationTheme.purple
        case .initials:
            return WorkstationTheme.textSecondary
        }
    }
}
