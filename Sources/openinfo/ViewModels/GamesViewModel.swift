import SwiftUI
import Observation

@Observable
@MainActor
final class GamesViewModel {

    // MARK: - Published State

    private(set) var games: [NBAGame] = []
    private(set) var menuBarIndex: Int = 0
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    // MARK: - Private

    private let service = NBAService()
    private var pollingTask: Task<Void, Never>?

    // MARK: - Current Menu Bar Game

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
                await self.fetch()
                let interval = refreshInterval(for: self.games)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Manual Refresh

    func refresh() async {
        await fetch()
    }

    // MARK: - Private Fetch

    private func fetch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchGames()
            games = fetched
            // Clamp index to valid range
            if menuBarIndex >= games.count, !games.isEmpty {
                menuBarIndex = 0
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
