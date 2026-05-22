import SwiftUI

struct AgentProfilesSettingsPanelView: View {
    @Bindable var appVM: AppViewModel

    @State private var isSheetPresented = false
    @State private var draftProfile: AgentProfile? = nil

    private var store: AgentProfileStore {
        appVM.agentProfileStore
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    listHeader
                    profileList
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
        .sheet(isPresented: $isSheetPresented) {
            if let draft = draftProfile {
                AgentProfileEditSheet(
                    profile: draft,
                    onSave: { updated in
                        if store.profiles.contains(where: { $0.id == updated.id }) {
                            store.updateProfile(updated)
                        } else {
                            store.addProfile(updated)
                        }
                        isSheetPresented = false
                        draftProfile = nil
                    },
                    onCancel: {
                        isSheetPresented = false
                        draftProfile = nil
                    }
                )
                .frame(minWidth: 520, minHeight: 680)
            }
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent Profiles")
                    .font(WorkstationTheme.Fonts.display(22, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Configure developer agent profiles and their capabilities.")
                    .font(WorkstationTheme.Fonts.body(13))
                    .foregroundStyle(WorkstationTheme.textSecondary)
            }
            Spacer()
            Button {
                presentCreate()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Custom Agent")
                        .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(WorkstationTheme.accent)
                .foregroundStyle(WorkstationTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: – List Header

    private var listHeader: some View {
        HStack {
            Text("Profiles")
                .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textSubtle)
                .textCase(.uppercase)
            Spacer()
            Text("\(store.profiles.count) total")
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
    }

    // MARK: – Profile List

    private var profileList: some View {
        VStack(spacing: 0) {
            ForEach(store.profiles) { profile in
                profileRow(profile)
                if profile.id != store.profiles.last?.id {
                    Divider()
                        .background(WorkstationTheme.borderSoft)
                        .padding(.leading, 52)
                }
            }
        }
    }

    private func profileRow(_ profile: AgentProfile) -> some View {
        HStack(spacing: 12) {
            avatarView(for: profile)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)

                HStack(spacing: 6) {
                    BadgeView(style: .surface, horizontalPadding: 8, verticalPadding: 2) {
                        Text(profile.role.displayName)
                            .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                    }

                    if profile.isBuiltIn {
                        BadgeView(style: .info, horizontalPadding: 8, verticalPadding: 2) {
                            Text("Built-in")
                                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                        }
                    }

                    if let cadence = profile.cadenceDays {
                        BadgeView(style: .recurring(isOverdue: false), horizontalPadding: 8, verticalPadding: 2) {
                            Text("\(cadence)d cadence")
                                .font(WorkstationTheme.Fonts.body(10, weight: .semibold))
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                iconButton(icon: "pencil", action: {
                    presentEdit(profile)
                })
                iconButton(icon: "doc.on.doc", action: {
                    presentDuplicate(profile)
                })
                if !profile.isBuiltIn {
                    iconButton(icon: "trash", action: {
                        store.deleteProfile(id: profile.id)
                    }, color: WorkstationTheme.red)
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func avatarView(for profile: AgentProfile) -> some View {
        ZStack {
            Circle()
                .fill(WorkstationTheme.hover)
            Text(profile.avatarMonogram)
                .font(WorkstationTheme.Fonts.body(12, weight: .bold))
                .foregroundStyle(profile.isBuiltIn ? WorkstationTheme.accent : WorkstationTheme.textSecondary)
        }
        .frame(width: 32, height: 32)
    }

    private func iconButton(icon: String, action: @escaping () -> Void, color: Color? = nil) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color ?? WorkstationTheme.textMuted)
                .frame(width: 30, height: 30)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: – Sheet Presentation

    private func presentCreate() {
        draftProfile = AgentProfile(
            name: "New Agent",
            role: .custom,
            command: "",
            avatarKind: .initials
        )
        isSheetPresented = true
    }

    private func presentEdit(_ profile: AgentProfile) {
        draftProfile = profile
        isSheetPresented = true
    }

    private func presentDuplicate(_ profile: AgentProfile) {
        let copy = AgentProfile(
            id: UUID(),
            name: "\(profile.name) Copy",
            role: profile.role,
            command: profile.command,
            defaultPromptTemplate: profile.defaultPromptTemplate,
            commandArgsTemplate: profile.commandArgsTemplate,
            systemInstructions: profile.systemInstructions,
            cadenceDays: profile.cadenceDays,
            avatarKind: profile.avatarKind,
            canExecuteCode: profile.canExecuteCode,
            shouldClaimIssue: profile.shouldClaimIssue,
            shouldCloseIssue: profile.shouldCloseIssue,
            shouldRequestHumanReview: profile.shouldRequestHumanReview,
            isBuiltIn: false
        )
        draftProfile = copy
        isSheetPresented = true
    }
}

// MARK: – Edit Sheet

struct AgentProfileEditSheet: View {
    let profile: AgentProfile
    let onSave: (AgentProfile) -> Void
    let onCancel: () -> Void

    @State private var draft: AgentProfile
    @State private var cadenceTarget: CadenceTarget

    init(profile: AgentProfile, onSave: @escaping (AgentProfile) -> Void, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: profile)
        _cadenceTarget = State(initialValue: CadenceTarget.from(days: profile.cadenceDays))
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    basicInfoSection
                    commandSection
                    promptsSection
                    capabilitiesSection
                    recurringSection
                    Spacer(minLength: 24)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WorkstationTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(WorkstationTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.cadenceDays = cadenceTarget.days
                        onSave(draft)
                    }
                    .foregroundStyle(isValid ? WorkstationTheme.accent : WorkstationTheme.textDisabled)
                    .disabled(!isValid)
                }
            }
            .navigationTitle(draft.id == profile.id && !profile.isBuiltIn ? "Edit Agent" : "New Agent")
        }
    }

    // MARK: – Sections

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Basic Info")

            VStack(alignment: .leading, spacing: 8) {
                formLabel("Name")
                formTextField(text: $draft.name, placeholder: "Agent name")
            }

            VStack(alignment: .leading, spacing: 8) {
                formLabel("Role")
                Picker("Role", selection: $draft.role) {
                    ForEach(AgentRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
            }

            VStack(alignment: .leading, spacing: 8) {
                formLabel("Avatar")
                Picker("Avatar", selection: $draft.avatarKind) {
                    ForEach(AgentAvatarKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue.capitalized).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
            }
        }
    }

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Command")

            VStack(alignment: .leading, spacing: 8) {
                formLabel("CLI Command")
                formTextField(text: $draft.command, placeholder: "e.g. claude")
            }

            VStack(alignment: .leading, spacing: 8) {
                formLabel("Arguments Template")
                formTextField(text: $draft.commandArgsTemplate, placeholder: "e.g. --dangerously-skip-permissions \"{{prompt}}\"")
            }
        }
    }

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Prompts")

            VStack(alignment: .leading, spacing: 8) {
                formLabel("Default Prompt Template")
                formTextEditor(text: $draft.defaultPromptTemplate, placeholder: "Enter prompt template...")
            }

            VStack(alignment: .leading, spacing: 8) {
                formLabel("System Instructions")
                formTextEditor(text: $draft.systemInstructions, placeholder: "Enter system instructions...")
            }
        }
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Capabilities")

            VStack(spacing: 10) {
                capabilityToggle(
                    title: "Can execute code",
                    isOn: $draft.canExecuteCode
                )
                capabilityToggle(
                    title: "Should claim issue",
                    isOn: $draft.shouldClaimIssue
                )
                capabilityToggle(
                    title: "Should close issue",
                    isOn: $draft.shouldCloseIssue
                )
                capabilityToggle(
                    title: "Should request human review",
                    isOn: $draft.shouldRequestHumanReview
                )
            }
        }
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recurring Scanner")

            HStack(spacing: 6) {
                Text("Cadence")
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .textCase(.uppercase)
                    .tracking(0.6)
                ForEach(CadenceTarget.allCases, id: \.self) { option in
                    cadenceChip(option: option, isSelected: option == cadenceTarget)
                }
                Spacer()
            }
        }
    }

