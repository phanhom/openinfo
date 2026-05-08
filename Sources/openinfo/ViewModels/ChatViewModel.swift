import SwiftUI
import Observation
import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date

    init(role: MessageRole, content: String = "") {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    enum MessageRole: String, Codable {
        case user
        case assistant
        case error
    }
}

extension ChatMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
    }
}

// MARK: - Chat ViewModel

@Observable
@MainActor
final class ChatViewModel {

    private static let maxContextTokens = 96_000
    private static let persistKey = "openinfo.chatHistory"
    private static let logFile: URL = {
        let logs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = logs.appendingPathComponent("openinfo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("error.log")
    }()

    private(set) var messages: [ChatMessage] = []
    private(set) var isThinking  = false
    private(set) var isStreaming = false
    var inputText: String = ""

    private let ai: AIService?
    private let searcher = WebSearchTool()

    var isAvailable: Bool { ai != nil }

    // MARK: - Init

    init() {
        self.ai = AIService.shared
        loadHistory()
    }

    // MARK: - Send

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking, !isStreaming else { return }
        guard let ai else {
            messages.append(ChatMessage(role: .error, content: "AI 未配置。\n请编辑 ~/.openinfo.env 设置以下变量：\nAI_BASE_URL=https://api.openai.com/v1\nAI_API_KEY=sk-your-key\nAI_MODEL_NAME=gpt-4o"))
            saveHistory()
            return
        }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        isThinking = true

        // 1. Web search
        let searchCtx = await searcher.searchContext(query: text)

        // 2. Build system prompt — minimal, no behavioral constraints
        var systemParts = ["Current time: \(currentDateString())"]
        if !searchCtx.isEmpty { systemParts.append(searchCtx) }
        let systemPrompt = systemParts.joined(separator: "\n")

        // 3. Attempt to stream with retry logic:
        //    - Context overflow: trim half, retry (up to 3 times)
        //    - Rate limit (429): exponential backoff, retry (up to 3 times)
        //    - Any other error: retry with backoff (up to 2 times)
        //    - All retries exhausted: fallback to single-message context
        //    - Final fallback: show contextual friendly error
        var currentMessages = buildContextWindow()
        var attempt = 0
        let maxAttempts = 5  // 3 context-trims + 1 single-msg + 1 final
        var assistantMsg: ChatMessage?
        var idx: Int?
        var lastError: Error?

        while attempt < maxAttempts {
            assistantMsg = nil
            idx = nil

            do {
                let stream = await ai.stream(messages: currentMessages, systemPrompt: systemPrompt)
                for try await chunk in stream {
                    if isThinking {
                        isThinking = false
                        isStreaming = true
                        assistantMsg = ChatMessage(role: .assistant, content: chunk)
                        messages.append(assistantMsg!)
                        idx = messages.count - 1
                    } else if let currentIdx = idx {
                        assistantMsg!.content += chunk
                        messages[currentIdx] = assistantMsg!
                    }
                }
                // Success
                break
            } catch {
                lastError = error
                logError(error, attempt: attempt, contextSize: currentMessages.count)

                attempt += 1

                if isContextLengthError(error) && attempt <= 3 {
                    // Trim half and retry
                    trimOlderMessages(keepFraction: 0.5)
                    currentMessages = buildContextWindow()
                    await backoff(for: 1.0)
                } else if isRateLimitError(error) && attempt <= 3 {
                    // 429: longer backoff
                    await backoff(for: Double(attempt) * 3.0)
                } else if attempt <= 3 {
                    // Generic retry with exponential backoff
                    await backoff(for: Double(attempt) * 2.0)
                } else if attempt == 4 {
                    // All retries exhausted — fallback to single message only
                    let lastUserMsg = AIMessage(role: "user", content: text)
                    currentMessages = [lastUserMsg]
                    await backoff(for: 2.0)
                } else {
                    // Final fallback — show friendly, contextual error
                    messages.append(ChatMessage(role: .assistant, content: friendlyMessage(for: lastError ?? NSError(domain: "openinfo", code: -1))))
                    break
                }
            }
        }

        isThinking  = false
        isStreaming = false
        saveHistory()
    }

