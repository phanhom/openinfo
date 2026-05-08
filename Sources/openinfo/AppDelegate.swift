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

        // Ensure a minimum height so the floating window isn't too short
        // in release builds where SwiftUI intrinsic-size calculation may differ
        let minWidth: CGFloat = 324
        let minHeight: CGFloat = 360
        var frame = window.frame
        if frame.height < minHeight {
            let newHeight = minHeight
            frame.origin.y -= (newHeight - frame.height)
            frame.size.height = newHeight
            frame.size.width = minWidth
            window.setFrame(frame, display: true)
        }
        window.minSize = NSSize(width: minWidth, height: minHeight)
    }
}
