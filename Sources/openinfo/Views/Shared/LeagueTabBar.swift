import SwiftUI

struct LeagueTabBar: View {
    @Environment(GamesViewModel.self) private var vm

    var body: some View {
        HStack(spacing: 4) {
            ForEach(League.allCases) { league in
                leagueTab(league)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func leagueTab(_ league: League) -> some View {
        let isSelected = vm.selectedLeague == league
        let gameCount = vm.gamesByLeague[league]?.count ?? 0

        return Button {
            vm.selectLeague(league)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: league.sfSymbol)
                    .font(.system(size: 10, weight: .semibold))

                Text(league.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.5)

                if gameCount > 0 {
                    Text("\(gameCount)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.4))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white : Color.white.opacity(0.12))
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
