import Foundation

// MARK: - AI Message

struct AIMessage: Codable {
    let role: String    // "user" | "assistant" | "system"
    let content: String
}

// MARK: - AI Service

actor AIService {

    // MARK: - Types

    enum AIError: Error, LocalizedError {
        case notConfigured
        case requestFailed(Int, String)
        case decodingFailed(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "AI not configured. Add .env with AI_BASE_URL, AI_API_KEY, AI_MODEL_NAME."
            case .requestFailed(let code, let body):
                return "Request failed (\(code)): \(body)"
            case .decodingFailed(let detail):
                return "Decode error: \(detail)"
            case .emptyResponse:
                return "Empty response from AI."
            }
        }
    }

    // MARK: - Properties

    private let config: AIConfig
    private let session: URLSession

    // MARK: - Init

    init(config: AIConfig) {
        self.config = config
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Chat

    /// Send a list of messages and return the assistant's reply string.
    func chat(messages: [AIMessage], systemPrompt: String? = nil) async throws -> String {
        switch config.provider {
        case .anthropic:
            return try await chatAnthropic(messages: messages, systemPrompt: systemPrompt)
        case .openAI, .unknown:
            return try await chatOpenAI(messages: messages, systemPrompt: systemPrompt)
        }
    }

    /// Convenience: single user message.
    func ask(_ prompt: String, systemPrompt: String? = nil) async throws -> String {
        try await chat(
            messages: [AIMessage(role: "user", content: prompt)],
            systemPrompt: systemPrompt
        )
    }

    // MARK: - OpenAI-compatible

    private func chatOpenAI(messages: [AIMessage], systemPrompt: String?) async throws -> String {
        let url = config.baseURL.appendingPathComponent("chat/completions")

        var allMessages: [[String: String]] = []
        if let sys = systemPrompt {
            allMessages.append(["role": "system", "content": sys])
        }
        allMessages += messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": config.modelName,
            "messages": allMessages,
            "temperature": 0.7,
            "max_tokens": 1024
        ]

        let data = try await post(url: url, body: body, authHeader: "Bearer \(config.apiKey)")

        // Decode
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            // Surface API error if present
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let msg = error["message"] as? String {
                throw AIError.requestFailed(0, msg)
            }
            throw AIError.decodingFailed(String(data: data, encoding: .utf8) ?? "")
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.emptyResponse }
        return trimmed
    }

    // MARK: - Anthropic

    private func chatAnthropic(messages: [AIMessage], systemPrompt: String?) async throws -> String {
        let url = config.baseURL.appendingPathComponent("messages")

        let anthropicMessages = messages.map { ["role": $0.role, "content": $0.content] }

        var body: [String: Any] = [
            "model": config.modelName,
            "messages": anthropicMessages,
            "max_tokens": 1024
        ]
        if let sys = systemPrompt {
            body["system"] = sys
        }

        // Anthropic uses x-api-key header, not Bearer
        let data = try await post(
            url: url,
            body: body,
            authHeader: config.apiKey,
            extraHeaders: [
                "anthropic-version": "2023-06-01",
                "x-api-key": config.apiKey
            ],
            authHeaderName: nil   // skip Authorization, using x-api-key instead
        )

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let first = content.first,
            let text = first["text"] as? String
        else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errMsg = json["error"] as? [String: Any],
               let msg = errMsg["message"] as? String {
                throw AIError.requestFailed(0, msg)
            }
            throw AIError.decodingFailed(String(data: data, encoding: .utf8) ?? "")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.emptyResponse }
        return trimmed
    }

    // MARK: - HTTP Helper

    private func post(
        url: URL,
        body: [String: Any],
        authHeader: String,
        extraHeaders: [String: String] = [:],
        authHeaderName: String? = "Authorization"
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let headerName = authHeaderName {
            request.setValue(authHeader, forHTTPHeaderField: headerName)
        }
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIError.requestFailed(http.statusCode, body)
        }

        return data
    }
}

// MARK: - Shared Instance

extension AIService {
    /// Lazily resolved shared instance. Re-evaluated on first access.
    static let shared: AIService? = {
        if let config = AIConfig.load() {
            return AIService(config: config)
        }
        return nil
    }()
}
