import Foundation

// MARK: - AI Config

struct AIConfig {
    let baseURL: URL
    let apiKey: String
    let modelName: String

    // MARK: - Provider Detection

    enum Provider {
        case openAI       // openai.com or compatible (Together, Groq, local, etc.)
        case anthropic    // anthropic.com
        case unknown
    }

    var provider: Provider {
        let host = baseURL.host ?? ""
        if host.contains("anthropic.com") { return .anthropic }
        if host.contains("openai.com")
            || host.contains("together.ai")
            || host.contains("groq.com")
            || host.contains("localhost")
            || host.contains("127.0.0.1") { return .openAI }
        // Fallback: if model name looks like Claude, treat as Anthropic
        if modelName.lowercased().hasPrefix("claude") { return .anthropic }
        return .openAI  // default to OpenAI-compatible
    }

    // MARK: - Load from .env

    static func load() -> AIConfig? {
        guard let env = loadEnvFile() else { return nil }

        guard
            let rawURL = env["AI_BASE_URL"], !rawURL.isEmpty,
            let url = URL(string: rawURL),
            let apiKey = env["AI_API_KEY"], !apiKey.isEmpty,
            !apiKey.hasPrefix("sk-your"),           // reject placeholder
            let model = env["AI_MODEL_NAME"], !model.isEmpty
        else { return nil }

        return AIConfig(baseURL: url, apiKey: apiKey, modelName: model)
    }

    // MARK: - .env Parser

    private static func loadEnvFile() -> [String: String]? {
        // Search order: CWD → executable dir → home dir → Bundle
        let fm = FileManager.default
        let candidates: [URL] = [
            URL(fileURLWithPath: fm.currentDirectoryPath)
                .appendingPathComponent(".env"),
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .appendingPathComponent(".env"),
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(".openinfo.env"),
            Bundle.main.bundleURL
                .appendingPathComponent(".env"),
        ].compactMap { $0 }

        for url in candidates {
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                return parse(env: contents)
            }
        }
        return nil
    }

    private static func parse(env: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in env.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comments and empty lines
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let eqRange = trimmed.range(of: "=") else { continue }
            let key = String(trimmed[..<eqRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[eqRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes: "value" or 'value'
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'")  && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }
}
