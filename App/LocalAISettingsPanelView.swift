import SwiftUI

struct LocalAISettingsPanelView: View {
    @Bindable var appVM: AppViewModel

    private var settings: LocalAISettings {
        appVM.localAISettings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    enableToggle
                    Divider().overlay(WorkstationTheme.borderSoft)
                    providerSection
                    Divider().overlay(WorkstationTheme.borderSoft)
                    modelsSection
                    if settings.provider.requiresAPIKey {
                        Divider().overlay(WorkstationTheme.borderSoft)
                        apiKeySection
                    }
                    Divider().overlay(WorkstationTheme.borderSoft)
                    connectionSection
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
            Text("Local AI")
                .font(WorkstationTheme.Fonts.display(22, weight: .bold))
                .foregroundStyle(WorkstationTheme.textPrimary)
            Text("Configure the AI provider used by Copilot and assisted actions.")
                .font(WorkstationTheme.Fonts.body(13))
                .foregroundStyle(WorkstationTheme.textSecondary)
        }
    }

    private var enableToggle: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .foregroundStyle(WorkstationTheme.textSecondary)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Local AI")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
                Text("Use a local or remote AI model for Copilot and assisted actions")
                    .font(WorkstationTheme.Fonts.body(12))
                    .foregroundStyle(WorkstationTheme.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: binding(
                get: { settings.isEnabled },
                set: { appVM.setLocalAIEnabled($0) }
            ))
            .toggleStyle(.switch)
            .tint(WorkstationTheme.accent)
            .labelsHidden()
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("Provider")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(WorkstationTheme.accent)
                    Text("OpenCode Go")
                        .font(WorkstationTheme.Fonts.body(13, weight: .bold))
                        .foregroundStyle(WorkstationTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(WorkstationTheme.cardAlt)
                .cornerRadius(WorkstationTheme.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                )

                Spacer()
            }

            providerInfoBanner
        }
        .opacity(settings.isEnabled ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: settings.isEnabled)
    }

    @ViewBuilder
    private var providerInfoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
            Text("OpenCode Go utilizes a high-performance OpenAI-compatible gateway. Stored API keys are maintained securely in your local preferences.")
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(WorkstationTheme.textMuted)
                .lineSpacing(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WorkstationTheme.cardAlt)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "cube.box")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("Models")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 10) {
                modelField(
                    label: "Base URL",
                    placeholder: LocalAISettings.defaultBaseURL,
                    text: binding(
                        get: { settings.baseURL },
                        set: { appVM.setLocalAIBaseURL($0) }
                    )
                )

                HStack(spacing: 12) {
                    modelField(
                        label: "Fast Model",
                        subtitle: "Lighter prompts: drafting, suggestions",
                        placeholder: LocalAISettings.defaultFastModel,
                        text: binding(
                            get: { settings.fastModel },
                            set: { appVM.setLocalAIFastModel($0) }
                        )
                    )

                    modelField(
                        label: "Strong Model",
                        subtitle: "Deeper prompts: analysis, reasoning",
                        placeholder: LocalAISettings.defaultStrongModel,
                        text: binding(
                            get: { settings.strongModel },
                            set: { appVM.setLocalAIStrongModel($0) }
                        )
                    )
                }
            }
        }
        .opacity(settings.isEnabled ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: settings.isEnabled)
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("API Key")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            Text("Stored securely in this app's local preferences. Never sent outside your machine.")
                .font(WorkstationTheme.Fonts.body(11))
                .foregroundStyle(WorkstationTheme.textMuted)
                .lineSpacing(2)

            SecureField("Paste your API key", text: binding(
                get: { settings.apiKey },
                set: { appVM.setLocalAIAPIKey($0) }
            ))
            .font(WorkstationTheme.Fonts.body(13))
            .foregroundStyle(WorkstationTheme.textPrimary)
            .padding(8)
            .background(WorkstationTheme.cardAlt)
            .overlay(
                RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                    .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))

            let defaultKey = LocalAISettings.loadDefaultAPIKey()
            if !defaultKey.isEmpty && settings.apiKey == defaultKey {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10))
                        .foregroundStyle(WorkstationTheme.accent)
                    Text("Auto-discovered API key from your local OpenCode CLI auth config!")
                        .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                        .foregroundStyle(WorkstationTheme.accent)
                }
                .padding(.top, 2)
            }
        }
        .opacity(settings.isEnabled ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: settings.isEnabled)
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(WorkstationTheme.textSecondary)
                    .font(.system(size: 14))
                Text("Connection")
                    .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textPrimary)
            }

            HStack(spacing: 10) {
                Button {
                    appVM.testLocalAIConnection()
                } label: {
                    HStack(spacing: 6) {
                        if appVM.isTestingLocalAIConnection {
                            ProgressView()
                                .controlSize(.small)
                                .tint(WorkstationTheme.background)
                        } else {
                            Image(systemName: "bolt.horizontal")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(appVM.isTestingLocalAIConnection ? "Testing..." : "Test Connection")
                            .font(WorkstationTheme.Fonts.body(13, weight: .semibold))
                    }
                }
                .buttonStyle(WorkstationPrimaryButtonStyle())
                .disabled(appVM.isTestingLocalAIConnection || !settings.isEnabled)

                if appVM.isTestingLocalAIConnection {
                    ProgressView()
                        .controlSize(.small)
                        .tint(WorkstationTheme.accent)
                }

                Spacer()
            }

            if let message = appVM.localAIConnectionMessage {
                connectionResultBanner(message: message, isError: appVM.localAIConnectionMessageIsError)
            } else if !settings.isEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                    Text("AI assistance is disabled. Turn it on above to use Copilot-backed actions.")
                        .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(WorkstationTheme.cardAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous)
                        .stroke(WorkstationTheme.borderSoft, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.small, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func connectionResultBanner(message: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isError ? WorkstationTheme.red : WorkstationTheme.green)
                .padding(.top, 2)
            Text(message)
                .font(WorkstationTheme.Fonts.body(11, weight: .medium))
                .foregroundStyle(isError ? WorkstationTheme.red : WorkstationTheme.green)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isError ? WorkstationTheme.redBg : WorkstationTheme.greenBg)
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous)
                .stroke(isError ? WorkstationTheme.redBorder : WorkstationTheme.greenBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.medium, style: .continuous))
    }

    private func modelField(
        label: String,
        subtitle: String? = nil,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(WorkstationTheme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(WorkstationTheme.textSecondary)
                if let subtitle {
                    Text("— \(subtitle)")
                        .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                        .foregroundStyle(WorkstationTheme.textMuted)
                }
            }

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
    }

    private func binding<Value>(
        get: @escaping @Sendable () -> Value,
        set: @escaping @Sendable (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: get, set: set)
    }
}