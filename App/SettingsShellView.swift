import SwiftUI

struct SettingsShellView: View {
    @Bindable var appVM: AppViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 700, minHeight: 500)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(SettingsTab.allCases, selection: $appVM.settingsSelectedTab) { tab in
                Label(tab.label, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)

            Divider().overlay(WorkstationTheme.borderSoft)

            Button(action: {
                appVM.resetSettingsToDefaults()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 14))
                    Text("Reset to Defaults")
                    Spacer()
                }
                .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                .foregroundStyle(WorkstationTheme.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appVM.settingsSelectedTab {
        case .general:
            GeneralSettingsPanelView(appVM: appVM)
        case .defaults:
            DefaultsSettingsPanelView(appVM: appVM)
        case .board:
            BoardSettingsPanelView(appVM: appVM)
        case .localAI:
            LocalAISettingsPanelView(appVM: appVM)
        case .agentProfiles:
            AgentProfilesSettingsPanelView(appVM: appVM)
        }
    }
}
