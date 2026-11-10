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

    /// Fetches up to `limit` usable photos, in the order given. Once
    /// `patience` has run out and there is at least one, slow ones are left
    /// behind rather than holding up the rest.
    static func photos(from urls: [URL], referer: URL?, limit: Int = 8, patience: Duration = .seconds(4)) async -> [Photo] {
        let candidates = Array(urls.prefix(limit + 4))
        guard !candidates.isEmpty else { return [] }
        return await withTaskGroup(of: (Int, Photo?).self) { group in
            for (index, url) in candidates.enumerated() {
                group.addTask { (index, await photo(from: url, referer: referer)) }
            }
            group.addTask {
                try? await Task.sleep(for: patience)
                return (-1, nil)
            }
            var found: [Int: Photo] = [:]
            var settled = 0
            var outOfPatience = false
            for await (index, photo) in group {
                if index < 0 {
                    outOfPatience = true
                } else {
                    settled += 1
                    found[index] = photo
                }
                if settled == candidates.count || (outOfPatience && !found.isEmpty) {
                    group.cancelAll()
                    break
                }
            }
            return found.sorted { $0.key < $1.key }.prefix(limit).map(\.value)
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
