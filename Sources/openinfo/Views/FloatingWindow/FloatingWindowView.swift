import SwiftUI

struct FloatingWindowView: View {
    @Environment(GamesViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────
            HStack(spacing: 8) {
                // Live indicator
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

                if vm.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white.opacity(0.4))
                } else {
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // ── Divider ───────────────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            // ── Games List ────────────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(vm.games) { game in
                        FloatingGameCard(game: game)
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 580)
            .overlay {
                if vm.games.isEmpty && !vm.isLoading {
                    emptyState
                }
            }
        }
        .frame(width: 324)
        .background(windowBackground)
        .onAppear { vm.startPolling() }
        .onDisappear { vm.stopPolling() }
    }

    // MARK: - Backgrounds

    private var windowBackground: some View {
        ZStack {
            // Solid black fill
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)

            // Subtle inner border
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "basketball")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.1))
            Text("No games today")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
