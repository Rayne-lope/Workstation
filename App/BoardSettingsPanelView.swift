import SwiftUI

struct BoardSettingsPanelView: View {
    @Bindable var appVM: AppViewModel

    private var preferences: AppPreferences {
        appVM.preferencesStore.preferences
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    compactModeSection
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
            Text("Board")
                .font(WorkstationTheme.Fonts.display(22, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Text("Kanban board display and layout preferences")
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
    }

    private var compactModeSection: some View {
        ToggleRow(
            icon: "rectangle.3.group",
            title: "Compact card layout",
            subtitle: "Show fewer details per card to fit more issues on screen",
            isOn: Binding(
                get: { preferences.kanbanCompactMode },
                set: { appVM.setKanbanCompactMode($0) }
            )
        )
    }
}