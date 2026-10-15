import Foundation

/// LLM provider presets. All of them are reached through the same
/// OpenAI-compatible Chat Completions API; a preset only pre-fills the Base URL.
enum Provider: String, CaseIterable, Identifiable {
    case openAI, deepSeek, claude, openRouter, ollama, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .deepSeek: "DeepSeek"
        case .claude: "Claude"
        case .openRouter: "OpenRouter"
        case .ollama: "Ollama"
        case .custom: "Custom"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: "https://api.openai.com/v1"
        case .deepSeek: "https://api.deepseek.com/v1"
        case .claude: "https://api.anthropic.com/v1"
        case .openRouter: "https://openrouter.ai/api/v1"
        case .ollama: "http://localhost:11434/v1"
        case .custom: ""
        }
    }

    /// Local or self-hosted servers often run without a key.
    var requiresAPIKey: Bool {
        switch self {
        case .ollama, .custom: false
        default: true
        }
    }
}

struct LLMConfig: Equatable {
    var provider: Provider = .openAI
    var baseURL: String = Provider.openAI.defaultBaseURL
    var apiKey: String = ""
    var model: String = ""

    var isValid: Bool {
        guard let url = URL(string: baseURL.trimmed),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host != nil
        else { return false }
        if model.trimmed.isEmpty { return false }
        if provider.requiresAPIKey && apiKey.trimmed.isEmpty { return false }
        return true
    }

    var normalized: LLMConfig {
        var copy = self
        copy.baseURL = baseURL.trimmed
        copy.apiKey = apiKey.trimmed
        copy.model = model.trimmed
        return copy
    }
}

extension StringProtocol {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
