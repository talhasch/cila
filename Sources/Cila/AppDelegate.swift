import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pauseItem: NSMenuItem!
    private var cancellables = Set<AnyCancellable>()
    private let state = AppState.shared
    private let settings = SettingsStore.shared
    private let watcher = ClipboardWatcher()
    private let panel = PanelController()
    private let toast = Toast()
    private var pauseHotKey: GlobalHotKey?
    private var composerHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()
        setUpStatusItem()
        pauseHotKey = GlobalHotKey(keyCode: kVK_ANSI_P, modifiers: controlKey | optionKey) { [weak self] in
            self?.togglePause(showToast: true)
        }
        composerHotKey = GlobalHotKey(keyCode: kVK_ANSI_N, modifiers: controlKey | optionKey) { [weak self] in
            self?.openComposer()
        }
        state.$isPaused
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &cancellables)

        if !settings.isProviderConfigured {
            WindowManager.shared.showSetup { [weak self] in self?.startIfReady() }
        } else {
            startIfReady()
        }
    }

    /// Clipboard watching starts only once the provider step is complete.
    private func startIfReady() {
        guard settings.isProviderConfigured else { return }
        watcher.onCopy = { [weak self] text in self?.panel.show(text) }
        watcher.start()
    }

    // MARK: - Main menu

    /// Accessory apps have no visible main menu, but text fields still need one
    /// for ⌘C / ⌘V / ⌘A etc. to work.
    private func setUpMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        appItem.submenu?.addItem(withTitle: "Quit Cila", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        windowItem.submenu = NSMenu(title: "Window")
        windowItem.submenu?.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        pauseItem = NSMenuItem(title: "", action: #selector(togglePauseFromMenu), keyEquivalent: "p")
        pauseItem.keyEquivalentModifierMask = [.control, .option]
        pauseItem.target = self
        menu.addItem(pauseItem)

        let composerItem = NSMenuItem(title: "Improve Text…", action: #selector(openComposer), keyEquivalent: "n")
        composerItem.keyEquivalentModifierMask = [.control, .option]
        composerItem.target = self
        menu.addItem(composerItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Cila", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show shortcuts as written (e.g. ⌃⌥P), not remapped to the keyboard layout.
        for item in menu.items { item.allowsAutomaticKeyEquivalentLocalization = false }
        statusItem.menu = menu
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        let symbol = state.isPaused ? "pause.circle" : "wand.and.stars"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Cila")
        image?.isTemplate = true
        statusItem.button?.image = image
        pauseItem.title = state.isPaused ? "Resume" : "Pause"
    }

    // MARK: - Actions

    @objc private func togglePauseFromMenu() {
        togglePause(showToast: false)
    }

    private func togglePause(showToast: Bool) {
        state.isPaused.toggle()
        if state.isPaused { panel.hide() }
        if showToast {
            toast.show(state.isPaused ? "Cila Paused" : "Cila Resumed",
                       systemImage: state.isPaused ? "pause.circle" : "wand.and.stars")
        }
    }

    @objc private func openComposer() {
        if settings.isProviderConfigured {
            WindowManager.shared.showComposer()
        } else {
            WindowManager.shared.showSetup { [weak self] in self?.startIfReady() }
        }
    }

    @objc private func openSettings() {
        if settings.isProviderConfigured {
            WindowManager.shared.showSettings()
        } else {
            WindowManager.shared.showSetup { [weak self] in self?.startIfReady() }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
