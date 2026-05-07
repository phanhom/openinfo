import SwiftUI
import Observation

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

    private static let windowSize = 10
    private static let persistKey = "openinfo.chatHistory"

    private(set) var messages: [ChatMessage] = []
    private(set) var isThinking  = false   // waiting before first token
    private(set) var isStreaming = false   // tokens flowing in
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
            messages.append(ChatMessage(role: .error, content: "AI not configured. Check .env file."))
            saveHistory()
            return
        }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        isThinking = true

        // 1. Web search for context (always, silently)
        let searchCtx = await searcher.searchContext(
            query: text + " \(currentDateString())"
        )

        // 2. Build sliding window + inject search results as system context
        let window = Array(messages.suffix(Self.windowSize))
        let aiMessages = window.compactMap { msg -> AIMessage? in
            switch msg.role {
            case .user:      return AIMessage(role: "user",      content: msg.content)
            case .assistant: return AIMessage(role: "assistant", content: msg.content)
            case .error:     return nil
            }
        }

        let systemPrompt = """
        Today's date and time: \(currentDateString()).
        \(searchCtx)
        Use the above web context to answer accurately. If the search results are irrelevant, ignore them.
        """

        // 3. Stream: show ThinkingRow until first token, then create bubble
        var assistantMsg: ChatMessage?
        var idx: Int?

        do {
            let stream = await ai.stream(messages: aiMessages, systemPrompt: systemPrompt)
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
        } catch {
            if let currentIdx = idx, messages[currentIdx].content.isEmpty {
                messages[currentIdx] = ChatMessage(role: .error, content: error.localizedDescription)
            } else if idx == nil {
                messages.append(ChatMessage(role: .error, content: error.localizedDescription))
            }
        }

        isThinking  = false
        isStreaming = false
        saveHistory()
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
