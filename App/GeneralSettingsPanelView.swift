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
                    Divider().background(Color(hex: "#1A1A1A"))
                    autoReloadToggle
                    Divider().background(Color(hex: "#1A1A1A"))
                    doneVisibilitySection
                    Divider().background(Color(hex: "#1A1A1A"))
                    themeSection
                }
                .padding(20)
                .background(Color(hex: "#141414"))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#1E1E1E"), lineWidth: 1)
                )

                Spacer(minLength: 24)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0F0F0F"))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("General")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "#F0ECE4"))
            Text("Workspace behavior and appearance preferences")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#888888"))
        }
    }

    private var autoRestoreToggle: some View {
        ToggleRow(
            icon: "arrow.counterclockwise",
            title: "Auto-restore last project",
            subtitle: "Reopen the last used project when the app launches",
            isOn: preferences.autoRestoreOnLaunch
        ) {
            appVM.setAutoRestoreOnLaunch($0)
        }
    }

    private var autoReloadToggle: some View {
        ToggleRow(
            icon: "arrow.triangle.2.circlepath",
            title: "Auto-reload issues",
            subtitle: "Automatically refresh issues when the underlying file changes",
            isOn: preferences.autoReloadEnabled
        ) {
            appVM.setAutoReloadEnabled($0)
        }
    }

    private var doneVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .foregroundColor(Color(hex: "#888888"))
                    .font(.system(size: 14))
                Text("Done visibility window")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0ECE4"))
            }

            Text("How long to show completed issues in the Done column")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#888888"))

            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { preferences.doneVisibilityWindowSeconds / 3600 },
                        set: { appVM.setDoneVisibilityWindowSeconds($0 * 3600) }
                    ),
                    in: 1...72,
                    step: 1
                )
                .tint(Color(hex: "#ECC864"))

                Text("\(Int(preferences.doneVisibilityWindowSeconds / 3600)) hours")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#ECC864"))
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .foregroundColor(Color(hex: "#888888"))
                    .font(.system(size: 14))
                Text("Theme")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0ECE4"))
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
            .colorMultiply(Color(hex: "#ECC864"))
        }
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @State var isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#888888"))
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0ECE4"))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#888888"))
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: isOn) { _, newValue in
                    onChange(newValue)
                }
        }
    }
}
