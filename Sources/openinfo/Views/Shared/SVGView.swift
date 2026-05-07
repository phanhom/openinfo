import SwiftUI
import AppKit

/// Renders an SVG from the app bundle by converting it to NSImage via CoreGraphics.
struct SVGView: View {
    let name: String
    var size: CGFloat = 80
    var opacity: Double = 0.25

    @State private var nsImage: NSImage? = nil

    var body: some View {
        Group {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .opacity(opacity)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .onAppear { load() }
    }

    private func load() {
        guard
            let url = Bundle.module.url(forResource: name, withExtension: "svg")
        else { return }

        let img = NSImage(contentsOf: url)
        img?.size = NSSize(width: size * 2, height: size * 2)
        if let source = img {
            nsImage = tinted(source, color: .white)
        }
    }

    /// Re-draws the image replacing all opaque pixels with `color`.
    private func tinted(_ source: NSImage, color: NSColor) -> NSImage {
        let size = source.size
        let result = NSImage(size: size)
        result.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: size))
        color.setFill()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        result.unlockFocus()
        return result
    }
}
