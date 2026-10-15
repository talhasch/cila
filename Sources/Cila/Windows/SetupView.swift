import SwiftUI

/// First-run wizard: step 1 (provider) is required, step 2 (language) is optional.
struct SetupView: View {
    let onFinish: () -> Void

    @ObservedObject private var settings = SettingsStore.shared
    @State private var step = Step.provider
    @State private var config = SettingsStore.shared.config
    @State private var language = SettingsStore.shared.targetLanguage
    @State private var saveError: String?

    private enum Step { case provider, language }

    var body: some View {
        VStack(spacing: 0) {
            header
            Form {
                switch step {
                case .provider:
                    ProviderSection(config: $config)
                case .language:
                    Section {
                        LanguagePicker(language: $language)
                    } footer: {
                        Text("Copied text will be improved and translated into this language. Leave it as None to improve text in its original language. You can change this later in Settings.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            footer
        }
        .frame(width: 520, height: 440)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step == .provider ? "Step 1 of 2 · Provider" : "Step 2 of 2 · Target Language (optional)")
                .font(.headline)
            Text(step == .provider
                 ? "Cila sends text to the model only when you click Improve. Any OpenAI-compatible API works."
                 : "Optionally pick a language to translate your text into.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal, .top], 20)
    }

    private var footer: some View {
        HStack {
            if let saveError {
                Text(saveError).foregroundStyle(.red).font(.callout)
            }
            Spacer()
            switch step {
            case .provider:
                Button("Continue", action: saveProvider)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!config.isValid)
            case .language:
                Button("Back") { step = .provider }
                Button("Skip") {
                    settings.targetLanguage = nil
                    onFinish()
                }
                Button("Done") {
                    settings.targetLanguage = language
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }

    private func saveProvider() {
        do {
            try settings.saveProvider(config)
            saveError = nil
            step = .language
        } catch {
            saveError = error.localizedDescription
        }
    }
}