    // MARK: - Backoff

    private func backoff(for seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // MARK: - Context Window Management

    private func buildContextWindow() -> [AIMessage] {
        let allAiMessages = messages.compactMap { msg -> AIMessage? in
            switch msg.role {
            case .user:      return AIMessage(role: "user",      content: msg.content)
            case .assistant: return AIMessage(role: "assistant", content: msg.content)
            case .error:     return nil
            }
        }

        let estimatedTokens = estimateTokens(allAiMessages)

        if estimatedTokens <= Self.maxContextTokens {
            return allAiMessages
        }

        let keepCount = max(2, allAiMessages.count / 2)
        return Array(allAiMessages.suffix(keepCount))
    }

    private func estimateTokens(_ messages: [AIMessage]) -> Int {
        var totalChars = 0
        for msg in messages {
            totalChars += msg.content.utf8.count
        }
        return (totalChars / 4) + (messages.count * 4)
    }

    private func trimOlderMessages(keepFraction: Double) {
        let keepCount = max(2, Int(Double(messages.count) * keepFraction))
        messages = Array(messages.suffix(keepCount))
    }

    // MARK: - Error Classification

    private func isContextLengthError(_ error: Error) -> Bool {
        let desc = error.localizedDescription.lowercased()
        return desc.contains("context") || desc.contains("token") ||
               desc.contains("length") || desc.contains("limit") ||
               desc.contains("maximum") || desc.contains("too long") ||
               desc.contains("reduce") || desc.contains("exceeds")
    }

    private func isRateLimitError(_ error: Error) -> Bool {
        let desc = error.localizedDescription.lowercased()
        return desc.contains("429") || desc.contains("rate limit") ||
               desc.contains("rate_limit") || desc.contains("too many requests") ||
               desc.contains("quota") || desc.contains("capacity")
    }

    private func isAuthError(_ error: Error) -> Bool {
        let desc = error.localizedDescription.lowercased()
        return desc.contains("401") || desc.contains("403") ||
               desc.contains("unauthorized") || desc.contains("invalid api key") ||
               desc.contains("invalid_api_key") || desc.contains("authentication") ||
               desc.contains("forbidden") || desc.contains("access denied")
    }

    private func isNetworkError(_ error: Error) -> Bool {
        let desc = error.localizedDescription.lowercased()
        return desc.contains("network") || desc.contains("connection") ||
               desc.contains("timeout") || desc.contains("dns") ||
               desc.contains("refused") || desc.contains("could not connect") ||
               desc.contains("no route") || desc.contains("offline") ||
               desc.contains("URLError")
    }

    // MARK: - Friendly Error Messages

    private func friendlyMessage(for error: Error) -> String {
        if isRateLimitError(error) {
            return "请求过于频繁，请稍等片刻再重试"
        }
        if isAuthError(error) {
            return "API 密钥无效或未配置。\n请编辑 ~/.openinfo.env 设置 AI_API_KEY\n格式：AI_API_KEY=sk-your-key"
        }
        if isContextLengthError(error) {
            return "对话过长，请发送新话题或清理历史记录"
        }
        if isNetworkError(error) {
            return "网络连接失败，请检查网络后重试"
        }
        return "遇到问题，请稍后重试"
    }

    // MARK: - Error Logging

    private func logError(_ error: Error, attempt: Int, contextSize: Int) {
        let timestamp = DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] attempt=\(attempt) contextSize=\(contextSize) error=\(error.localizedDescription)\n"
        guard let data = entry.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: Self.logFile.path) {
            if let handle = try? FileHandle(forWritingTo: Self.logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: Self.logFile, options: .atomic)
        }
    }

    // MARK: - Clear

    func clear() {
        messages.removeAll()
        inputText = ""
        UserDefaults.standard.removeObject(forKey: Self.persistKey)
    }

    // MARK: - Persistence

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: Self.persistKey)
    }

    private func loadHistory() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.persistKey),
            let saved = try? JSONDecoder().decode([ChatMessage].self, from: data)
        else { return }
        messages = saved
    }

    // MARK: - Helpers

    private func currentDateString() -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .short
        return f.string(from: Date())
    }
}