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
                    Divider().background(Color(hex: "#1A1A1A"))
                    defaultPrioritySection
                    Divider().background(Color(hex: "#1A1A1A"))
                    closeReasonTemplateSection
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
            Text("Defaults")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "#F0ECE4"))
            Text("Default values for new issues and close templates")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#888888"))
        }
    }

    private var defaultIssueTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundColor(Color(hex: "#888888"))
                    .font(.system(size: 14))
                Text("Default issue type")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0ECE4"))
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
                    .foregroundColor(Color(hex: "#888888"))
                    .font(.system(size: 14))
                Text("Default priority")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0ECE4"))
            }

            HStack(spacing: 0) {
                ForEach(priorities, id: \.0) { value, label, desc in
                    Button {
                        appVM.setDefaultIssuePriority(value)
                    } label: {
                        VStack(spacing: 2) {
                            Text(label)
                                .font(.system(size: 11, weight: .bold))
                            Text(desc)
                                .font(.system(size: 9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            preferences.defaultIssuePriority == value
                                ? Color(hex: "#ECC864")
                                : Color(hex: "#1A1A1A")
                        )
                        .foregroundColor(
                            preferences.defaultIssuePriority == value
                                ? Color(hex: "#0F0F0F")
                                : Color(hex: "#888888")
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(hex: "#1A1A1A"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#2A2A2A"), lineWidth: 1)
            )
        }
    }

    private var closeReasonTemplateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .foregroundColor(Color(hex: "#888888"))
                    .font(.system(size: 14))
                Text("Default close reason template")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0ECE4"))
            }

            Text("This text will prefill the close reason field when closing an issue")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#888888"))

            TextEditor(text: Binding(
                get: { preferences.defaultCloseReasonTemplate },
                set: { appVM.setDefaultCloseReasonTemplate($0) }
            ))
            .font(.system(size: 13))
            .foregroundColor(Color(hex: "#F0ECE4"))
            .frame(minHeight: 100)
            .padding(8)
            .background(Color(hex: "#151515"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#222222"), lineWidth: 1)
            )
        }
    }
}
