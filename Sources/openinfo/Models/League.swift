import Foundation

// MARK: - League

enum League: String, CaseIterable, Identifiable {
    case nba = "NBA"
    case nfl = "NFL"

    var id: String { rawValue }

    var espnPath: String {
        switch self {
        case .nba: return "basketball/nba"
        case .nfl: return "football/nfl"
        }
    }

    var sfSymbol: String {
        switch self {
        case .nba: return "basketball.fill"
        case .nfl: return "football.fill"
        }
    }

    var scoreboardURL: URL {
        URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(espnPath)/scoreboard")!
    }
}
