import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a menu-bar-only app: no Dock icon, no app menu
        NSApp.setActivationPolicy(.accessory)

        // Delay slightly to let SwiftUI create the window
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            configureFloatingWindow()
        }
    }

    // MARK: - Floating Window Setup

    @MainActor
    private func configureFloatingWindow() {
        guard let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "floating"
        }) else { return }

        // Always on top of all normal windows
        window.level = .floating

        // Visible across all Spaces + in full-screen mode
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary
        ]

        // Allow dragging by clicking anywhere on the content
        window.isMovableByWindowBackground = true

        // Transparent window chrome
        window.hasShadow = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
    }
}
