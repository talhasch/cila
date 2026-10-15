import AppKit
import SwiftUI

/// Brief non-activating notice below the menu bar (e.g. "Cila Paused").
@MainActor
final class Toast {
    private final class Model: ObservableObject {
        @Published var message = ""
        @Published var systemImage = "wand.and.stars"
    }

    private struct ToastView: View {
        @ObservedObject var model: Model

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: model.systemImage)
                Text(model.message).fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .fixedSize()
        }
    }

    private let model = Model()
    private lazy var hostingView = NSHostingView(rootView: ToastView(model: model))
    private lazy var panel = makePanel()
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, systemImage: String) {
        let panel = self.panel  // attach the hosting view to its window before measuring
        model.message = message
        model.systemImage = systemImage

        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 8,
                                  width: size.width, height: size.height), display: true)
        }
        panel.invalidateShadow()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel.animator().alphaValue = 0 }) {
                MainActor.assumeIsolated { panel.orderOut(nil) }
            }
        }
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel()
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: background.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
        return panel
    }
}
