import SwiftUI

struct StatusIndicatorView: View {
    let status: GameStatus

    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .opacity(isLive ? (pulsing ? 0.3 : 1.0) : 0.7)
                .animation(
                    isLive
                        ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )
                .onAppear { if isLive { pulsing = true } }
                .onChange(of: isLive) { _, live in pulsing = live }

            Text(statusText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
                .tracking(0.4)
        }
    }

    // MARK: - Derived

    private var isLive: Bool {
        if case .inProgress = status { return true }
        return false
    }

    private var dotColor: Color {
        switch status {
        case .inProgress:  return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .final_:      return Color(white: 0.45)
        case .scheduled:   return .white.opacity(0.55)
        }
    }

    private var textColor: Color {
        switch status {
        case .inProgress:  return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .final_:      return Color(white: 0.45)
        case .scheduled:   return .white.opacity(0.65)
        }
    }

    private var statusText: String {
        switch status {
        case .inProgress(let period, let clock):
            let label = period <= 4 ? "Q\(period)" : "OT\(period - 4)"
            return clock.isEmpty ? label : "\(label)  \(clock)"
        case .final_:
            return "FINAL"
        case .scheduled(let time):
            return time
        }
    }
}
