import AppKit
import SwiftUI

/// Hosts the SwiftUI windows for this menu-bar-only app.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var setupWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var composerWindow: NSWindow?

    func showSetup(onComplete: @escaping () -> Void) {
        if let setupWindow, setupWindow.isVisible { return present(setupWindow) }
        let window = makeWindow(title: "Welcome to Cila", rootView: SetupView { [weak self] in
            self?.setupWindow?.close()
            self?.setupWindow = nil
            onComplete()
        })
        setupWindow = window
        present(window)
    }

    func showSettings() {
        if let settingsWindow, settingsWindow.isVisible { return present(settingsWindow) }
        // Recreated each time so unsaved edits from a previous session are discarded.
        let window = makeWindow(title: "Cila Settings", rootView: SettingsView())
        settingsWindow = window
        present(window)
    }

    /// Kept alive after closing so the draft survives until the app quits.
    func showComposer() {
        let window = composerWindow ?? makeWindow(title: "Improve Text", rootView: ComposerView(), resizable: true)
        composerWindow = window
        present(window)
    }

    private func makeWindow(title: String, rootView: some View, resizable: Bool = false) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = title
        window.styleMask = resizable ? [.titled, .closable, .resizable] : [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow) {
        // Accessory (menu bar) apps aren't brought forward by the cooperative
        // `activate()`, so force it and order the window front regardless.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
