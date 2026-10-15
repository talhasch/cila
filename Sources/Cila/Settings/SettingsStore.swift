import Foundation

/// Persists settings: API key in a private file (see `CredentialStore`),
/// everything else in UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published private(set) var config: LLMConfig
    @Published private(set) var isProviderConfigured: Bool

    /// `nil` means "improve in the original language".
    @Published var targetLanguage: String? {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }

    @Published var tone: Tone {
        didSet { defaults.set(tone.rawValue, forKey: Keys.tone) }
    }

    /// Defaults for each new copy or composer session.
    var defaultOptions: ImproveOptions {
        ImproveOptions(targetLanguage: targetLanguage, tone: tone)
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let provider = "provider"
        static let baseURL = "baseURL"
        static let model = "model"
        static let targetLanguage = "targetLanguage"
        static let providerConfigured = "providerConfigured"
        static let tone = "tone"
    }

    private init() {
        let provider = Provider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .openAI
        let config = LLMConfig(
            provider: provider,
            baseURL: defaults.string(forKey: Keys.baseURL) ?? provider.defaultBaseURL,
            apiKey: CredentialStore.readAPIKey() ?? "",
            model: defaults.string(forKey: Keys.model) ?? ""
        )
        self.config = config
        targetLanguage = defaults.string(forKey: Keys.targetLanguage)
        tone = Tone(rawValue: defaults.string(forKey: Keys.tone) ?? "") ?? .original
        // A missing key (e.g. one that only existed in the old Keychain storage)
        // sends the user back through setup with the other fields pre-filled.
        isProviderConfigured = defaults.bool(forKey: Keys.providerConfigured) && config.isValid
    }

    func saveProvider(_ newConfig: LLMConfig) throws {
        let newConfig = newConfig.normalized
        try CredentialStore.saveAPIKey(newConfig.apiKey)
        defaults.set(newConfig.provider.rawValue, forKey: Keys.provider)
        defaults.set(newConfig.baseURL, forKey: Keys.baseURL)
        defaults.set(newConfig.model, forKey: Keys.model)
        defaults.set(true, forKey: Keys.providerConfigured)
        config = newConfig
        isProviderConfigured = true
    }
}
