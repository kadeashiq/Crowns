import Foundation
import CoreGraphics
import UIKit

/// Downloads candidate product photos and keeps the ones that look like
/// photos of the product: big enough, not banner- or strip-shaped.
enum ImageFetcher {
    struct Photo: Identifiable, Hashable {
        let id = UUID()
        /// Downscaled JPEG, ≤ `storedPixel` on the long side. This is what gets stored.
        let data: Data
        let pixelSize: CGSize
        let sourceURL: URL?
        /// Already decoded, small enough to keep several in memory, so the
        /// sheet never decodes on the main thread or pops an image in.
        let preview: UIImage

        static func == (a: Photo, b: Photo) -> Bool { a.id == b.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    static let previewPixel = 800

    static let storedPixel = 1600
    static let minimumPixel: CGFloat = 300

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.httpMaximumConnectionsPerHost = 4
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    /// Fetches up to `limit` usable photos, in the order given.
    static func photos(from urls: [URL], referer: URL?, limit: Int = 8) async -> [Photo] {
        let candidates = Array(urls.prefix(limit + 4))
        let results = await withTaskGroup(of: (Int, Photo?).self) { group in
            for (index, url) in candidates.enumerated() {
                group.addTask { (index, await photo(from: url, referer: referer)) }
            }
            var collected: [(Int, Photo)] = []
            for await (index, photo) in group {
                if let photo { collected.append((index, photo)) }
            }
            return collected
        }
        return results.sorted { $0.0 < $1.0 }.map(\.1).prefix(limit).map { $0 }
    }

    static func photo(from url: URL, referer: URL?) async -> Photo? {
        var request = URLRequest(url: url)
        request.setValue(UserAgent.mobileSafari, forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/heic,image/jpeg,image/png,image/*;q=0.8", forHTTPHeaderField: "Accept")
        if let referer { request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer") }
        guard let fetched = try? await session.data(for: request) else { return nil }
        let (data, response) = fetched
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return photo(from: data, sourceURL: url)
    }

    /// Validates and downscales image bytes from any source.
    static func photo(from data: Data, sourceURL: URL? = nil) -> Photo? {
        guard let size = ImageDownscaler.pixelSize(of: data),
              min(size.width, size.height) >= minimumPixel else { return nil }
        let aspect = size.width / max(size.height, 1)
        guard aspect > 0.4, aspect < 2.5 else { return nil }
        let longSide = max(size.width, size.height)
        let target = min(Int(longSide), storedPixel)
        guard let jpeg = ImageDownscaler.jpeg(from: data, maxPixel: target),
              let preview = ImageDownscaler.thumbnail(from: jpeg, maxPixel: min(target, previewPixel)) else { return nil }
        let scale = CGFloat(target) / longSide
        return Photo(
            data: jpeg,
            pixelSize: CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded()),
            sourceURL: sourceURL,
            preview: UIImage(cgImage: preview)
        )
    }
}
