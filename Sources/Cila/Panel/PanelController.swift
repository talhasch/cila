import AppKit
import Combine
import SwiftUI

/// Shows copied text below the menu bar and runs the improve request on demand.
@MainActor
final class PanelController {
    private enum Timing {
        static let preview: Duration = .seconds(6)
        static let result: Duration = .seconds(30)
        static let afterCopy: Duration = .milliseconds(700)
        static let hoverRecheck: Duration = .seconds(2)
    }

    private let model = PanelModel()
    private lazy var panel = makePanel()
    private var hostingView: NSView!
    private var requestTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Shows (or replaces) the panel content with newly copied text.
    func show(_ text: String) {
        requestTask?.cancel()
        model.text = text
        model.options = SettingsStore.shared.defaultOptions
        model.state = .preview
        model.copied = false

        if !panel.isVisible {
            position(on: screenWithMouse())
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        }
        scheduleDismiss(after: Timing.preview)
    }

    func hide() {
        requestTask?.cancel()
        dismissTask?.cancel()
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; panel.animator().alphaValue = 0 }) {
            MainActor.assumeIsolated { self.panel.orderOut(nil) }
        }
    }

    // MARK: - Actions

    private func improve() {
        dismissTask?.cancel()
        requestTask?.cancel()
        model.state = .loading

        let text = model.text
        let options = model.options
        requestTask = Task {
            do {
                let improved = try await Improver.improve(text, options: options)
                try Task.checkCancellation()
                model.state = .result(improved)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                model.state = .error(error.localizedDescription)
            }
            scheduleDismiss(after: Timing.result)
        }
    }

    /// Re-runs the request when the language or tone changes after Improve.
    private func optionsChanged() {
        if model.state == .preview {
            scheduleDismiss(after: Timing.preview)
        } else {
            improve()
        }
    }

    private func copy() {
        guard case .result(let improved) = model.state else { return }
        Improver.copy(improved)
        model.copied = true
        scheduleDismiss(after: Timing.afterCopy, evenIfHovering: true)
    }

    // MARK: - Auto-dismiss

    private func scheduleDismiss(after delay: Duration, evenIfHovering: Bool = false) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            if (model.isHovering || model.isMenuOpen) && !evenIfHovering {
                scheduleDismiss(after: Timing.hoverRecheck)
            } else {
                hide()
            }
        }
    }

    // MARK: - Window

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel()

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true

        let actions = PanelActions(
            improve: { [weak self] in self?.improve() },
            copy: { [weak self] in self?.copy() },
            close: { [weak self] in self?.hide() },
            optionsChanged: { [weak self] in self?.optionsChanged() }
        )
        let hosting = FirstMouseHostingView(rootView: PanelView(model: model, actions: actions))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
        hostingView = hosting

        let center = NotificationCenter.default
        center.publisher(for: NSMenu.didBeginTrackingNotification)
            .sink { [weak self] _ in self?.model.isMenuOpen = true }
            .store(in: &cancellables)
        center.publisher(for: NSMenu.didEndTrackingNotification)
            .sink { [weak self] _ in self?.model.isMenuOpen = false }
            .store(in: &cancellables)

        // Re-fit the panel whenever its content changes.
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.panel.isVisible else { return }
                self.position(on: self.panel.screen)
            }
            .store(in: &cancellables)
        return panel
    }

    /// Centers the panel horizontally just below the menu bar.
    private func position(on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else { return }
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 8)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.invalidateShadow()
    }

    private func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
