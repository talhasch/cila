import SwiftUI

@MainActor
final class PanelModel: ObservableObject {
    enum State: Equatable {
        case preview
        case loading
        case result(String)
        case error(String)
    }

    @Published var text = ""
    @Published var state = State.preview
    @Published var options = SettingsStore.shared.defaultOptions
    @Published var copied = false
    @Published var isHovering = false
    /// A picker menu is open; its window sits outside the panel, so hover alone misses it.
    @Published var isMenuOpen = false

    var preview: String {
        let flat = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return flat.count > 60 ? flat.prefix(60).trimmed + "…" : flat
    }
}

struct PanelActions {
    var improve: () -> Void
    var copy: () -> Void
    var close: () -> Void
    var optionsChanged: () -> Void
}

struct PanelView: View {
    @ObservedObject var model: PanelModel
    let actions: PanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
        }
        .padding(14)
        .frame(width: 400, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        // The panel never becomes key; render controls as active anyway so
        // prominent buttons keep their accent color.
        .environment(\.controlActiveState, .key)
        .onHover { model.isHovering = $0 }
        .onChange(of: model.options) { actions.optionsChanged() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
            Text("Cila").fontWeight(.semibold)
            Spacer()
            LanguagePicker(language: $model.options.targetLanguage, compact: true)
            TonePicker(tone: $model.options.tone, compact: true)
            Button(action: actions.close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .font(.callout)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .preview:
            Text(model.preview)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Spacer()
                Button("Skip", action: actions.close)
                Button("Improve", action: actions.improve)
                    .buttonStyle(.borderedProminent)
            }

        case .loading:
            Text(model.preview)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                ProgressView().controlSize(.small)
                Text("Improving…").foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: actions.close)
            }

        case .result(let improved):
            ScrollView {
                Text(improved)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Close", action: actions.close)
                Button(action: actions.copy) {
                    Label(model.copied ? "Copied" : "Copy",
                          systemImage: model.copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.copied)
            }

        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Close", action: actions.close)
                Button("Try Again", action: actions.improve)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
