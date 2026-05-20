import SwiftUI

struct LocalAISettingsPanelView: View {
    @Bindable var appVM: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            toggleRow
            fieldGrid
            connectionSection
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Local AI")
                .font(WorkstationTheme.Fonts.display(16, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)

            Text("Configure Ollama so the app can use a local model for assisted actions.")
                .font(WorkstationTheme.Fonts.body(12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
        }
    }

    private var toggleRow: some View {
        Toggle(
            "Enable Local AI",
            isOn: binding(
                get: { appVM.localAISettings.isEnabled },
                set: { appVM.setLocalAIEnabled($0) }
            )
        )
        .toggleStyle(.switch)
    }

    private var fieldGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                settingField(
                    title: "Provider",
                    control: providerPicker
                )

                settingField(
                    title: "Base URL",
                    subtitle: "Ollama listens here.",
                    control: baseURLField
                )
            }

            GridRow {
                settingField(
                    title: "Fast Model",
                    subtitle: "Used for lighter prompts.",
                    control: fastModelField
                )

                settingField(
                    title: "Strong Model",
                    subtitle: "Used for deeper prompts.",
                    control: strongModelField
                )
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    appVM.testLocalAIConnection()
                } label: {
                    Label(
                        appVM.isTestingLocalAIConnection ? "Testing..." : "Test Connection",
                        systemImage: appVM.isTestingLocalAIConnection ? "hourglass" : "network"
                    )
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(appVM.isTestingLocalAIConnection)

                if appVM.isTestingLocalAIConnection {
                    ProgressView()
                        .controlSize(.small)
                        .tint(WorkstationTheme.accent)
                }
            }

            if let message = appVM.localAIConnectionMessage {
                Text(message)
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(appVM.localAIConnectionMessageIsError ? WorkstationTheme.red : WorkstationTheme.green)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !appVM.localAISettings.isEnabled {
                Text("Local AI is disabled. Turn it on to use Ollama-backed assistance.")
                    .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func providerPicker() -> some View {
        Picker(
            "Provider",
            selection: binding(
                get: { appVM.localAISettings.provider },
                set: { appVM.setLocalAIProvider($0) }
            )
        ) {
            ForEach(LocalAIProvider.allCases) { provider in
                Text(provider.displayName).tag(provider)
            }
        }
        .pickerStyle(.menu)
    }

    private func baseURLField() -> some View {
        TextField(
            "http://localhost:11434",
            text: binding(
                get: { appVM.localAISettings.baseURL },
                set: { appVM.setLocalAIBaseURL($0) }
            )
        )
        .textFieldStyle(.roundedBorder)
    }

    private func fastModelField() -> some View {
        TextField(
            "qwen2.5-coder:3b",
            text: binding(
                get: { appVM.localAISettings.fastModel },
                set: { appVM.setLocalAIFastModel($0) }
            )
        )
        .textFieldStyle(.roundedBorder)
    }

    private func strongModelField() -> some View {
        TextField(
            "qwen2.5-coder:7b",
            text: binding(
                get: { appVM.localAISettings.strongModel },
                set: { appVM.setLocalAIStrongModel($0) }
            )
        )
        .textFieldStyle(.roundedBorder)
    }

    private func settingField<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textPrimary)

            control()

            if let subtitle {
                Text(subtitle)
                    .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .lineSpacing(1.5)
            }
        }
    }

    private func binding<Value>(
        get: @escaping @Sendable () -> Value,
        set: @escaping @Sendable (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: get, set: set)
    }
}
