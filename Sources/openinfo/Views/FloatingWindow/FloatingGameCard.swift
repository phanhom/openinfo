import SwiftUI

struct FloatingGameCard: View {
    let game: NBAGame

    @State private var isHovered = false

    var body: some View {
        GameCardView(game: game, logoSize: 52, compact: false)
            .overlay(
                // Live game: green glow border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        game.isLive
                            ? Color.green.opacity(isHovered ? 0.5 : 0.25)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .shadow(
                color: game.isLive
                    ? Color.green.opacity(isHovered ? 0.12 : 0.06)
                    : .clear,
                radius: 12
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
