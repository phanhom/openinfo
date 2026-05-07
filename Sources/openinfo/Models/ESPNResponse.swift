import Foundation

// MARK: - Top Level

struct ESPNResponse: Codable {
    let events: [ESPNEvent]
}

// MARK: - Event

struct ESPNEvent: Codable {
    let id: String
    let competitions: [ESPNCompetition]
}

// MARK: - Competition

struct ESPNCompetition: Codable {
    let competitors: [ESPNCompetitor]
    let status: ESPNStatus
}

// MARK: - Competitor

struct ESPNCompetitor: Codable {
    let homeAway: String   // "home" | "away"
    let score: String      // "108"
    let team: ESPNTeam
}

// MARK: - Team

struct ESPNTeam: Codable {
    let displayName: String    // "New York Knicks"
    let abbreviation: String   // "NY"
    let logo: URL              // https://a.espncdn.com/...
    let color: String          // "1d428a" (no #)
    let alternateColor: String?
}

// MARK: - Status

struct ESPNStatus: Codable {
    let period: Int?
    let displayClock: String?  // "2:34"
    let type: ESPNStatusType
}

struct ESPNStatusType: Codable {
    let name: String           // STATUS_SCHEDULED | STATUS_IN_PROGRESS | STATUS_FINAL
    let shortDetail: String    // "Final" | "Q4 2:34" | "7:30 PM ET"
    let state: String          // "pre" | "in" | "post"
}
