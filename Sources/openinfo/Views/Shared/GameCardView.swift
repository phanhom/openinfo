import SwiftUI

/// Shared game card used in both the MenuBar Popover and the FloatingWindow.
/// `compact` mode is used in the Popover (smaller logos, tighter spacing).
/// `onNext` — if provided, shows a ▼ button below the status for cycling games.
struct GameCardView: View {
    let game: NBAGame
    var logoSize: CGFloat = 48
    var compact: Bool = false
    var onNext: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 18) {

            // ── Away Team ──────────────────────────────────
            teamColumn(team: game.awayTeam)

            // ── Center: Score / Status ─────────────────────
            VStack(spacing: compact ? 4 : 6) {
                if game.league == .cs2 {
                    cs2Meta
                } else if game.isLive || game.isFinal {
                    scoreRow
                        .fixedSize()
                }
                StatusIndicatorView(status: game.status)
                    .fixedSize()

                // ▼ next game button (only when provided)
                if let onNext {
                    Button(action: onNext) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(width: 24, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
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

    private var cs2Meta: some View {
        VStack(spacing: 2) {
            Text(game.bestOf ?? game.shortDetail)
                .font(.system(size: compact ? 15 : 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(1.2)

            if let eventName = game.eventName {
                Text(shortEventName(eventName))
                    .font(.system(size: compact ? 8 : 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: compact ? 90 : 120)
            }
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
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                .fill(backgroundBase)

            if game.league == .cs2 {
                cs2Backdrop
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous))
            }

            RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                .strokeBorder(Color.white.opacity(game.league == .cs2 ? 0.12 : 0.08), lineWidth: 1)
        }
    }

    private var backgroundBase: some ShapeStyle {
        if game.league == .cs2 {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.10, blue: 0.07), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.white.opacity(0.04))
    }

    private var cs2Backdrop: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [mapAccent.opacity(0.22), Color.clear, Color.black.opacity(0.35)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            Text((game.mapName ?? "CS2").uppercased())
                .font(.system(size: compact ? 28 : 42, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.055))
                .tracking(2)
                .rotationEffect(.degrees(-8))
                .offset(x: compact ? 10 : 16, y: compact ? 4 : 8)

            Image(systemName: "scope")
                .font(.system(size: compact ? 34 : 52, weight: .thin))
                .foregroundStyle(mapAccent.opacity(0.14))
                .offset(x: compact ? -4 : -8, y: compact ? -2 : -4)
        }
    }

    private var mapAccent: Color {
        switch game.mapName?.lowercased() {
        case "inferno": return Color(red: 0.95, green: 0.32, blue: 0.12)
        case "mirage": return Color(red: 0.88, green: 0.62, blue: 0.32)
        case "nuke": return Color(red: 0.24, green: 0.56, blue: 0.95)
        case "ancient": return Color(red: 0.25, green: 0.70, blue: 0.42)
        case "anubis", "dust2": return Color(red: 0.84, green: 0.66, blue: 0.38)
        case "overpass": return Color(red: 0.48, green: 0.64, blue: 0.76)
        default: return Color(red: 0.95, green: 0.65, blue: 0.18)
        }
    }

    // MARK: - Helpers

    private func scoreColor(for team: TeamInfo, opponent: TeamInfo) -> Color {
        guard game.isFinal || game.isLive else { return .white }
        if team.score > opponent.score { return .white }
        if team.score < opponent.score { return .white.opacity(0.4) }
        return .white
    }

    private func teamShortName(_ fullName: String) -> String {
        fullName.components(separatedBy: " ").last ?? fullName
    }

    private func shortEventName(_ eventName: String) -> String {
        eventName
            .replacingOccurrences(of: "Counter-Strike 2", with: "CS2")
            .replacingOccurrences(of: "2026", with: "'26")
            .replacingOccurrences(of: "Season", with: "S")
    }
}
