import XCTest
@testable import openinfo

final class CS2MatchParsingTests: XCTestCase {

    func testTopTierFilterAcceptsPremierCS2Events() {
        XCTAssertTrue(CS2EventFilter.isTopTier(eventName: "IEM Cologne Major 2026"))
        XCTAssertTrue(CS2EventFilter.isTopTier(eventName: "BLAST Open Porto 2026"))
        XCTAssertTrue(CS2EventFilter.isTopTier(eventName: "PGL Singapore Major 2026"))
        XCTAssertTrue(CS2EventFilter.isTopTier(eventName: "Esports World Cup 2026"))
        XCTAssertTrue(CS2EventFilter.isTopTier(eventName: "StarLadder StarSeries September 2026"))
    }

    func testTopTierFilterRejectsSmallRegionalEvents() {
        XCTAssertFalse(CS2EventFilter.isTopTier(eventName: "European Pro League Series 7"))
        XCTAssertFalse(CS2EventFilter.isTopTier(eventName: "Svenska CS-Ligan 2026"))
        XCTAssertFalse(CS2EventFilter.isTopTier(eventName: "CCT 2026 Challengers Europe Series 4"))
    }

    func testParserKeepsOnlyTopTierTodayMatches() throws {
        let html = """
        <div class="upcomingMatch" data-zonedgrouping-entry-unix="1780000000000">
            <a href="/matches/2395002/furia-vs-falcons-iem-cologne-major-2026">
                <div class="matchTime">20:00</div>
                <div class="matchMeta">bo3</div>
                <div class="matchTeamName">FURIA</div>
                <div class="matchTeamName">Falcons</div>
                <div class="matchEventName">IEM Cologne Major 2026</div>
            </a>
        </div>
        <div class="upcomingMatch" data-zonedgrouping-entry-unix="1780003600000">
            <a href="/matches/2395358/lilmix-vs-rethink-svenska-cs-ligan-2026">
                <div class="matchTime">22:00</div>
                <div class="matchMeta">bo1</div>
                <div class="matchTeamName">Lilmix</div>
                <div class="matchTeamName">ReThink</div>
                <div class="matchEventName">Svenska CS-Ligan 2026</div>
            </a>
        </div>
        """

        let matches = CS2MatchParser.parseTodayMatches(from: html, now: Date(timeIntervalSince1970: 1_780_000_000))

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].homeTeam.name, "Falcons")
        XCTAssertEqual(matches[0].awayTeam.name, "FURIA")
        XCTAssertEqual(matches[0].eventName, "IEM Cologne Major 2026")
        XCTAssertEqual(matches[0].bestOf, "bo3")
    }
}
