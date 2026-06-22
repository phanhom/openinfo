import SwiftUI

struct TeamLogoView: View {
    let url: URL?
    let size: CGFloat

    @State private var cachedImage: Image? = nil
    @State private var failed = false

    var body: some View {
        Group {
            if let image = cachedImage {
                image
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .shadow(color: .white.opacity(0.08), radius: 4)

            } else if failed {
                Image(systemName: url == nil ? "scope" : "basketball.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.3))

            } else {
                // Skeleton placeholder while loading
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: size * 0.7, height: size * 0.7)
            }
        }
        .frame(width: size, height: size)
        .task(id: url) {
            guard let url else {
                failed = true
                return
            }
            if let image = await ImageCache.shared.load(url: url) {
                cachedImage = image
            } else {
                failed = true
            }
        }
    }
}
