import SwiftUI

/// Provider fields shared by the setup and settings windows. Use inside a `Form`.
struct ProviderSection: View {
    @Binding var config: LLMConfig

    @State private var testState: TestState = .idle
    @State private var testTask: Task<Void, Never>?

    private enum TestState: Equatable {
        case idle, testing, success, failure(String)
    }

    var body: some View {
        Section {
            Picker("Provider", selection: $config.provider) {
                ForEach(Provider.allCases) { Text($0.displayName).tag($0) }
            }
            TextField("Base URL", text: $config.baseURL, prompt: Text("https://…"))
            SecureField("API Key", text: $config.apiKey,
                        prompt: Text(config.provider.requiresAPIKey ? "Required" : "Optional"))
            TextField("Model", text: $config.model, prompt: Text("Model name"))
        } footer: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Button("Test Connection", action: test)
                    .disabled(!config.isValid || testState == .testing)
                testStatus
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        .autocorrectionDisabled()
        .onChange(of: config.provider) { _, provider in
            config.baseURL = provider.defaultBaseURL
        }
        .onChange(of: config) {
            testTask?.cancel()
            testState = .idle
        }
        .onDisappear { testTask?.cancel() }
    }

    @ViewBuilder
    private var testStatus: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView().controlSize(.small)
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func test() {
        testTask?.cancel()
        testState = .testing
        let client = LLMClient(config: config.normalized)
        testTask = Task {
            do {
                try await client.testConnection()
                testState = .success
            } catch is CancellationError {
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}

struct LanguagePicker: View {
    @Binding var language: String?
    /// Compact pickers (panel, composer) hide the label and use a short "none" title.
    var compact = false

    var body: some View {
        Picker("Target Language", selection: $language) {
            Text(compact ? "No Translation" : "None (keep original language)").tag(String?.none)
            Divider()
            ForEach(Languages.all, id: \.self) { Text($0).tag(Optional($0)) }
        }
        .modifier(CompactPicker(enabled: compact, help: "Translate into"))
    }
}

struct TonePicker: View {
    @Binding var tone: Tone
    var compact = false

    var body: some View {
        Picker("Tone", selection: $tone) {
            Text(Tone.original.displayName).tag(Tone.original)
            Divider()
            ForEach(Tone.allCases.dropFirst()) { Text($0.displayName).tag($0) }
        }
        .modifier(CompactPicker(enabled: compact, help: "Tone"))
    }
}

private struct CompactPicker: ViewModifier {
    let enabled: Bool
    let help: String

    func body(content: Content) -> some View {
        if enabled {
            content
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
                .help(help)
        } else {
            content
        }
    }
}
