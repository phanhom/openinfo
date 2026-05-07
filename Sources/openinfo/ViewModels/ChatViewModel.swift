import SwiftUI
import Observation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()

    enum MessageRole {
        case user
        case assistant
        case error
    }
}

// MARK: - Chat ViewModel

@Observable
@MainActor
final class ChatViewModel {

    // Sliding window: keep last N messages for context
    private static let windowSize = 10

    private(set) var messages: [ChatMessage] = []
    private(set) var isThinking = false
    var inputText: String = ""

    private let ai: AIService?

    var isAvailable: Bool { ai != nil }

    // Debug: expose whether config loaded
    var configStatus: String {
        if ai != nil { return "ready" }
        return "no config"
    }

    init() {
        self.ai = AIService.shared
    }

    // MARK: - Send

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        guard let ai else { return }

        inputText = ""
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        isThinking = true

        defer { isThinking = false }

        // Build sliding window context
        let window = Array(messages.suffix(Self.windowSize))
        let aiMessages = window.compactMap { msg -> AIMessage? in
            switch msg.role {
            case .user:      return AIMessage(role: "user",      content: msg.content)
            case .assistant: return AIMessage(role: "assistant", content: msg.content)
            case .error:     return nil
            }
        }

        do {
            let reply = try await ai.chat(
                messages: aiMessages,
                systemPrompt: "You are a concise, knowledgeable sports assistant. Keep answers short and direct."
            )
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            messages.append(ChatMessage(role: .error, content: error.localizedDescription))
        }
    }

    // MARK: - Clear

    func clear() {
        messages.removeAll()
        inputText = ""
    }
}
