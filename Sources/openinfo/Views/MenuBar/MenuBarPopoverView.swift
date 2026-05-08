import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(GamesViewModel.self) private var vm
    @State private var chatVM = ChatViewModel()
    @State private var showChat = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Header Bar ─────────────────────────────────────────────────
            HStack(spacing: 0) {

                // League name + cycle button
                HStack(spacing: 2) {
                    Text(vm.selectedLeague.rawValue)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(1.5)

                    Button { vm.cycleLeague() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Spacer()

                // Chat toggle
                Button { withAnimation(.easeInOut(duration: 0.2)) { showChat.toggle() } } label: {
                    Image(systemName: showChat ? "bubble.fill" : "bubble")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            divider

            // ── Game Card ─────────────────────────────────────────────────
            Group {
                if let game = vm.currentMenuBarGame {
                    GameCardView(
                        game: game,
                        logoSize: 46,
                        compact: true,
                        onNext: vm.hasMultipleGames ? { vm.nextGame() } : nil
                    )
                    .padding(10)
                    .transition(.opacity)
                    .id(game.id)
                } else if vm.isLoading {
                    loadingPlaceholder
                } else {
                    emptyPlaceholder
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.currentMenuBarGame?.id)

            // ── AI Chat (collapsible) ─────────────────────────────────────
            if showChat {
                divider
                ChatView(vm: chatVM)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // ── Error ─────────────────────────────────────────────────────
            if let err = vm.errorMessage {
                divider
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
        }
        .frame(width: 296)
        .background(Color.black)
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    private var loadingPlaceholder: some View {
        ProgressView()
            .controlSize(.small)
            .tint(.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(36)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            SVGView(name: "basketball", size: 60)
                .frame(width: 60, height: 60)
            Text("No games today")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}

// MARK: - Ghost Button Style

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                configuration.isPressed
                    ? Color.white.opacity(0.8)
                    : Color.white.opacity(0.45)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
