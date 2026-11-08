import SwiftUI
import UIKit

/// Decoded, display-ready images keyed by content. Decoding happens off the
/// main thread before anything is shown, so images never pop in half-drawn.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func image(for key: String, data: Data, maxPixel: Int) async -> UIImage? {
        if let hit = cached(key) { return hit }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let cg = ImageDownscaler.thumbnail(from: data, maxPixel: maxPixel) else { return nil }
            return UIImage(cgImage: cg, scale: 1, orientation: .up)
        }.value
        if let image {
            cache.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height * 4))
        }
        return image
    }
}

/// Shows image data once it is decoded. Holds its frame from the
/// start, so nothing around it moves or resizes when the image arrives.
struct DecodedImage: View {
    let key: String
    let data: Data?
    var maxPixel: Int = 1000
    var contentMode: ContentMode = .fit

    @State private var image: UIImage?

    init(key: String, data: Data?, maxPixel: Int = 1000, contentMode: ContentMode = .fit) {
        self.key = key
        self.data = data
        self.maxPixel = maxPixel
        self.contentMode = contentMode
        // A cached image shows on the first frame. The detail sheet relies on
        // this to have its image as soon as it opens.
        _image = State(initialValue: ImageCache.shared.cached(DecodedImage.cacheKey(key, maxPixel)))
    }

    static func cacheKey(_ key: String, _ maxPixel: Int) -> String { "\(key)@\(maxPixel)" }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .task(id: DecodedImage.cacheKey(key, maxPixel)) {
            guard image == nil, let data else { return }
            image = await ImageCache.shared.image(for: DecodedImage.cacheKey(key, maxPixel), data: data, maxPixel: maxPixel)
        }
    }
}

extension Watch {
    var coverKey: String { "\(id.uuidString)-cover-\(coverData?.count ?? 0)" }
    var thumbnailKey: String { "\(id.uuidString)-thumb-\(thumbnailData?.count ?? 0)" }
}
