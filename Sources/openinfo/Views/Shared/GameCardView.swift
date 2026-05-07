import SwiftUI

/// Shared game card used in both the MenuBar Popover and the FloatingWindow.
/// `compact` mode is used in the Popover (smaller logos, tighter spacing).
struct GameCardView: View {
    let game: NBAGame
    var logoSize: CGFloat = 48
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 18) {

            // ── Away Team ──────────────────────────────────
            teamColumn(team: game.awayTeam)

            // ── Center: Score / Status ─────────────────────
            VStack(spacing: compact ? 5 : 8) {
                if game.isLive || game.isFinal {
                    scoreRow
                        .fixedSize()
                }
                StatusIndicatorView(status: game.status)
                    .fixedSize()
            }
            .frame(minWidth: compact ? 110 : 130)

            // ── Home Team ──────────────────────────────────
            teamColumn(team: game.homeTeam)
        }
        .padding(.horizontal, compact ? 14 : 20)
        .padding(.vertical, compact ? 12 : 16)
        .background(cardBackground)
    }

    // MARK: - Score Row

    private var scoreRow: some View {
        HStack(spacing: 6) {
            Text("\(game.awayTeam.score)")
                .font(.system(
                    size: compact ? 24 : 34,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(scoreColor(for: game.awayTeam, opponent: game.homeTeam))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("–")
                .font(.system(size: compact ? 13 : 18, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.25))

            Text("\(game.homeTeam.score)")
                .font(.system(
                    size: compact ? 24 : 34,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(scoreColor(for: game.homeTeam, opponent: game.awayTeam))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    // MARK: - Team Column

    private func teamColumn(team: TeamInfo) -> some View {
        VStack(spacing: compact ? 5 : 8) {
            TeamLogoView(url: team.logoURL, size: logoSize)

            Text(team.abbreviation)
                .font(.system(
                    size: compact ? 11 : 13,
                    weight: .bold,
                    design: .rounded
                ))
                .foregroundStyle(Color(hex: team.hexColor))
                .tracking(1.0)

            if !compact {
                Text(teamShortName(team.displayName))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(width: logoSize + 12)
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Helpers

    /// Winning team score shown in white, losing in dimmed white.
    private func scoreColor(for team: TeamInfo, opponent: TeamInfo) -> Color {
        guard game.isFinal || game.isLive else { return .white }
        if team.score > opponent.score { return .white }
        if team.score < opponent.score { return .white.opacity(0.4) }
        return .white
    }

    /// Returns the last word of a team's displayName (e.g. "Knicks" from "New York Knicks").
    private func teamShortName(_ fullName: String) -> String {
        fullName.components(separatedBy: " ").last ?? fullName
    }
}
