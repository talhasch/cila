import Foundation

/// A single OpenAI-compatible Chat Completions client used for every provider.
struct LLMClient {
    let config: LLMConfig
    var timeout: TimeInterval = 60

    func complete(system: String, user: String) async throws -> String {
        guard var url = URL(string: config.baseURL.trimmed) else { throw LLMError.invalidURL }
        url.append(path: "chat/completions")

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Cila", forHTTPHeaderField: "X-Title")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: config.model,
            messages: [.init(role: "system", content: system), .init(role: "user", content: user)]
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw LLMError(urlError: error)
        }

        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError(status: http.statusCode, serverMessage: Self.errorMessage(in: data))
        }

        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw LLMError.invalidResponse
        }
        let text = decoded.choices.first?.message.content?.trimmed ?? ""
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }

    /// Sends a tiny request to verify the URL, key and model.
    func testConnection() async throws {
        var client = self
        client.timeout = 30
        _ = try await client.complete(system: "Reply with the single word OK.", user: "ping")
    }

    private static func errorMessage(in data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        return (json["error"] as? String) ?? (json["message"] as? String)
    }
}

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}

enum LLMError: LocalizedError, Equatable {
    case invalidURL
    case noConnection
    case cannotReachServer
    case timeout
    case invalidAPIKey
    case forbidden
    case insufficientCredits
    case notFound
    case rateLimited
    case server(Int)
    case rejected(String?)
    case invalidResponse
    case emptyResponse
    case other(String)

    init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            self = .noConnection
        case .timedOut:
            self = .timeout
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .secureConnectionFailed, .appTransportSecurityRequiresSecureConnection:
            self = .cannotReachServer
        case .badURL, .unsupportedURL:
            self = .invalidURL
        default:
            self = .other(urlError.localizedDescription)
        }
    }

    init(status: Int, serverMessage: String?) {
        switch status {
        case 401: self = .invalidAPIKey
        case 402: self = .insufficientCredits
        case 403: self = .forbidden
        case 404: self = .notFound
        case 429: self = .rateLimited
        case 500...: self = .server(status)
        default: self = .rejected(serverMessage)
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The Base URL is invalid."
        case .noConnection:
            "No internet connection."
        case .cannotReachServer:
            "Couldn't reach the server. Check the Base URL and make sure the service is running."
        case .timeout:
            "The request timed out. Please try again."
        case .invalidAPIKey:
            "Invalid API key. Check it in Settings."
        case .forbidden:
            "Access denied. Your API key may not have access to this model."
        case .insufficientCredits:
            "Your account has insufficient balance or credits."
        case .notFound:
            "Model or endpoint not found. Check the Base URL and model name."
        case .rateLimited:
            "Rate limit or quota exceeded. Wait a moment and try again."
        case .server(let code):
            "The provider is having problems (error \(code)). Try again later."
        case .rejected(let message):
            message.map { "The request was rejected: \($0)" } ?? "The request was rejected by the provider."
        case .invalidResponse:
            "Received an unexpected response from the server."
        case .emptyResponse:
            "The model returned an empty response."
        case .other(let message):
            message
        }
    }
}
