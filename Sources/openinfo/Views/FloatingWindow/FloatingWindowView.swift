import SwiftUI

struct FloatingWindowView: View {
    @Environment(GamesViewModel.self) private var vm

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

    // MARK: - Background

    private var windowBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        }
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
        .padding(.vertical, 48)
    }
}
