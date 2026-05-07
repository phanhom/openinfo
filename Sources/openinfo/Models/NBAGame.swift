import Foundation

// MARK: - Game Status

enum GameStatus: Equatable {
    case scheduled(startTime: String)
    case inProgress(period: Int, clock: String)
    case final_
}

// MARK: - Team Info

struct TeamInfo: Identifiable, Equatable {
    var id: String { abbreviation }
    let displayName: String
    let abbreviation: String
    let logoURL: URL
    let hexColor: String   // "1d428a"
    let score: Int
    let isHome: Bool
}

// MARK: - NBA Game

struct NBAGame: Identifiable, Equatable {
    let id: String
    let homeTeam: TeamInfo
    let awayTeam: TeamInfo
    let status: GameStatus
    let shortDetail: String

    // MARK: Computed

    var isLive: Bool {
        if case .inProgress = status { return true }
        return false
    }

    var isFinal: Bool {
        status == .final_
    }

    /// Text shown in the menu bar: "NY 108  PHI 102 · Final"
    var menuBarLabel: String {
        switch status {
        case .scheduled(let time):
            return "\(awayTeam.abbreviation) vs \(homeTeam.abbreviation) · \(time)"
        case .inProgress, .final_:
            return "\(awayTeam.abbreviation) \(awayTeam.score)  \(homeTeam.abbreviation) \(homeTeam.score) · \(shortDetail)"
        }
    }
}

// MARK: - Mapper

extension NBAGame {
    static func from(event: ESPNEvent) -> NBAGame? {
        guard let comp = event.competitions.first else { return nil }
        guard comp.competitors.count >= 2 else { return nil }

        guard
            let homeComp = comp.competitors.first(where: { $0.homeAway == "home" }),
            let awayComp = comp.competitors.first(where: { $0.homeAway == "away" })
        else { return nil }

        let statusType = comp.status.type
        let gameStatus: GameStatus
        switch statusType.state {
        case "pre":
            gameStatus = .scheduled(startTime: statusType.shortDetail)
        case "in":
            gameStatus = .inProgress(
                period: comp.status.period ?? 1,
                clock: comp.status.displayClock ?? ""
            )
        default:
            gameStatus = .final_
        }

        return NBAGame(
            id: event.id,
            homeTeam: TeamInfo(
                displayName: homeComp.team.displayName,
                abbreviation: homeComp.team.abbreviation,
                logoURL: homeComp.team.logo,
                hexColor: homeComp.team.color,
                score: Int(homeComp.score) ?? 0,
                isHome: true
            ),
            awayTeam: TeamInfo(
                displayName: awayComp.team.displayName,
                abbreviation: awayComp.team.abbreviation,
                logoURL: awayComp.team.logo,
                hexColor: awayComp.team.color,
                score: Int(awayComp.score) ?? 0,
                isHome: false
            ),
            status: gameStatus,
            shortDetail: statusType.shortDetail
        )
    }
}
