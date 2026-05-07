import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(GamesViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {

            // ── Header Bar ─────────────────────────────────────────────────
            HStack(spacing: 8) {

                // Title
                Text("NBA")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1.5)

                Spacer()

                // Pagination (only when multiple games)
                if vm.hasMultipleGames {
                    HStack(spacing: 2) {
                        Text(vm.gameCountLabel)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .monospacedDigit()
                            .frame(minWidth: 28)

                        Button { vm.nextGame() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }

                // Refresh button
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                        .rotationEffect(vm.isLoading ? .degrees(360) : .zero)
                        .animation(
                            vm.isLoading
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: vm.isLoading
                        )
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            divider

            // ── Game Card ─────────────────────────────────────────────────
            Group {
                if let game = vm.currentMenuBarGame {
                    GameCardView(game: game, logoSize: 46, compact: true)
                        .padding(10)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal:   .opacity.combined(with: .move(edge: .leading))
                        ))
                        .id(game.id)
                } else if vm.isLoading {
                    loadingPlaceholder
                } else {
                    emptyPlaceholder
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.currentMenuBarGame?.id)

            // ── Footer: error indicator ───────────────────────────────────
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
        .onAppear {
            Task { await vm.refresh() }
        }
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
