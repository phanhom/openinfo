import Foundation

enum CS2EventFilter {
    private static let topTierKeywords = [
        "major",
        "iem",
        "esl pro league",
        "blast",
        "pgl",
        "esports world cup",
        "fissure",
        "starladder",
        "starseries",
        "thunderpick world championship"
    ]

    static func isTopTier(eventName: String) -> Bool {
        let normalized = eventName.lowercased()
        return topTierKeywords.contains { normalized.contains($0) }
    }
}

struct CS2Team: Equatable {
    let name: String

    var abbreviation: String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "TBA" }
        let compact = cleaned.filter { $0.isLetter || $0.isNumber }
        if compact.count <= 4 { return compact.uppercased() }
        return String(compact.prefix(4)).uppercased()
    }
}

struct CS2Match: Identifiable, Equatable {
    let id: String
    let awayTeam: CS2Team
    let homeTeam: CS2Team
    let eventName: String
    let bestOf: String
    let status: GameStatus
    let mapName: String?
}

enum CS2MatchParser {
    static func parseTodayMatches(from html: String, now: Date = Date()) -> [CS2Match] {
        matchBlocks(in: html)
            .compactMap { parseMatch(from: $0) }
            .filter { CS2EventFilter.isTopTier(eventName: $0.eventName) }
    }

    private static func parseMatch(from block: String) -> CS2Match? {
        let teams = captures(in: block, pattern: #"matchTeamName[^>]*>\s*([^<]+)"#)
            .map(cleanText)
        guard teams.count >= 2 else { return nil }

        let eventName = firstCapture(in: block, pattern: #"matchEventName[^>]*>\s*([^<]+)"#)
            .map(cleanText) ?? "CS2"
        let bestOf = firstCapture(in: block, pattern: #"matchMeta[^>]*>\s*([^<]+)"#)
            .map { cleanText($0).lowercased() } ?? "bo3"
        let matchTime = firstCapture(in: block, pattern: #"matchTime[^>]*>\s*([^<]+)"#)
            .map(cleanText) ?? "TBD"
        let id = firstCapture(in: block, pattern: #"/matches/(\d+)/"#) ?? UUID().uuidString

        return CS2Match(
            id: "cs2-\(id)",
            awayTeam: CS2Team(name: teams[0]),
            homeTeam: CS2Team(name: teams[1]),
            eventName: eventName,
            bestOf: bestOf,
            status: parseStatus(from: block, matchTime: matchTime),
            mapName: firstMapName(in: block)
        )
    }

    private static func parseStatus(from block: String, matchTime: String) -> GameStatus {
        let normalized = block.lowercased()
        if normalized.contains("live") { return .inProgress(period: 1, clock: "LIVE") }
        if normalized.contains("matchwon") || normalized.contains("matchlost") { return .final_ }
        return .scheduled(startTime: matchTime)
    }

    private static func firstMapName(in block: String) -> String? {
        let maps = ["ancient", "anubis", "dust2", "inferno", "mirage", "nuke", "overpass", "train", "vertigo"]
        let normalized = block.lowercased()
        return maps.first { normalized.contains($0) }
    }

    private static func matchBlocks(in html: String) -> [String] {
        let pattern = #"<div[^>]+class=\"[^\"]*(?:upcomingMatch|liveMatch|result-con)[^\"]*\"[\s\S]*?(?=<div[^>]+class=\"[^\"]*(?:upcomingMatch|liveMatch|result-con)|\z)"#
        return captures(in: html, pattern: pattern, wholeMatch: true)
    }

    private static func captures(in string: String, pattern: String, wholeMatch: Bool = false) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.matches(in: string, range: range).compactMap { match in
            let captureRange = wholeMatch ? match.range : match.range(at: 1)
            guard let range = Range(captureRange, in: string) else { return nil }
            return String(string[range])
        }
    }

    private static func firstCapture(in string: String, pattern: String) -> String? {
        captures(in: string, pattern: pattern).first
    }

    private static func cleanText(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension CS2Match {
    func asGame() -> NBAGame {
        NBAGame(
            id: id,
            league: .cs2,
            homeTeam: TeamInfo(
                displayName: homeTeam.name,
                abbreviation: homeTeam.abbreviation,
                logoURL: nil,
                hexColor: "f0b90b",
                score: 0,
                isHome: true
            ),
            awayTeam: TeamInfo(
                displayName: awayTeam.name,
                abbreviation: awayTeam.abbreviation,
                logoURL: nil,
                hexColor: "d9d9d9",
                score: 0,
                isHome: false
            ),
            status: status,
            shortDetail: bestOf.uppercased(),
            eventName: eventName,
            bestOf: bestOf.uppercased(),
            mapName: mapName
        )
    }
}
