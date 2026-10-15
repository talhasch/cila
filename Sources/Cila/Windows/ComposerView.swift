import SwiftUI

/// Free-form input: improve any text without copying it first.
struct ComposerView: View {
    @State private var input = ""
    @State private var options = SettingsStore.shared.defaultOptions
    @State private var phase = Phase.idle
    @State private var copied = false
    @State private var task: Task<Void, Never>?

    private enum Phase: Equatable {
        case idle, loading, result(String), error(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $input)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                .overlay(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Type or paste text to improve…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                LanguagePicker(language: $options.targetLanguage, compact: true)
                TonePicker(tone: $options.tone, compact: true)
                Spacer()
                if phase == .loading {
                    ProgressView().controlSize(.small)
                }
                Button("Improve", action: improve)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmed.isEmpty || phase == .loading)
            }

            Divider()

            output
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Spacer()
                Button(action: copy) {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(!hasResult)
            }
        }
        .padding(16)
        .frame(minWidth: 460, idealWidth: 540, minHeight: 420, idealHeight: 520)
        .onChange(of: options) {
            // Re-run when the language or tone changes after an attempt.
            if phase != .idle && !input.trimmed.isEmpty { improve() }
        }
    }

    @ViewBuilder
    private var output: some View {
        switch phase {
        case .idle:
            Text("The improved text will appear here.")
                .foregroundStyle(.tertiary)
        case .loading:
            Text("Improving…")
                .foregroundStyle(.secondary)
        case .result(let text):
            ScrollView {
                Text(text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private var hasResult: Bool {
        if case .result = phase { return true }
        return false
    }

    private func improve() {
        task?.cancel()
        phase = .loading
        copied = false
        let text = input
        let options = options
        task = Task {
            do {
                let improved = try await Improver.improve(text, options: options)
                try Task.checkCancellation()
                phase = .result(improved)
            } catch is CancellationError {
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func copy() {
        guard case .result(let text) = phase else { return }
        Improver.copy(text)
        copied = true
    }
}
