import Foundation

// MARK: - AI Message (shared between service layer)

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
        cfg.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Streaming Chat

    /// Streams assistant reply tokens via AsyncThrowingStream.
    /// Each yielded value is an incremental text chunk.
    func stream(
        messages: [AIMessage],
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    switch config.provider {
                    case .anthropic:
                        try await streamAnthropic(
                            messages: messages,
                            systemPrompt: systemPrompt,
                            continuation: continuation
                        )
                    case .openAI, .unknown:
                        try await streamOpenAI(
                            messages: messages,
                            systemPrompt: systemPrompt,
                            continuation: continuation
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - OpenAI-compatible streaming

    private func streamOpenAI(
        messages: [AIMessage],
        systemPrompt: String?,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let url = config.baseURL.appendingPathComponent("chat/completions")

        var allMessages: [[String: Any]] = []
        if let sys = systemPrompt {
            allMessages.append(["role": "system", "content": sys])
        }
        allMessages += messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": config.modelName,
            "messages": allMessages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 1024
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            var errBody = ""
            for try await line in bytes.lines { errBody += line }
            throw AIError.requestFailed(http.statusCode, errBody)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))
            if data == "[DONE]" { break }
            guard
                let json = try? JSONSerialization.jsonObject(
                    with: Data(data.utf8)) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let delta = choices.first?["delta"] as? [String: Any],
                let text = delta["content"] as? String,
                !text.isEmpty
            else { continue }
            continuation.yield(text)
        }
    }

    // MARK: - Anthropic streaming

    private func streamAnthropic(
        messages: [AIMessage],
        systemPrompt: String?,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let url = config.baseURL.appendingPathComponent("messages")

        var body: [String: Any] = [
            "model": config.modelName,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true,
            "max_tokens": 1024
        ]
        if let sys = systemPrompt { body["system"] = sys }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            var errBody = ""
            for try await line in bytes.lines { errBody += line }
            throw AIError.requestFailed(http.statusCode, errBody)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))
            guard
                let json = try? JSONSerialization.jsonObject(
                    with: Data(data.utf8)) as? [String: Any],
                let type_ = json["type"] as? String,
                type_ == "content_block_delta",
                let delta = json["delta"] as? [String: Any],
                let text = delta["text"] as? String,
                !text.isEmpty
            else { continue }
            continuation.yield(text)
        }
    }

    // MARK: - Shared Instance

    static let shared: AIService? = {
        guard let config = AIConfig.load() else { return nil }
        return AIService(config: config)
    }()
}
