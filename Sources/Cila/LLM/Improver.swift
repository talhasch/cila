import AppKit

/// The improve request and clipboard copy shared by the panel and the composer.
@MainActor
enum Improver {
    static func improve(_ text: String, options: ImproveOptions) async throws -> String {
        let client = LLMClient(config: SettingsStore.shared.config)
        return try await client.complete(system: Prompt.system(for: options), user: text)
    }

    /// Copies `text`, marked so the clipboard watcher doesn't offer it again.
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string, ClipboardWatcher.ownType], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("", forType: ClipboardWatcher.ownType)
    }
}
