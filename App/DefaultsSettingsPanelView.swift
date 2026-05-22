import SwiftUI

struct DefaultsSettingsPanelView: View {
    @Bindable var appVM: AppViewModel

    private var preferences: AppPreferences {
        appVM.preferencesStore.preferences
    }

    private let issueTypes = [
        ("task", "Task"),
        ("bug", "Bug"),
        ("feature", "Feature"),
        ("epic", "Epic"),
        ("chore", "Chore")
    ]

    private let priorities = [
        (0, "P0", "Must"),
        (1, "P1", "Important"),
        (2, "P2", "High"),
        (3, "P3", "Medium"),
        (4, "P4", "Low")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    defaultIssueTypeSection
                    Divider().overlay(WorkstationTheme.borderSoft)
                    defaultPrioritySection
                    Divider().overlay(WorkstationTheme.borderSoft)
                    closeReasonTemplateSection
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
            Text("Defaults")
                .font(WorkstationTheme.Fonts.display(22, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Text("Default values for new issues and close templates")
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
    }

    private var defaultIssueTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("Default issue type")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            Picker("Issue Type", selection: Binding(
                get: { preferences.defaultIssueType },
                set: { appVM.setDefaultIssueType($0) }
            )) {
                ForEach(issueTypes, id: \.0) { type, label in
                    Text(label)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)
        }
    }

    private var defaultPrioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("Default priority")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            HStack(spacing: 0) {
                ForEach(priorities, id: \.0) { value, label, desc in
                    Button {
                        appVM.setDefaultIssuePriority(value)
                    } label: {
                        VStack(spacing: 2) {
                            Text(label)
                                .font(WorkstationTheme.Fonts.body(11, weight: .bold))
                            Text(desc)
                                .font(WorkstationTheme.Fonts.body(9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            preferences.defaultIssuePriority == value
                                ? WorkstationTheme.accent
                                : WorkstationTheme.cardAlt
                        )
                        .foregroundStyle(
                            preferences.defaultIssuePriority == value
                                ? WorkstationTheme.background
                                : WorkstationTheme.textMuted
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(WorkstationTheme.cardAlt)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
        }
    }

    private var closeReasonTemplateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("Default close reason template")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            Text("This text will prefill the close reason field when closing an issue")
                .font(WorkstationTheme.Fonts.body(12))
                .foregroundStyle(WorkstationTheme.textSecondary)

            TextEditor(text: Binding(
                get: { preferences.defaultCloseReasonTemplate },
                set: { appVM.setDefaultCloseReasonTemplate($0) }
            ))
            .font(WorkstationTheme.Fonts.body(13))
            .foregroundStyle(WorkstationTheme.textPrimary)
            .frame(minHeight: 100)
            .padding(8)
            .background(WorkstationTheme.cardAlt)
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
        }
    }
}
