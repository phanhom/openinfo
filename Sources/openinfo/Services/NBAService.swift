import Foundation

// MARK: - Sports Service

actor SportsService {

    private let decoder = JSONDecoder()

    func fetchGames(for league: League) async throws -> [NBAGame] {
        let (data, response) = try await URLSession.shared.data(from: league.scoreboardURL)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { throw URLError(.badServerResponse) }

        let espnResponse = try decoder.decode(ESPNResponse.self, from: data)
        return espnResponse.events.compactMap { NBAGame.from(event: $0) }
    }
}

// MARK: - Refresh Interval

func refreshInterval(for games: [NBAGame]) -> TimeInterval {
    games.contains(where: { $0.isLive }) ? 15 : 300
}
