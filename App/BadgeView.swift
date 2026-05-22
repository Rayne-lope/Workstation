import SwiftUI

struct BadgeView<Content: View>: View {
    let style: BadgeStyle
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 2
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(style.foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(style.background)
            .overlay {
                if let border = style.border {
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(border, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }
}

enum BadgeStyle {
    case id
    case surface
    case accent
    case priority(Int)
    case info
    case blocked
    case warning
    case recurring(isOverdue: Bool)
    case focus

    var foreground: Color {
        switch self {
        case .id:
            return WorkstationTheme.textMuted
        case .surface:
            return WorkstationTheme.textSecondary
        case .accent:
            return WorkstationTheme.background
        case .priority(let priority):
            return WorkstationTheme.difficultyColor(priority)
        case .info:
            return WorkstationTheme.blue
        case .blocked:
            return WorkstationTheme.red
        case .warning:
            return WorkstationTheme.orange
        case .recurring(let isOverdue):
            return isOverdue ? WorkstationTheme.orange : WorkstationTheme.purple
        case .focus:
            return WorkstationTheme.background
        }
    }

    var background: Color {
        switch self {
        case .id:
            return WorkstationTheme.borderSoft
        case .surface:
            return WorkstationTheme.cardAlt
        case .accent:
            return WorkstationTheme.accent
        case .priority(let priority):
            return priority <= 1 ? WorkstationTheme.accentBg : WorkstationTheme.cardAlt
        case .info:
            return WorkstationTheme.blueBg
        case .blocked:
            return WorkstationTheme.redBg
        case .warning:
            return WorkstationTheme.orangeBg
        case .recurring(let isOverdue):
            return isOverdue ? WorkstationTheme.orangeBg : WorkstationTheme.purpleBg
        case .focus:
            return WorkstationTheme.accent
        }
    }

    var border: Color? {
        switch self {
        case .id:
            return nil
        case .surface:
            return WorkstationTheme.borderStrong
        case .accent:
            return WorkstationTheme.accent
        case .priority(let priority):
            return priority <= 1 ? WorkstationTheme.accentBorder : WorkstationTheme.borderStrong
        case .info:
            return WorkstationTheme.blueBorder
        case .blocked:
            return WorkstationTheme.redBorder
        case .warning:
            return WorkstationTheme.orangeBorder
        case .recurring(let isOverdue):
            return isOverdue ? WorkstationTheme.orangeBorder : WorkstationTheme.purpleBorder
        case .focus:
            return WorkstationTheme.accent
        }
    }
}
