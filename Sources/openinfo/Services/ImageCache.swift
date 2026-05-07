import SwiftUI
import CryptoKit

// MARK: - Image Cache

actor ImageCache {
    static let shared = ImageCache()

    // In-memory cache
    private var memoryCache: [URL: Image] = [:]

    // Disk cache directory: ~/Library/Caches/openinfo/logos/
    private let cacheDirectory: URL = {
        let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!
        let dir = caches.appendingPathComponent("openinfo/logos", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }()

    // MARK: - Load

    func load(url: URL) async -> Image? {
        // 1. Memory cache hit
        if let cached = memoryCache[url] {
            return cached
        }

        // 2. Disk cache hit
        let filePath = diskPath(for: url)
        if let data = try? Data(contentsOf: filePath),
           let nsImage = NSImage(data: data) {
            let image = Image(nsImage: nsImage)
            memoryCache[url] = image
            return image
        }

        // 3. Network fetch + write to disk
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let nsImage = NSImage(data: data)
        else { return nil }

        // Persist to disk
        try? data.write(to: filePath, options: .atomic)

        let image = Image(nsImage: nsImage)
        memoryCache[url] = image
        return image
    }

    // MARK: - Clear

    func clearDiskCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
        memoryCache.removeAll()
    }

    // MARK: - Private

    private func diskPath(for url: URL) -> URL {
        // Use MD5 of the URL string as filename to avoid path-unsafe characters
        let hash = Insecure.MD5
            .hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return cacheDirectory.appendingPathComponent("\(hash).png")
    }
}
