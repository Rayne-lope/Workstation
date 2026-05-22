import SwiftUI

struct GeneralSettingsPanelView: View {
    @Bindable var appVM: AppViewModel

    private var preferences: AppPreferences {
        appVM.preferencesStore.preferences
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    autoRestoreToggle
                    Divider().overlay(WorkstationTheme.borderSoft)
                    autoReloadToggle
                    Divider().overlay(WorkstationTheme.borderSoft)
                    doneVisibilitySection
                    Divider().overlay(WorkstationTheme.borderSoft)
                    themeSection
                }
                .padding(20)
                .background(WorkstationTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                        .stroke(WorkstationTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))

                Spacer(minLength: 24)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkstationTheme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("General")
                .font(WorkstationTheme.Fonts.display(22, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Text("Workspace behavior and appearance preferences")
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
    }

    private var autoRestoreToggle: some View {
        ToggleRow(
            icon: "arrow.counterclockwise",
            title: "Auto-restore last project",
            subtitle: "Reopen the last used project when the app launches",
            isOn: Binding(
                get: { preferences.autoRestoreOnLaunch },
                set: { appVM.setAutoRestoreOnLaunch($0) }
            )
        )
    }

    private var autoReloadToggle: some View {
        ToggleRow(
            icon: "arrow.triangle.2.circlepath",
            title: "Auto-reload issues",
            subtitle: "Automatically refresh issues when the underlying file changes",
            isOn: Binding(
                get: { preferences.autoReloadEnabled },
                set: { appVM.setAutoReloadEnabled($0) }
            )
        )
    }

    private var doneVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("Done visibility window")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            Text("How long to show completed issues in the Done column")
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textMuted)

            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { preferences.doneVisibilityWindowSeconds / 3600 },
                        set: { appVM.setDoneVisibilityWindowSeconds($0 * 3600) }
                    ),
                    in: 1...72,
                    step: 1
                )
                .tint(WorkstationTheme.accent)

                Text("\(Int(preferences.doneVisibilityWindowSeconds / 3600)) hours")
                    .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                    .foregroundStyle(WorkstationTheme.accent)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("Theme")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            Picker("Theme", selection: Binding(
                get: { preferences.theme },
                set: { appVM.setTheme($0) }
            )) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(WorkstationTheme.accent)
        }
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(WorkstationTheme.textSecondary)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text(subtitle)
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}
