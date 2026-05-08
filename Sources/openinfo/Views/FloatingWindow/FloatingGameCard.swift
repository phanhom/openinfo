import SwiftUI

struct FloatingGameCard: View {
    let game: NBAGame

    @State private var isHovered = false

    var body: some View {
        GameCardView(game: game, logoSize: 52, compact: false)
            .overlay(
                // Live game: subtle green glow border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        game.isLive
                            ? Color.green.opacity(isHovered ? 0.5 : 0.25)
                            : Color.white.opacity(0.06),
                        lineWidth: game.isLive ? 1.5 : 0.5
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: isHovered)
            .onHover { isHovered = $0 }
    }
}