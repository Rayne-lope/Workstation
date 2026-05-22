import SwiftUI

struct FocusStripView: View {
    @Bindable var appVM: AppViewModel

    private var issueTitle: String {
        guard let id = appVM.activeFocusIssueID else { return "" }
        return appVM.issueStore?.issues.first { $0.id == id }?.title ?? id
    }

    private var elapsedFormatted: String {
        let totalSeconds = max(0, appVM.focusElapsedMs / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Status dot
            Circle()
                .fill(appVM.isFocusPaused ? WorkstationTheme.textMuted : WorkstationTheme.accent)
                .frame(width: 7, height: 7)
                .animation(.easeInOut(duration: 0.3), value: appVM.isFocusPaused)

            // Issue info
            HStack(spacing: 6) {
                Text("FOCUS")
                    .font(WorkstationTheme.Fonts.body(9, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .tracking(0.8)

                Text(appVM.activeFocusIssueID ?? "")
                    .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                    .foregroundStyle(WorkstationTheme.accent)

                if !appVM.isFocusPaused {
                    Text("·")
                        .foregroundStyle(WorkstationTheme.textSubtle)
                    Text(issueTitle)
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            // Timer
            HStack(spacing: 4) {
                if appVM.isFocusPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
                Text(elapsedFormatted)
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium).monospacedDigit())
                    .foregroundStyle(appVM.isFocusPaused ? WorkstationTheme.textMuted : WorkstationTheme.textPrimary)
            }

            // Pause / Resume button
            Button {
                if appVM.isFocusPaused {
                    appVM.resumeFocus()
                } else {
                    appVM.pauseFocus()
                }
            } label: {
                Image(systemName: appVM.isFocusPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(WorkstationTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small))
            }
            .buttonStyle(.plain)
            .help(appVM.isFocusPaused ? "Resume focus" : "Pause focus")

            // End button
            Button {
                appVM.endFocus()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .frame(width: 24, height: 24)
                    .background(WorkstationTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small)
                            .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small))
            }
            .buttonStyle(.plain)
            .help("End focus session")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(WorkstationTheme.accentBg)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(WorkstationTheme.accentBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }
}