import Foundation
import CoreGraphics
import UIKit

/// Downloads candidate product photos and keeps the ones that look like
/// photos of the product: big enough, not banner- or strip-shaped.
enum ImageFetcher {
    struct Photo: Identifiable, Hashable, Sendable {
        let id = UUID()
        /// What the cover is made from: the image as it came when that's
        /// light enough to hold, otherwise a JPEG ≤ `storedPixel` on the long side.
        let data: Data
        /// Already decoded, small enough to keep several in memory, so the
        /// sheet never decodes on the main thread or pops an image in.
        let preview: UIImage

        static func == (a: Photo, b: Photo) -> Bool { a.id == b.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    static let previewPixel = 800

    static let storedPixel = 1600
    static let minimumPixel: CGFloat = 300
    /// Heavier images are re-encoded rather than held as they came.
    static let heldBytes = 1_500_000

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.httpMaximumConnectionsPerHost = 4
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    /// Fetches up to `limit` usable photos and hands each one over once every
    /// photo ahead of it has been dealt with, so they arrive in the order given.
    static func photos(from urls: [URL], referer: URL?, limit: Int = 8, deliver: @escaping @MainActor @Sendable (Photo) -> Void) async {
        let candidates = Array(urls.prefix(limit + 4))
        await withTaskGroup(of: (Int, Photo?).self) { group in
            for (index, url) in candidates.enumerated() {
                group.addTask { (index, await photo(from: url, referer: referer)) }
            }
            var finished: [Int: Photo?] = [:]
            var next = 0
            var delivered = 0
            for await (index, photo) in group {
                finished[index] = .some(photo)
                while let result = finished.removeValue(forKey: next) {
                    next += 1
                    guard let result else { continue }
                    await deliver(result)
                    delivered += 1
                    if delivered == limit {
                        group.cancelAll()
                        return
                    }
                }
            }
        }
    }

    static func photo(from url: URL, referer: URL?) async -> Photo? {
        var request = URLRequest(url: url)
        request.setValue(UserAgent.mobileSafari, forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/heic,image/jpeg,image/png,image/*;q=0.8", forHTTPHeaderField: "Accept")
        if let referer { request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer") }
        guard let fetched = try? await session.data(for: request) else { return nil }
        let (data, response) = fetched
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return photo(from: data)
    }

    /// `photo(from:)`, off the main thread.
    static func preparedPhoto(from data: Data) async -> Photo? {
        await Task.detached(priority: .userInitiated) { photo(from: data) }.value
    }

    /// Validates image bytes from any source and prepares them for the sheet.
    static func photo(from data: Data) -> Photo? {
        guard let size = ImageDownscaler.pixelSize(of: data),
              min(size.width, size.height) >= minimumPixel else { return nil }
        let aspect = size.width / max(size.height, 1)
        guard aspect > 0.4, aspect < 2.5 else { return nil }
        let longSide = Int(max(size.width, size.height))
        let held = data.count <= heldBytes ? data : ImageDownscaler.jpeg(from: data, maxPixel: min(longSide, storedPixel))
        guard let held, let preview = ImageDownscaler.thumbnail(from: held, maxPixel: min(longSide, previewPixel)) else { return nil }
        return Photo(data: held, preview: UIImage(cgImage: preview))
    }
}
