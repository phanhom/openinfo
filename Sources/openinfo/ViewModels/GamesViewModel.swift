import SwiftUI
import Observation

@Observable
@MainActor
final class GamesViewModel {

    // MARK: - League State

    private(set) var selectedLeague: League = .nba

    // Per-league game lists
    private(set) var gamesByLeague: [League: [NBAGame]] = [:]

    // Per-league menu bar index
    private var menuBarIndexByLeague: [League: Int] = [:]

    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    // MARK: - Private

    private let service = SportsService()
    private var pollingTask: Task<Void, Never>?

    // MARK: - Current League Games

    var games: [NBAGame] {
        gamesByLeague[selectedLeague] ?? []
    }

    var menuBarIndex: Int {
        get { menuBarIndexByLeague[selectedLeague] ?? 0 }
        set { menuBarIndexByLeague[selectedLeague] = newValue }
    }

    var currentMenuBarGame: NBAGame? {
        guard !games.isEmpty else { return nil }
        return games[menuBarIndex % games.count]
    }

    var menuBarTitle: String {
        currentMenuBarGame?.menuBarLabel ?? ""
    }

    var hasMultipleGames: Bool {
        games.count > 1
    }

    var gameCountLabel: String {
        "\(menuBarIndex + 1)/\(games.count)"
    }

    var hasAnyGames: Bool {
        gamesByLeague.values.contains { !$0.isEmpty }
    }

    // MARK: - League Switching

    func selectLeague(_ league: League) {
        selectedLeague = league
    }

    func cycleLeague() {
        let all = League.allCases
        guard let idx = all.firstIndex(of: selectedLeague) else { return }
        selectedLeague = all[(idx + 1) % all.count]
    }

    // MARK: - Navigation

    func nextGame() {
        guard games.count > 1 else { return }
        menuBarIndex = (menuBarIndex + 1) % games.count
    }

    func prevGame() {
        guard games.count > 1 else { return }
        menuBarIndex = (menuBarIndex - 1 + games.count) % games.count
    }

    // MARK: - Polling

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetchAll()
                let allGames = self.gamesByLeague.values.flatMap { $0 }
                let interval = refreshInterval(for: allGames)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        await fetchAll()
    }

    // MARK: - Private Fetch

    private func fetchAll() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Fetch all leagues in parallel
        await withTaskGroup(of: (League, [NBAGame]?).self) { group in
            for league in League.allCases {
                group.addTask {
                    let fetched = try? await self.service.fetchGames(for: league)
                    return (league, fetched)
                }
            }
            for await (league, fetched) in group {
                if let games = fetched {
                    gamesByLeague[league] = games
                    // Clamp index
                    let idx = menuBarIndexByLeague[league] ?? 0
                    if idx >= games.count {
                        menuBarIndexByLeague[league] = 0
                    }
                }
            }
        }
    }
}
