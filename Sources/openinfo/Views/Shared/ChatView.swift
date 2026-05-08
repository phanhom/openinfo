import SwiftUI

// MARK: - Chat View

struct ChatView: View {
    @Bindable var vm: ChatViewModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("AI")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.8)
                }

                Spacer()

                if !vm.messages.isEmpty {
                    Button { vm.clear() } label: {
                        Text("clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .animation(.easeInOut(duration: 0.15), value: vm.messages.isEmpty)

            // ── Messages ──────────────────────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        // Three-dot thinking indicator
                        if vm.isThinking {
                            ThinkingRow()
                                .id("thinking")
                                .transition(.opacity)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                }
                .frame(height: 200)
                .onChange(of: vm.messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: vm.isThinking) { _, v in if v { scrollToBottom(proxy) } }
                .onChange(of: vm.messages.last?.content) { _, _ in scrollToBottom(proxy) }
                .onAppear { scrollToBottom(proxy) }
            }

            // ── Input bar ─────────────────────────────────────────────────
            InputBar(vm: vm, focused: $inputFocused)
        }
        .onAppear { inputFocused = true }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    // iMessage-style corner radii
    private let bigR: CGFloat   = 18
    private let smallR: CGFloat = 4

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.role == .user { Spacer(minLength: 48) }

            Group {
                if let attr = try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .full)) {
                    Text(attr)
                } else {
                    Text(message.content)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(textColor)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubble)
            .fixedSize(horizontal: false, vertical: true)

            if message.role != .user { Spacer(minLength: 48) }
        }
        .padding(.vertical, 2)
    }

    // MARK: Bubble shape (iMessage asymmetric corners)
    @ViewBuilder
    private var bubble: some View {
        switch message.role {
        case .user:
            // Blue-tinted right bubble
            RoundedCornerShape(
                topLeft: bigR, topRight: bigR,
                bottomLeft: bigR, bottomRight: smallR
            )
            .fill(Color(red: 0.18, green: 0.48, blue: 0.95).opacity(0.85))

        case .assistant:
            // Dark grey left bubble
            RoundedCornerShape(
                topLeft: bigR, topRight: bigR,
                bottomLeft: smallR, bottomRight: bigR
            )
            .fill(Color.white.opacity(0.1))

        case .error:
            RoundedCornerShape(
                topLeft: bigR, topRight: bigR,
                bottomLeft: smallR, bottomRight: bigR
            )
            .fill(Color.orange.opacity(0.15))
            .overlay(
                RoundedCornerShape(
                    topLeft: bigR, topRight: bigR,
                    bottomLeft: smallR, bottomRight: bigR
                )
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user:      return .white
        case .assistant: return .white.opacity(0.85)
        case .error:     return .orange
        }
    }
}

// MARK: - Thinking Row

private struct ThinkingRow: View {
    @State private var dotOpacity: [Double] = [0.2, 0.2, 0.2]
    @State private var step = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(dotOpacity[i]))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedCornerShape(topLeft: 18, topRight: 18, bottomLeft: 4, bottomRight: 18)
                    .fill(Color.white.opacity(0.08))
            )
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 10)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dotOpacity = [0.2, 0.2, 0.2]
                        dotOpacity[step % 3] = 0.9
                    }
                    step += 1
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Input Bar

private struct InputBar: View {
    @Bindable var vm: ChatViewModel
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 0) {
            TextField("Message", text: $vm.inputText, axis: .vertical)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .tint(Color(red: 0.18, green: 0.48, blue: 0.95))
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused(focused)
                .onSubmit {
                    Task { await vm.send() }
                }
                .padding(.vertical, 9)
                .padding(.leading, 14)

            // Send button or spinner
            ZStack {
                if vm.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white.opacity(0.35))
                } else {
                    let hasText = !vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                    Button {
                        Task { await vm.send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                hasText
                                    ? Color(red: 0.18, green: 0.48, blue: 0.95)
                                    : Color.white.opacity(0.1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasText)
                }
            }
            .frame(width: 38, height: 38)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            focused.wrappedValue
                                ? Color.white.opacity(0.18)
                                : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .animation(.easeInOut(duration: 0.15), value: focused.wrappedValue)
    }
}

// MARK: - Asymmetric Rounded Corner Shape (iMessage style)

private struct RoundedCornerShape: Shape {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let tl = min(topLeft,    w/2, h/2)
        let tr = min(topRight,   w/2, h/2)
        let bl = min(bottomLeft, w/2, h/2)
        let br = min(bottomRight,w/2, h/2)

        path.move(to: CGPoint(x: tl, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr),    radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0),   clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br),radius: br, startAngle: .degrees(0),   endAngle: .degrees(90),  clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl),    radius: bl, startAngle: .degrees(90),  endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl),        radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