    // MARK: – Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            .foregroundStyle(WorkstationTheme.textSubtle)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func formLabel(_ text: String) -> some View {
        Text(text)
            .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
            .foregroundStyle(WorkstationTheme.textSecondary)
    }

    private func formTextField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .font(WorkstationTheme.Fonts.body(13))
            .foregroundStyle(WorkstationTheme.textPrimary)
            .padding(8)
            .background(WorkstationTheme.cardAlt)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func formTextEditor(text: Binding<String>, placeholder: String) -> some View {
        TextEditor(text: text)
            .font(WorkstationTheme.Fonts.body(13))
            .foregroundStyle(WorkstationTheme.textPrimary)
            .frame(minHeight: 80)
            .padding(6)
            .background(WorkstationTheme.cardAlt)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func capabilityToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(WorkstationTheme.accent)
        }
        .padding(.vertical, 4)
    }

    private func cadenceChip(option: CadenceTarget, isSelected: Bool) -> some View {
        Button {
            cadenceTarget = option
        } label: {
            BadgeView(style: isSelected ? .accent : .surface, horizontalPadding: 10, verticalPadding: 5) {
                Text(cadenceShortLabel(option))
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
    }

    private func cadenceShortLabel(_ option: CadenceTarget) -> String {
        switch option {
        case .none: return "None"
        case .weekly: return "7d"
        case .monthly: return "30d"
        case .quarterly: return "90d"
        }
    }
}
