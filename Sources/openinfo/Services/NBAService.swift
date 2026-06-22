import Foundation

// MARK: - Sports Service

actor SportsService {

    private let decoder = JSONDecoder()

    func fetchGames(for league: League) async throws -> [NBAGame] {
        guard league.usesESPN else {
            return try await fetchCS2Matches()
        }

        let (data, response) = try await URLSession.shared.data(from: league.scoreboardURL)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { throw URLError(.badServerResponse) }

        let espnResponse = try decoder.decode(ESPNResponse.self, from: data)
        return espnResponse.events.compactMap { NBAGame.from(event: $0, league: league) }
    }

    private func fetchCS2Matches() async throws -> [NBAGame] {
        let url = URL(string: "https://www.hltv.org/matches")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 openinfo", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { throw URLError(.badServerResponse) }

        let html = String(data: data, encoding: .utf8) ?? ""
        return CS2MatchParser.parseTodayMatches(from: html).map { $0.asGame() }
    }
}

// MARK: - Refresh Interval

func refreshInterval(for games: [NBAGame]) -> TimeInterval {
    for game in games {
        guard case .inProgress(_, let clock) = game.status else { continue }
        // Last 3 minutes of any quarter → 2s
        if let seconds = parseClock(clock), seconds <= 180 {
            return 2
        }
        return 6
    }
    // All games are final or scheduled → 30s
    return 30
}

/// Parse "M:SS" or "MM:SS" countdown clock into total seconds.
private func parseClock(_ clock: String) -> Int? {
    let parts = clock.split(separator: ":")
    guard parts.count == 2,
          let minutes = Int(parts[0]),
          let seconds = Int(parts[1])
    else { return nil }
    return minutes * 60 + seconds
}
