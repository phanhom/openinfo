import Foundation

// MARK: - League

enum League: String, CaseIterable, Identifiable {
    case nba = "NBA"
    case nfl = "NFL"
    case cs2 = "CS2"

    var id: String { rawValue }

    var espnPath: String {
        switch self {
        case .nba: return "basketball/nba"
        case .nfl: return "football/nfl"
        case .cs2: return ""
        }
    }

    var usesESPN: Bool {
        switch self {
        case .nba, .nfl: return true
        case .cs2: return false
        }
    }

    var sfSymbol: String {
        switch self {
        case .nba: return "basketball.fill"
        case .nfl: return "football.fill"
        case .cs2: return "scope"
        }
    }

    var scoreboardURL: URL {
        URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(espnPath)/scoreboard")!
    }
}
