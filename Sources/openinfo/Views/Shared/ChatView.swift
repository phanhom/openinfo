import SwiftUI

struct ChatView: View {
    @Bindable var vm: ChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var scrollID: UUID?

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────
            HStack {
                Label("AI", systemImage: "sparkle")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(0.8)

                Spacer()

                if !vm.messages.isEmpty {
                    Button { vm.clear() } label: {
                        Text("clear")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.2), value: vm.messages.isEmpty)

            // ── Messages ──────────────────────────────────────────────────
            if !vm.messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(vm.messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                            if vm.isThinking {
                                ThinkingIndicator()
                                    .id("thinking")
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: 220)
                    .onChange(of: vm.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            if let lastID = vm.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: vm.isThinking) { _, thinking in
                        if thinking {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("thinking", anchor: .bottom)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // ── Input ─────────────────────────────────────────────────────
            inputBar
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 0) {
            TextField("Ask anything...", text: $vm.inputText, axis: .vertical)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .tint(.white.opacity(0.6))
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit {
                    Task { await vm.send() }
                }
                .submitLabel(.send)
                .padding(.vertical, 9)
                .padding(.leading, 12)

            // Send / loading indicator
            ZStack {
                if vm.isThinking {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white.opacity(0.3))
                } else {
                    Button {
                        Task { await vm.send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.white.opacity(0.12)
                                    : Color.white.opacity(0.7)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .frame(width: 36, height: 36)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            inputFocused
                                ? Color.white.opacity(0.2)
                                : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.15), value: inputFocused)
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(textColor)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(bubbleBackground)
                .frame(
                    maxWidth: .infinity,
                    alignment: message.role == .user ? .trailing : .leading
                )

            if message.role != .user { Spacer(minLength: 40) }
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user:      return .white.opacity(0.9)
        case .assistant: return .white.opacity(0.75)
        case .error:     return .orange.opacity(0.8)
        }
    }

    private var bubbleBackground: some View {
        Group {
            switch message.role {
            case .user:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            case .assistant:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.clear)
            case .error:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Thinking Indicator

private struct ThinkingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == i ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .onAppear { phase = 0 }
    }
}
