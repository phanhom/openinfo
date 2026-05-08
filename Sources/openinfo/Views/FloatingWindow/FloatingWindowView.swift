import SwiftUI

struct FloatingWindowView: View {
    @Environment(GamesViewModel.self) private var vm
    @State private var chatVM = ChatViewModel()
    @State private var showChat = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.games.contains(where: { $0.isLive }) ? Color.green : Color.white.opacity(0.2))
                        .frame(width: 7, height: 7)

                    Text("openinfo")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1.2)
                }

                Spacer()

                // League name + cycle
                HStack(spacing: 2) {
                    Text(vm.selectedLeague.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(0.8)

                    Button { vm.cycleLeague() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Chat toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showChat.toggle() }
                } label: {
                    Image(systemName: showChat ? "bubble.fill" : "bubble")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(showChat ? 0.7 : 0.35))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // ── Divider ───────────────────────────────────────────────────
            divider

            // ── Games List ────────────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(vm.games) { game in
                        FloatingGameCard(game: game)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .frame(minHeight: 200, maxHeight: 480)
            .overlay {
                if vm.games.isEmpty && !vm.isLoading {
                    emptyState
                }
            }

            // ── AI Chat (collapsible) ─────────────────────────────────────
            if showChat {
                divider
                ChatView(vm: chatVM)
                    .frame(minHeight: 200, maxHeight: 280)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: 324)
        .background(windowBackground)
        .animation(.easeInOut(duration: 0.2), value: showChat)
    }

    // MARK: - Background

    private var windowBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            SVGView(name: "basketball", size: 72)
                .frame(width: 72, height: 72)
            Text("No games today")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}