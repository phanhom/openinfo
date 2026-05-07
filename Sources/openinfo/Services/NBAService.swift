import Foundation

// MARK: - NBA Service

actor NBAService {
    private let endpoint = URL(
        string: "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard"
    )!

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()

    func fetchGames() async throws -> [NBAGame] {
        let (data, response) = try await URLSession.shared.data(from: endpoint)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let espnResponse = try decoder.decode(ESPNResponse.self, from: data)
        return espnResponse.events.compactMap { NBAGame.from(event: $0) }
    }
}

// MARK: - Refresh Interval

/// Returns polling interval based on whether any games are currently live.
func refreshInterval(for games: [NBAGame]) -> TimeInterval {
    games.contains(where: { $0.isLive }) ? 15 : 300
}
