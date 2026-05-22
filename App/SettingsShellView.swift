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
        List(SettingsTab.allCases, selection: $appVM.settingsSelectedTab) { tab in
            Label(tab.label, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appVM.settingsSelectedTab {
        case .general:
            GeneralSettingsPanelView(appVM: appVM)
        case .defaults:
            DefaultsSettingsPanelView(appVM: appVM)
        case .localAI:
            LocalAISettingsPanelView(appVM: appVM)
        case .agentProfiles:
            AgentProfilesSettingsPanelView(appVM: appVM)
        }
    }
}
