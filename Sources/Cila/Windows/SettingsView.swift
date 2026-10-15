import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            ProviderSettings()
                .tabItem { Label("Provider", systemImage: "network") }
        }
        .frame(width: 520, height: 410)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.set($0) }
                ))
                if launchAtLogin.needsApproval {
                    HStack {
                        Text("Approve Cila in System Settings to finish.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { launchAtLogin.openSystemSettings() }
                    }
                }
                if let message = launchAtLogin.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
            }

            Section {
                LanguagePicker(language: $settings.targetLanguage)
                TonePicker(tone: $settings.tone)
            } header: {
                Text("Defaults")
            } footer: {
                Text("Used for every new copy. You can change both for a single text from the panel or the Improve Text window. Text already in the target language is only improved.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
    }
}

// MARK: - Provider

private struct ProviderSettings: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var config = SettingsStore.shared.config
    @State private var saveState: SaveState = .idle

    private enum SaveState: Equatable { case idle, saved, failed(String) }

    var body: some View {
        Form {
            ProviderSection(config: $config)
            Section {
                HStack {
                    saveStatus
                    Spacer()
                    Button("Revert") { config = settings.config }
                        .disabled(config == settings.config)
                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!config.isValid || config.normalized == settings.config)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: config) { saveState = .idle }
    }

    @ViewBuilder
    private var saveStatus: some View {
        switch saveState {
        case .idle: EmptyView()
        case .saved: Label("Saved", systemImage: "checkmark").foregroundStyle(.secondary)
        case .failed(let message): Text(message).foregroundStyle(.red)
        }
    }

    private func save() {
        do {
            try settings.saveProvider(config)
            config = settings.config
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }
}
